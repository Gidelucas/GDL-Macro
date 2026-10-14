@echo off
setlocal EnableExtensions

set "DEST=%TEMP%\GDL-Macro"
set "BASE=https://raw.githubusercontent.com/Gidelucas/GDL-Macro/main"

if exist "%DEST%" (
    rmdir /s /q "%DEST%" >nul 2>&1
)

mkdir "%DEST%" >nul 2>&1
if errorlevel 1 (
    echo [ERRO] Nao foi possivel criar "%DEST%".
    pause
    exit /b 1
)

call :download "GDL_Macro.ahk"
if errorlevel 1 goto :erro

call :download "snippets.ini"
if errorlevel 1 goto :erro

call :download "AutoHotkey64.exe"
if errorlevel 1 goto :erro

if not exist "%DEST%\AutoHotkey64.exe" goto :erro
if not exist "%DEST%\GDL_Macro.ahk" goto :erro
if not exist "%DEST%\snippets.ini" goto :erro

start "" /d "%DEST%" "%DEST%\AutoHotkey64.exe" "%DEST%\GDL_Macro.ahk"
if errorlevel 1 goto :erro

exit /b 0

:download
set "FILE=%~1"
curl.exe -fL --connect-timeout 15 --retry 2 --retry-delay 1 "%BASE%/%FILE%" -o "%DEST%\%FILE%"
if errorlevel 1 (
    echo [ERRO] Falha ao baixar %FILE%.
    exit /b 1
)

if not exist "%DEST%\%FILE%" (
    echo [ERRO] Arquivo %FILE% nao foi criado.
    exit /b 1
)

exit /b 0

:erro
echo.
echo [ERRO] O GDL Macro nao pode ser iniciado.
echo Verifique bloqueio do Windows, antivirus, proxy ou acesso ao GitHub.
pause
exit /b 1
