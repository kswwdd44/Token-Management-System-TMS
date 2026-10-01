$ErrorActionPreference = "Stop"

$source = $PSScriptRoot
$target = Join-Path $env:LOCALAPPDATA "CodexUsageBar"
$startMenu = Join-Path ([Environment]::GetFolderPath("Programs")) "Codex Usage Bar.lnk"
$startup = Join-Path ([Environment]::GetFolderPath("Startup")) "Codex Usage Bar.lnk"

Write-Host "Codex Usage Bar - install"
Write-Host ""

# Stop a running copy so its files can be replaced.
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'CodexUsageBar\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500

New-Item -ItemType Directory -Path $target -Force | Out-Null
foreach ($name in @("CodexUsageBar.ps1", "Start Codex Usage Bar.vbs", "uninstall.ps1", "Uninstall.cmd", "README.txt")) {
    $file = Join-Path $source $name
    if (Test-Path -LiteralPath $file) { Copy-Item -LiteralPath $file -Destination $target -Force }
}
# Files unpacked from a downloaded zip carry a "from the internet" mark.
Get-ChildItem -LiteralPath $target -File | Unblock-File -ErrorAction SilentlyContinue

$vbs = Join-Path $target "Start Codex Usage Bar.vbs"
$shell = New-Object -ComObject WScript.Shell
foreach ($path in @($startMenu, $startup)) {
    $link = $shell.CreateShortcut($path)
    $link.TargetPath = Join-Path $env:WINDIR "System32\wscript.exe"
    $link.Arguments = "`"$vbs`""
    $link.WorkingDirectory = $target
    $link.Description = "Codex usage strip on the taskbar"
    $link.Save()
}

Write-Host "Installed to: $target"
Write-Host "Start menu and startup shortcuts created (starts with Windows)."

$codex = Get-Command codex, codex.cmd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $codex -and -not (Test-Path (Join-Path $env:LOCALAPPDATA "Programs\OpenAI\Codex\bin"))) {
    Write-Host ""
    Write-Host "WARNING: Codex CLI was not found." -ForegroundColor Yellow
    Write-Host "  Install it first:  npm i -g @openai/codex"
    Write-Host "  Then sign in:      codex login"
}

Start-Process (Join-Path $env:WINDIR "System32\wscript.exe") -ArgumentList "`"$vbs`""
Write-Host ""
Write-Host "Started. Look at the left side of the taskbar."
