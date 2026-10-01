$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public struct CodexBarRect { public int Left, Top, Right, Bottom; }
public static class CodexBarNative {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out CodexBarRect rect);
    [DllImport("gdi32.dll")] public static extern IntPtr CreateRoundRectRgn(int left, int top, int right, int bottom, int width, int height);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int index);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int index, int value);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
}
"@

[CodexBarNative]::SetProcessDPIAware() | Out-Null
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:version = "1.1.0"
$script:mutex = [System.Threading.Mutex]::new($false, "Local\CodexUsageBar")
$created = $false
try { $created = $script:mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $created = $true }
if (-not $created) { $script:mutex.Dispose(); exit 0 }

$script:server = $null
$script:requestId = 0
$script:refreshing = $false
$script:offsetX = 12
$script:refreshSeconds = 300
$script:lastTip = ""
$script:logPath = Join-Path $env:TEMP "CodexUsageBar.log"
$script:configDir = Join-Path $env:USERPROFILE ".codex-usage-bar"
$script:configPath = Join-Path $script:configDir "config.json"

$CodexBase = [System.Drawing.Color]::FromArgb(20, 25, 34)
$CodexSurface = [System.Drawing.Color]::FromArgb(47, 52, 65)
$CodexText = [System.Drawing.Color]::White
$CodexMuted = [System.Drawing.Color]::FromArgb(145, 153, 172)
$CodexBlue = [System.Drawing.Color]::FromArgb(76, 201, 240)
$CodexAmber = [System.Drawing.Color]::FromArgb(255, 190, 74)
$CodexRed = [System.Drawing.Color]::FromArgb(255, 82, 82)

function Get-UsageColor([double]$Percent) {
    if ($Percent -ge 90) { return $CodexRed }
    if ($Percent -ge 70) { return $CodexAmber }
    return $CodexBlue
}

function Get-TaskbarRect {
    $hwnd = [CodexBarNative]::FindWindow("Shell_TrayWnd", $null)
    $rect = New-Object CodexBarRect
    if ($hwnd -ne [IntPtr]::Zero -and [CodexBarNative]::GetWindowRect($hwnd, [ref]$rect)) { return $rect }
    return $null
}

function Get-DefaultOffset {
    # Sit beside ClaudeUsageBar when it is installed; otherwise start at the
    # left edge of the taskbar.
    $path = Join-Path $env:USERPROFILE ".claude-usage-bar\config.json"
    try {
        if (Test-Path -LiteralPath $path) {
            $saved = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
            if ($null -ne $saved.offsetX) { return ([int]$saved.offsetX + 415) }
        }
    } catch {}
    return 12
}

function Load-Config {
    try {
        if (Test-Path -LiteralPath $script:configPath) {
            $saved = Get-Content -Raw -LiteralPath $script:configPath | ConvertFrom-Json
            if ($null -ne $saved.offsetX) { $script:offsetX = [int]$saved.offsetX }
            if ($null -ne $saved.refreshSeconds) { $script:refreshSeconds = [Math]::Max(60, [int]$saved.refreshSeconds) }
        } else { $script:offsetX = Get-DefaultOffset }
    } catch { $script:offsetX = Get-DefaultOffset }
}

function Save-Config {
    try {
        if (-not (Test-Path -LiteralPath $script:configDir)) { New-Item -ItemType Directory -Path $script:configDir -Force | Out-Null }
        [ordered]@{ offsetX = $script:offsetX; refreshSeconds = $script:refreshSeconds } |
            ConvertTo-Json | Set-Content -LiteralPath $script:configPath -Encoding utf8
    } catch {}
}

function Find-CodexExecutable {
    foreach ($name in @("codex.exe", "codex.cmd", "codex")) {
        $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $cmd) { return $cmd.Source }
    }
    $roots = @(
        (Join-Path $env:LOCALAPPDATA "Programs\OpenAI\Codex\bin"),
        (Join-Path $env:LOCALAPPDATA "OpenAI\Codex\bin")
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $direct = Join-Path $root "codex.exe"
        if (Test-Path -LiteralPath $direct) { return $direct }
        $candidate = Get-ChildItem -LiteralPath $root -Filter "codex.exe" -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($null -ne $candidate) { return $candidate.FullName }
    }
    throw "CODEX_NOT_FOUND"
}

