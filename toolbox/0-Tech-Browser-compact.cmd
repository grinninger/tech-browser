@echo off
setlocal
pushd "%~dp0"

if not exist "app\Tech Browser.exe" (
    "7za.exe" x "payload.7z" -o"app" -y
    if errorlevel 1 (
        popd
        exit /b 1
    )
)

start "" /wait "%~dp0app\Tech Browser.exe" %*
set "exit_code=%ERRORLEVEL%"
popd
exit /b %exit_code%
