@echo off
setlocal
pushd "%~dp0"
start "" /wait "Tech Browser.exe" %*
set "exit_code=%ERRORLEVEL%"
popd
exit /b %exit_code%