function Stop-AppServer {
    if ($null -ne $script:server) {
        try { if (-not $script:server.HasExited) { $script:server.Kill(); $script:server.WaitForExit(1000) | Out-Null } } catch {}
        try { $script:server.Dispose() } catch {}
        $script:server = $null
    }
}

function Send-AppRequest([string]$Method, [object]$Params, [switch]$NoParams) {
    $script:requestId++
    $request = [ordered]@{ id = $script:requestId; method = $Method }
    if (-not $NoParams) { $request.params = $Params }
    $script:server.StandardInput.WriteLine(($request | ConvertTo-Json -Depth 10 -Compress))
    $script:server.StandardInput.Flush()

    while ($true) {
        $read = $script:server.StandardOutput.ReadLineAsync()
        if (-not $read.Wait(10000)) { throw "App Server response timeout" }
        $line = $read.Result
        if ([string]::IsNullOrWhiteSpace($line)) { throw "App Server closed the stream" }
        $response = $line | ConvertFrom-Json
        if ($response.id -eq $script:requestId) {
            if ($null -ne $response.error) { throw (($response.error | ConvertTo-Json -Compress)) }
            return $response.result
        }
    }
}

function Start-AppServer {
    Stop-AppServer
    $exe = Find-CodexExecutable
    $info = New-Object System.Diagnostics.ProcessStartInfo
    if ($exe -match '\.cmd$') {
        # npm installs a .cmd shim, which has to go through cmd.exe.
        $info.FileName = $env:ComSpec
        $info.Arguments = "/d /c `"`"$exe`" app-server --stdio`""
    } else {
        $info.FileName = $exe
        $info.Arguments = "app-server --stdio"
    }
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $script:server = New-Object System.Diagnostics.Process
    $script:server.StartInfo = $info
    if (-not $script:server.Start()) { throw "Could not start App Server" }
    # Nobody reads stderr; drain it so a chatty server cannot block on a full pipe.
    $script:server.BeginErrorReadLine()
    $init = @{ clientInfo = @{ name = "codex-usage-bar"; title = "Codex Usage Bar"; version = $script:version } }
    Send-AppRequest "initialize" $init | Out-Null
    $script:server.StandardInput.WriteLine('{"method":"initialized","params":{}}')
    $script:server.StandardInput.Flush()
}

function Get-RateLimits {
    if ($null -eq $script:server -or $script:server.HasExited) { Start-AppServer }
    Send-AppRequest "account/rateLimits/read" $null -NoParams
}

function Format-Reset($UnixSeconds) {
    if ($null -eq $UnixSeconds) { return "--/-- --:--" }
    return ([DateTimeOffset]::FromUnixTimeSeconds([int64]$UnixSeconds).LocalDateTime).ToString("MM/dd HH:mm")
}

Load-Config
$taskbarRect = Get-TaskbarRect
if ($null -eq $taskbarRect) { [System.Windows.Forms.MessageBox]::Show("Taskbar not found.", "Codex Usage Bar") | Out-Null; exit 1 }
$barHeight = [Math]::Max(34, ($taskbarRect.Bottom - $taskbarRect.Top) - 8)
$barWidth = 405
$markX = 8; $markW = 45; $labelX = 58; $labelW = 26; $gaugeX = 90; $gaugeH = 7
$percentW = 48; $resetW = 84; $rightMargin = 10
$gaugeW = $barWidth - $gaugeX - 6 - $percentW - 8 - $resetW - $rightMargin
$percentX = $gaugeX + $gaugeW + 6; $resetX = $percentX + $percentW + 8

