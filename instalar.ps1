$ErrorActionPreference = 'Stop'

$baseUrl = 'https://raw.githubusercontent.com/Gidelucas/GDL-Macro/main'
$destino = Join-Path $env:LOCALAPPDATA 'GDL-Macro'
$pastaPai = Split-Path -Path $destino -Parent
$id = [guid]::NewGuid().ToString('N')
$temporario = Join-Path $pastaPai ("GDL-Macro-preparacao-$id")
$backup = Join-Path $pastaPai ("GDL-Macro-anterior-$id")
$arquivos = @('GDL_Macro.ahk', 'snippets.ini', 'AutoHotkey64.exe')
$instalacaoAnteriorMovida = $false
$novaInstalacaoAtiva = $false

try {
    if (-not $env:LOCALAPPDATA) {
        throw 'A variavel LOCALAPPDATA nao esta disponivel neste computador.'
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    New-Item -Path $temporario -ItemType Directory -Force | Out-Null

    foreach ($arquivo in $arquivos) {
        $url = "$baseUrl/$arquivo"
        $saida = Join-Path $temporario $arquivo
        Write-Host "Baixando $arquivo..."
        Invoke-WebRequest -Uri $url -OutFile $saida -UseBasicParsing -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $saida -PathType Leaf) -or (Get-Item -LiteralPath $saida).Length -eq 0) {
            throw "O arquivo $arquivo nao foi baixado corretamente."
        }
    }

    $executavelBaixado = Join-Path $temporario 'AutoHotkey64.exe'
    $fluxo = [System.IO.File]::OpenRead($executavelBaixado)
    try {
        if ($fluxo.Length -lt 2 -or $fluxo.ReadByte() -ne 77 -or $fluxo.ReadByte() -ne 90) {
            throw 'O AutoHotkey64.exe baixado nao tem um cabecalho executavel valido.'
        }
    }
    finally { $fluxo.Dispose() }

    if (Test-Path -LiteralPath $destino -PathType Container) {
        $executavelAtual = Join-Path $destino 'AutoHotkey64.exe'
        $emUso = @(Get-CimInstance Win32_Process -Filter "Name = 'AutoHotkey64.exe'" -ErrorAction Stop |
            Where-Object { $_.ExecutablePath -and ($_.ExecutablePath -ieq $executavelAtual) })
        if ($emUso.Count -gt 0) {
            throw 'A macro ja esta aberta. Feche-a pela bandeja do Windows e tente instalar novamente.'
        }
        Move-Item -LiteralPath $destino -Destination $backup -ErrorAction Stop
        $instalacaoAnteriorMovida = $true
    }

    Move-Item -LiteralPath $temporario -Destination $destino -ErrorAction Stop
    $novaInstalacaoAtiva = $true

    $ahk = Join-Path $destino 'AutoHotkey64.exe'
    $macro = Join-Path $destino 'GDL_Macro.ahk'
    Start-Process -FilePath $ahk -ArgumentList ('"' + $macro + '"') -WorkingDirectory $destino -ErrorAction Stop

    try {
        $runMruPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU'
        $props = Get-ItemProperty -Path $runMruPath -ErrorAction SilentlyContinue
        $alvo = 'raw.githubusercontent.com/Gidelucas/GDL-Macro/main/instalar.ps1'
        if ($null -ne $props) {
            $nomes = @($props.PSObject.Properties | Where-Object {
                $_.Name -cmatch '^[a-z]$' -and $_.Value -is [string] -and $_.Value.Contains($alvo)
            } | ForEach-Object { $_.Name })
            $mru = [string]$props.MRUList
            foreach ($nome in $nomes) {
                Remove-ItemProperty -Path $runMruPath -Name $nome -ErrorAction SilentlyContinue
                $mru = $mru.Replace($nome, '')
            }
            if ($nomes.Count -gt 0) {
                Set-ItemProperty -Path $runMruPath -Name 'MRUList' -Value $mru -ErrorAction SilentlyContinue
            }
        }
    }
    catch { }

    Write-Host "GDL-Macro instalado e iniciado em: $destino" -ForegroundColor Green
    if ($instalacaoAnteriorMovida -and (Test-Path -LiteralPath $backup)) {
        Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue
    }
}
catch {
    $mensagem = $_.Exception.Message
    if ($instalacaoAnteriorMovida) {
        if ($novaInstalacaoAtiva -and (Test-Path -LiteralPath $destino)) {
            Remove-Item -LiteralPath $destino -Recurse -Force -ErrorAction SilentlyContinue
        }
        if ((Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $destino)) {
            Move-Item -LiteralPath $backup -Destination $destino -ErrorAction SilentlyContinue
        }
    }
    Write-Host "Falha na instalacao do GDL-Macro: $mensagem" -ForegroundColor Red
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        [System.Windows.Forms.MessageBox]::Show(
            "Falha na instalacao do GDL-Macro:`n`n$mensagem",
            'GDL-Macro - Erro', 'OK', 'Error') | Out-Null
    }
    catch { }
    exit 1
}
finally {
    if (Test-Path -LiteralPath $temporario) {
        Remove-Item -LiteralPath $temporario -Recurse -Force -ErrorAction SilentlyContinue
    }
}
