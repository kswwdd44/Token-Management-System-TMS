# Shared actions for the taskbar usage strip. No reset is redeemed by this script.
function Get-UsageBarStartupPath {
    Join-Path ([Environment]::GetFolderPath('Startup')) "$script:usageBarProduct Usage Bar.lnk"
}

function Set-UsageBarStartup([bool]$Enabled) {
    $path = Get-UsageBarStartupPath
    if ($Enabled) {
        $launcher = Join-Path $PSScriptRoot "Start $script:usageBarProduct Usage Bar.vbs"
        if (-not (Test-Path -LiteralPath $launcher)) { throw "Launcher not found: $launcher" }
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($path)
        $link.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
        $link.Arguments = '"' + $launcher + '"'
        $link.WorkingDirectory = $PSScriptRoot
        $link.Description = "$script:usageBarProduct Usage Bar - start at Windows sign-in"
        $link.Save()
    } elseif (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force -ErrorAction Stop
    }
}

function Open-UsageBarReset {
    if ($script:resetDialogOpen) { return }
    $script:resetDialogOpen = $true
    try {
        $steps = if ($script:usageBarProduct -eq 'Claude') {
            "Choose Reset for free under Limit resets, then confirm on the official page."
        } else {
            "Select an available reset, then confirm on the official page. If it is missing, check Settings > Usage & billing in the desktop app."
        }
        $message = "Open the official $script:usageBarProduct reset screen?`r`n`r`n$steps`r`n`r`nCheck availability and covered limits there. This dialog does not use a reset."
        $answer = [System.Windows.Forms.MessageBox]::Show($message, "$script:usageBarProduct reset", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question, [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
        if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-Process -FilePath $script:usageBarResetUrl -ErrorAction Stop | Out-Null
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Could not open the official usage page.`r`n$script:usageBarResetUrl`r`n$($_.Exception.Message)", 'Usage Bar') | Out-Null
    } finally { $script:resetDialogOpen = $false }
}

$resetItem = $menu.Items.Insert(0, (New-Object System.Windows.Forms.ToolStripMenuItem('Open reset screen...')))
# Insert returns void; retrieve the inserted item explicitly.
$resetItem = $menu.Items[0]
$resetItem.Add_Click({ Open-UsageBarReset })
$startupItem = New-Object System.Windows.Forms.ToolStripMenuItem('Start when I sign in to Windows')
$menu.Items.Insert(1, $startupItem)
$menu.Add_Opening({ $startupItem.Checked = Test-Path -LiteralPath (Get-UsageBarStartupPath) })
$startupItem.Add_Click({
    try {
        Set-UsageBarStartup (-not (Test-Path -LiteralPath (Get-UsageBarStartupPath)))
        $startupItem.Checked = Test-Path -LiteralPath (Get-UsageBarStartupPath)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Could not change the startup setting.`r`n$($_.Exception.Message)", 'Usage Bar') | Out-Null
    }
})
$mark.Cursor = [System.Windows.Forms.Cursors]::Hand
$mark.Add_MouseClick({ param($sender, $eventArgs)
    if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Open-UsageBarReset }
})
