$ErrorActionPreference = "Stop"

$destino = Join-Path $env:TEMP "GDL-Macro"
$baseUrl = "https://raw.githubusercontent.com/Gidelucas/GDL-Macro/main"

if (Test-Path $destino) {
    Remove-Item $destino -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $destino -Force | Out-Null

$arquivos = @(
    "GDL_Macro.ahk",
    "snippets.ini",
    "AutoHotkey64.exe"
)

foreach ($arquivo in $arquivos) {
    $url = "$baseUrl/$arquivo"
    $saida = Join-Path $destino $arquivo

    Invoke-WebRequest `
        -Uri $url `
        -OutFile $saida `
        -UseBasicParsing
}


# Remove somente a entrada deste instalador do histórico do Executar (Win+R).
try {
    $runMruPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
    $props = Get-ItemProperty -Path $runMruPath -ErrorAction SilentlyContinue
    $target = "raw.githubusercontent.com/Gidelucas/GDL-Macro/main/instalar.ps1"

    if ($null -ne $props) {
        $matchedNames = @()

        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.Name -match '^[a-z]$' -and
                $prop.Value -is [string] -and
                $prop.Value -like "*$target*") {
                $matchedNames += $prop.Name
            }
        }

        if ($matchedNames.Count -gt 0) {
            $mruList = [string]$props.MRUList

            foreach ($name in $matchedNames) {
                Remove-ItemProperty -Path $runMruPath -Name $name -ErrorAction SilentlyContinue
                $mruList = $mruList.Replace($name, "")
            }

            Set-ItemProperty -Path $runMruPath -Name "MRUList" -Value $mruList -ErrorAction SilentlyContinue
        }
    }
}
catch {
}

$ahk = Join-Path $destino "AutoHotkey64.exe"
$macro = Join-Path $destino "GDL_Macro.ahk"

Start-Process `
    -FilePath $ahk `
    -ArgumentList "`"$macro`"" `
    -WorkingDirectory $destino