$form = New-Object System.Windows.Forms.Form
$form.Text = "Codex Usage Bar"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.ShowInTaskbar = $false; $form.TopMost = $true; $form.BackColor = $CodexBase
$form.ClientSize = New-Object System.Drawing.Size($barWidth, $barHeight)
$form.Region = [System.Drawing.Region]::FromHrgn([CodexBarNative]::CreateRoundRectRgn(0, 0, $form.Width, $form.Height, 12, 12))
$rowHeight = [int](($barHeight - 4) / 2); $row1Y = 2; $row2Y = 2 + $rowHeight

function New-CodexRow([string]$Name, [int]$Y) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Name; $label.ForeColor = $CodexText; $label.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
    $label.AutoSize = $false; $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $label.Location = New-Object System.Drawing.Point($labelX, $Y); $label.Size = New-Object System.Drawing.Size($labelW, $rowHeight); $form.Controls.Add($label)
    $track = New-Object System.Windows.Forms.Panel
    $track.BackColor = $CodexSurface; $track.Location = New-Object System.Drawing.Point($gaugeX, ($Y + [int](($rowHeight - $gaugeH) / 2))); $track.Size = New-Object System.Drawing.Size($gaugeW, $gaugeH); $form.Controls.Add($track)
    $fill = New-Object System.Windows.Forms.Panel
    $fill.BackColor = $CodexBlue; $fill.Location = New-Object System.Drawing.Point(0, 0); $fill.Size = New-Object System.Drawing.Size(0, $gaugeH); $track.Controls.Add($fill)
    $percent = New-Object System.Windows.Forms.Label
    $percent.Text = "--%"; $percent.ForeColor = $CodexMuted; $percent.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9); $percent.AutoSize = $false; $percent.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $percent.Location = New-Object System.Drawing.Point($percentX, $Y); $percent.Size = New-Object System.Drawing.Size($percentW, $rowHeight); $form.Controls.Add($percent)
    $reset = New-Object System.Windows.Forms.Label
    $reset.Text = "--/-- --:--"; $reset.ForeColor = $CodexMuted; $reset.Font = New-Object System.Drawing.Font("Segoe UI", 8); $reset.AutoSize = $false; $reset.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $reset.Location = New-Object System.Drawing.Point($resetX, $Y); $reset.Size = New-Object System.Drawing.Size($resetW, $rowHeight); $form.Controls.Add($reset)
    return @{ Label=$label; Track=$track; Fill=$fill; Percent=$percent; Reset=$reset }
}

$rowFive = New-CodexRow "5h" $row1Y
$rowSeven = New-CodexRow "7d" $row2Y
$allRows = @($rowFive, $rowSeven)

