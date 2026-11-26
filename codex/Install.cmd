@echo off
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 echo TMS operation failed. Please review the message above.
pause
