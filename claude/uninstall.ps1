$ErrorActionPreference = "SilentlyContinue"

$target = Join-Path $env:LOCALAPPDATA "ClaudeUsageBar"

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'ClaudeUsageBar\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Start-Sleep -Milliseconds 500

Remove-Item -LiteralPath (Join-Path ([Environment]::GetFolderPath("Programs")) "Claude Usage Bar.lnk") -Force
Remove-Item -LiteralPath (Join-Path ([Environment]::GetFolderPath("Startup")) "Claude Usage Bar.lnk") -Force
Remove-Item -LiteralPath (Join-Path $env:USERPROFILE ".claude-usage-bar") -Recurse -Force
Remove-Item -LiteralPath (Join-Path $env:TEMP "ClaudeUsageBar.attempts.log") -Force

# This script may be running from inside the install folder, so remove the
# folder from a detached process after this one exits.
if (Test-Path -LiteralPath $target) {
    Start-Process cmd.exe -WindowStyle Hidden -WorkingDirectory $env:TEMP -ArgumentList "/c timeout /t 5 /nobreak >nul & rd /s /q `"$target`""
}

Write-Host "Claude Usage Bar has been removed."
Start-Sleep -Seconds 3