function Show-MarkText($Graphics, $Bounds, [string]$Text, $Color) {
    # Shrink the font until the name fits the column at any display scale.
    $flags = [System.Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, SingleLine, NoPadding'
    for ($size = 9.0; $size -ge 5.0; $size -= 0.5) {
        $font = New-Object System.Drawing.Font("Segoe UI Semibold", $size)
        $fit = [System.Windows.Forms.TextRenderer]::MeasureText($Text, $font, $Bounds.Size, $flags).Width -le $Bounds.Width
        if ($fit -or $size -le 5.0) {
            [System.Windows.Forms.TextRenderer]::DrawText($Graphics, $Text, $font, $Bounds, $Color, $flags)
            $font.Dispose()
            return
        }
        $font.Dispose()
    }
}

# The mark is the product name in text: no logo artwork is shipped.
$mark = New-Object System.Windows.Forms.Panel
$mark.BackColor = $CodexBase
$mark.Size = New-Object System.Drawing.Size($markW, $barHeight)
$mark.Location = New-Object System.Drawing.Point($markX, 0)
$form.Controls.Add($mark)
$mark.Add_Paint({
    param($sender, $e)
    Show-MarkText $e.Graphics $sender.ClientRectangle "Codex" $CodexBlue
})

$tooltip = New-Object System.Windows.Forms.ToolTip; $tooltip.AutoPopDelay = 12000; $tooltip.InitialDelay = 300
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$refreshItem = $menu.Items.Add("Refresh now"); $detailsItem = $menu.Items.Add("Details"); $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null; $exitItem = $menu.Items.Add("Exit")
$form.ContextMenuStrip = $menu

function Set-BarPosition {
    $rect = Get-TaskbarRect
    if ($null -eq $rect) { return }
    $h = $rect.Bottom - $rect.Top
    $top = $rect.Top + [Math]::Max(0, [int](($h - $form.ClientSize.Height) / 2))
    # Keep the strip on screen if the saved offset came from a wider display.
    $maxX = [Math]::Max(0, ($rect.Right - $rect.Left) - $form.Width)
    $x = [Math]::Min([Math]::Max(0, $script:offsetX), $maxX)
    $form.Location = New-Object System.Drawing.Point($x, $top)
}
function Assert-TopMost { [CodexBarNative]::SetWindowPos($form.Handle, [IntPtr](-1), 0, 0, 0, 0, 0x13) | Out-Null }

function Test-FullscreenForeground {
    # Step aside while a game or full-screen video is in front.
    $fg = [CodexBarNative]::GetForegroundWindow()
    if ($fg -eq [IntPtr]::Zero -or $fg -eq $form.Handle) { return $false }
    $rect = New-Object CodexBarRect
    if (-not [CodexBarNative]::GetWindowRect($fg, [ref]$rect)) { return $false }
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    return (($rect.Right - $rect.Left) -ge $screen.Width -and ($rect.Bottom - $rect.Top) -ge $screen.Height)
}

function Set-BarRow($Row, $Window) {
    if ($null -eq $Window) { $Row.Percent.Text = "--%"; $Row.Percent.ForeColor = $CodexMuted; $Row.Fill.Width = 0; $Row.Reset.Text = "--/-- --:--"; $Row.Reset.ForeColor = $CodexMuted; return }
    $used = [Math]::Max(0, [Math]::Min(100, [double]$Window.usedPercent))
    $color = Get-UsageColor $used
    $Row.Percent.Text = ("{0}%" -f [int][Math]::Round($used)); $Row.Percent.ForeColor = $color; $Row.Fill.BackColor = $color; $Row.Fill.Width = [int][Math]::Round($Row.Track.ClientSize.Width * $used / 100); $Row.Reset.Text = Format-Reset $Window.resetsAt; $Row.Reset.ForeColor = $color
}

function Show-Message([string]$Text, $Color) {
    # The strip has no spare row, so problems are spelled out in the reset
    # column where they cannot be missed.
    $rowFive.Reset.Text = $Text; $rowFive.Reset.ForeColor = $Color
    $rowSeven.Reset.Text = ""
}

function Update-Usage {
    if ($script:refreshing) { return }
    $script:refreshing = $true
    try {
        $snapshot = Get-RateLimits
        $limits = $snapshot.rateLimits
        if ($null -ne $snapshot.rateLimitsByLimitId -and $null -ne $snapshot.rateLimitsByLimitId.codex) { $limits = $snapshot.rateLimitsByLimitId.codex }
        if ($null -eq $limits -or ($null -eq $limits.primary -and $null -eq $limits.secondary)) { throw "NO_LIMITS" }
        Set-BarRow $rowFive $limits.primary; Set-BarRow $rowSeven $limits.secondary
        $lines = @()
        if ($null -ne $limits.primary) { $lines += "5 hours: $([int][Math]::Round([double]$limits.primary.usedPercent))% used - resets $(Format-Reset $limits.primary.resetsAt)" }
        if ($null -ne $limits.secondary) { $lines += "7 days: $([int][Math]::Round([double]$limits.secondary.usedPercent))% used - resets $(Format-Reset $limits.secondary.resetsAt)" }
        $script:lastTip = $lines -join "`n"
        foreach($target in @($form,$mark,$rowFive.Label,$rowFive.Track,$rowFive.Percent,$rowFive.Reset,$rowSeven.Label,$rowSeven.Track,$rowSeven.Percent,$rowSeven.Reset)){ $tooltip.SetToolTip($target,$script:lastTip) }
        Remove-Item -LiteralPath $script:logPath -ErrorAction SilentlyContinue
    } catch {
        $raw = $_.Exception.Message
        ("$(Get-Date -Format s)  v$($script:version)`r`n" + ($_ | Out-String)) | Set-Content -LiteralPath $script:logPath -Encoding utf8
        Stop-AppServer
        Set-BarRow $rowFive $null; Set-BarRow $rowSeven $null
        if ($raw -eq "CODEX_NOT_FOUND") {
            Show-Message "install Codex CLI" $CodexRed
            $script:lastTip = "Codex CLI was not found. Install it (npm i -g @openai/codex), then run: codex login"
        } elseif ($raw -match 'auth|login|logged|sign|401|unauthor|credential|token') {
            Show-Message "run: codex login" $CodexRed
            $script:lastTip = "Codex is not signed in. Open a terminal and run: codex login`n`n$raw"
        } elseif ($raw -eq "NO_LIMITS") {
            Show-Message "no usage data" $CodexAmber
            $script:lastTip = "Codex returned no usage limits. A ChatGPT plan login (codex login) is required; API-key logins have no 5h/7d limits."
        } else {
            $short = $raw; if ($short.Length -gt 22) { $short = $short.Substring(0, 22) }
            Show-Message $short $CodexRed
            $script:lastTip = "Connection error: $raw`n`nLog: $($script:logPath)"
        }
        $tooltip.SetToolTip($form, $script:lastTip)
    } finally { $script:refreshing = $false }
}

$timer = New-Object System.Windows.Forms.Timer; $timer.Interval = ($script:refreshSeconds * 1000); $timer.Add_Tick({ Update-Usage })
$keeper = New-Object System.Windows.Forms.Timer; $keeper.Interval = 3000
$keeper.Add_Tick({
    if (Test-FullscreenForeground) { if ($form.Visible) { $form.Hide() }; return }
    if (-not $form.Visible) { [CodexBarNative]::ShowWindow($form.Handle, 8) | Out-Null }
    Set-BarPosition; Assert-TopMost
})
$refreshItem.Add_Click({ Update-Usage })
$detailsItem.Add_Click({ [System.Windows.Forms.MessageBox]::Show($(if($script:lastTip){$script:lastTip}else{"No data yet."}), "Codex Usage Bar $($script:version)") | Out-Null })
$exitItem.Add_Click({ $form.Close() })

$dragging = $false; $dragOrigin = 0
$dragDown = { param($s,$e) if($e.Button -eq [System.Windows.Forms.MouseButtons]::Left){$script:dragging=$true;$script:dragOrigin=[System.Windows.Forms.Cursor]::Position.X-$form.Location.X} }
$dragMove = { if($script:dragging){$x=[System.Windows.Forms.Cursor]::Position.X-$script:dragOrigin;if($x-lt 0){$x=0};$script:offsetX=$x;$form.Location=New-Object System.Drawing.Point($x,$form.Location.Y)} }
$dragUp = { if($script:dragging){$script:dragging=$false;Save-Config} }
foreach($c in @($form,$mark,$rowFive.Label,$rowFive.Percent,$rowFive.Reset,$rowSeven.Label,$rowSeven.Percent,$rowSeven.Reset)){ $c.Add_MouseDown($dragDown);$c.Add_MouseMove($dragMove);$c.Add_MouseUp($dragUp) }

$form.Add_FormClosed({ $timer.Stop();$keeper.Stop();Stop-AppServer;Save-Config;try{$script:mutex.ReleaseMutex()}catch{};$script:mutex.Dispose() })
$handle = $form.Handle; $ex = [CodexBarNative]::GetWindowLong($handle,-20); [CodexBarNative]::SetWindowLong($handle,-20,($ex -bor 0x80 -bor 0x08000000)) | Out-Null
Set-BarPosition; $form.Add_Shown({ Update-Usage; $timer.Start(); $keeper.Start(); Set-BarPosition; Assert-TopMost })
[System.Windows.Forms.Application]::Run($form)
