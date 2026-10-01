$ErrorActionPreference = "Stop"

$source = $PSScriptRoot
$target = Join-Path $env:LOCALAPPDATA "ClaudeUsageBar"
$startMenu = Join-Path ([Environment]::GetFolderPath("Programs")) "Claude Usage Bar.lnk"
$startup = Join-Path ([Environment]::GetFolderPath("Startup")) "Claude Usage Bar.lnk"

Write-Host "Claude Usage Bar - install"
Write-Host ""

# Stop a running copy so its files can be replaced.
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'ClaudeUsageBar\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500

New-Item -ItemType Directory -Path $target -Force | Out-Null
foreach ($name in @("ClaudeUsageBar.ps1", "Start Claude Usage Bar.vbs", "uninstall.ps1", "Uninstall.cmd", "README.txt")) {
    $file = Join-Path $source $name
    if (Test-Path -LiteralPath $file) { Copy-Item -LiteralPath $file -Destination $target -Force }
}
# Files unpacked from a downloaded zip carry a "from the internet" mark.
Get-ChildItem -LiteralPath $target -File | Unblock-File -ErrorAction SilentlyContinue

$vbs = Join-Path $target "Start Claude Usage Bar.vbs"
$shell = New-Object -ComObject WScript.Shell
foreach ($path in @($startMenu, $startup)) {
    $link = $shell.CreateShortcut($path)
    $link.TargetPath = Join-Path $env:WINDIR "System32\wscript.exe"
    $link.Arguments = "`"$vbs`""
    $link.WorkingDirectory = $target
    $link.Description = "Claude usage strip on the taskbar"
    $link.Save()
}

Write-Host "Installed to: $target"
Write-Host "Start menu and startup shortcuts created (starts with Windows)."

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "WARNING: Claude Code (claude) was not found on PATH." -ForegroundColor Yellow
    Write-Host "  Install it first:  https://claude.com/claude-code"
    Write-Host "  Then sign in:      claude /login"
}

Start-Process (Join-Path $env:WINDIR "System32\wscript.exe") -ArgumentList "`"$vbs`""
Write-Host ""
Write-Host "Started. Look at the left side of the taskbar."
