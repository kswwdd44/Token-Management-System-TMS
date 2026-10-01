$ErrorActionPreference = "SilentlyContinue"

$target = Join-Path $env:LOCALAPPDATA "CodexUsageBar"

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'CodexUsageBar\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Start-Sleep -Milliseconds 500

Remove-Item -LiteralPath (Join-Path ([Environment]::GetFolderPath("Programs")) "Codex Usage Bar.lnk") -Force
Remove-Item -LiteralPath (Join-Path ([Environment]::GetFolderPath("Startup")) "Codex Usage Bar.lnk") -Force
Remove-Item -LiteralPath (Join-Path $env:USERPROFILE ".codex-usage-bar") -Recurse -Force
Remove-Item -LiteralPath (Join-Path $env:TEMP "CodexUsageBar.log") -Force

# This script may be running from inside the install folder, so remove the
# folder from a detached process after this one exits.
if (Test-Path -LiteralPath $target) {
    Start-Process cmd.exe -WindowStyle Hidden -WorkingDirectory $env:TEMP -ArgumentList "/c timeout /t 5 /nobreak >nul & rd /s /q `"$target`""
}

Write-Host "Codex Usage Bar has been removed."
Start-Sleep -Seconds 3
