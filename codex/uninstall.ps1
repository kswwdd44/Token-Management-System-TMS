[CmdletBinding()]
param([switch]$NoShortcuts, [string]$InstallBase = $env:LOCALAPPDATA)
$ErrorActionPreference = 'Stop'
$product = 'Codex'
$basePath = [IO.Path]::GetFullPath($InstallBase).TrimEnd('\')
$target = [IO.Path]::GetFullPath((Join-Path $basePath ($product + 'UsageBar')))
if ([IO.Path]::GetDirectoryName($target) -ne $basePath -or [IO.Path]::GetFileName($target) -ne ($product + 'UsageBar')) { throw 'Unsafe uninstall path.' }
if (Test-Path -LiteralPath $target) {
    if ((Get-Item -LiteralPath $target).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) { throw 'Refusing to remove a linked install folder.' }
    $marker = Join-Path $target '.tms-install.json'
    if (-not (Test-Path -LiteralPath $marker)) { throw 'TMS install marker missing. Close the bar and remove the intended folder manually.' }
    $info = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
    if ($info.product -ne $product) { throw 'TMS install marker does not match this product.' }
    $pattern = [regex]::Escape($product + 'UsageBar.ps1') + '(?:"|\s|$)'
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -match $pattern } | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop
    }
    # Refuse nested links as well, before recursive removal within the verified target.
    if (Get-ChildItem -LiteralPath $target -Recurse -Force | Where-Object { $_.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint) }) { throw 'Install folder contains a link or junction; remove manually.' }
    Remove-Item -LiteralPath $target -Recurse -Force
}
if (-not $NoShortcuts) {
    $shell = New-Object -ComObject WScript.Shell
    foreach ($folder in @([Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Startup'))) {
        $path = Join-Path $folder "$product Usage Bar.lnk"
        if (Test-Path -LiteralPath $path) {
            $link = $shell.CreateShortcut($path)
            if ($link.Arguments -eq ('"' + (Join-Path $target "Start $product Usage Bar.vbs") + '"')) { Remove-Item -LiteralPath $path -Force }
        }
    }
}
Write-Output "Removed TMS ($product). Login credentials and saved display preferences were kept."
