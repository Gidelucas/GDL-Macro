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

$ahk = Join-Path $destino "AutoHotkey64.exe"
$macro = Join-Path $destino "GDL_Macro.ahk"

Start-Process `
    -FilePath $ahk `
    -ArgumentList "`"$macro`"" `
    -WorkingDirectory $destino
