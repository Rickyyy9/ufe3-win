@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-windows.ps1" %*
set "CODE=%ERRORLEVEL%"
if not "%CODE%"=="0" pause
exit /b %CODE%
