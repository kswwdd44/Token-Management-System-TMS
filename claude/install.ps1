[CmdletBinding()]
param([switch]$NoLaunch, [switch]$NoShortcuts, [string]$InstallBase = $env:LOCALAPPDATA)
$ErrorActionPreference = 'Stop'
$product = 'Claude'
$target = [IO.Path]::GetFullPath((Join-Path $InstallBase ($product + 'UsageBar')))
if ([IO.Path]::GetFileName($target) -ne ($product + 'UsageBar')) { throw 'Invalid install folder.' }
$required = @(($product + 'UsageBar.ps1'), "Start $product Usage Bar.vbs", 'UsageBarActions.ps1', 'uninstall.ps1', 'Uninstall.cmd', 'README.txt')
foreach ($name in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $name) -PathType Leaf)) { throw "Package file missing: $name" }
}
if ((Test-Path -LiteralPath $target) -and (Get-Item -LiteralPath $target).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) { throw 'Install target must not be a link or junction.' }
$pattern = [regex]::Escape($product + 'UsageBar.ps1') + '(?:"|\s|$)'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -match $pattern } | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop
}
New-Item -ItemType Directory -Path $target -Force | Out-Null
foreach ($name in $required) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $target $name) -Force }
@{ product=$product; version='1.2.0' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $target '.tms-install.json') -Encoding UTF8
Get-ChildItem -LiteralPath $target -File | Unblock-File -ErrorAction SilentlyContinue
$vbs = Join-Path $target "Start $product Usage Bar.vbs"
if (-not $NoShortcuts) {
    $shell = New-Object -ComObject WScript.Shell
    foreach ($folder in @([Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Startup'))) {
        $link = $shell.CreateShortcut((Join-Path $folder "$product Usage Bar.lnk"))
        $link.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
        $link.Arguments = '"' + $vbs + '"'
        $link.WorkingDirectory = $target
        $link.Description = "TMS 1.2.0 - $product usage strip"
        $link.Save()
    }
}
if (-not $NoLaunch) { Start-Process -FilePath (Join-Path $env:WINDIR 'System32\wscript.exe') -ArgumentList ('"' + $vbs + '"') -WindowStyle Hidden }
Write-Output "Installed TMS 1.2.0 ($product) to $target"
