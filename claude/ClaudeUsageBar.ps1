$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public struct BarRect { public int Left, Top, Right, Bottom; }
public static class BarNative {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out BarRect lpRect);
    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool DestroyIcon(IntPtr hIcon);
}
"@

Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class BarCredMan {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL {
        public uint Flags;
        public uint Type;
        public IntPtr TargetName;
        public IntPtr Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint Persist;
        public uint AttributeCount;
        public IntPtr Attributes;
        public IntPtr TargetAlias;
        public IntPtr UserName;
    }
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CredEnumerateW(string filter, uint flag, out uint count, out IntPtr credentials);
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CredReadW(string target, uint type, uint flags, out IntPtr credential);
    [DllImport("advapi32.dll")]
    static extern void CredFree(IntPtr buffer);

    public static List<string> ListTargets() {
        var names = new List<string>();
        uint count = 0;
        IntPtr bulk = IntPtr.Zero;
        if (!CredEnumerateW(null, 1, out count, out bulk)) return names;
        try {
            for (int i = 0; i < count; i++) {
                IntPtr entry = Marshal.ReadIntPtr(bulk, i * IntPtr.Size);
                var cred = (CREDENTIAL)Marshal.PtrToStructure(entry, typeof(CREDENTIAL));
                if (cred.TargetName != IntPtr.Zero)
                    names.Add(Marshal.PtrToStringUni(cred.TargetName));
            }
        } finally { CredFree(bulk); }
        return names;
    }

    public static string ReadBlob(string target) {
        IntPtr ptr = IntPtr.Zero;
        if (!CredReadW(target, 1, 0, out ptr)) return null;
        try {
            var cred = (CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL));
            if (cred.CredentialBlobSize == 0) return "";
            return Marshal.PtrToStringUni(cred.CredentialBlob, (int)(cred.CredentialBlobSize / 2));
        } finally { CredFree(ptr); }
    }
}
"@

[BarNative]::SetProcessDPIAware() | Out-Null
[System.Windows.Forms.Application]::EnableVisualStyles()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:version = "1.0.0"
$script:singleInstance = New-Object System.Threading.Mutex($false, "Local\ClaudeUsageBar")
$script:owns = $false
try { $script:owns = $script:singleInstance.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $script:owns = $true }
if (-not $script:owns) {
    $script:singleInstance.Dispose()
    exit 0
}

$script:configDir = Join-Path $env:USERPROFILE ".claude-usage-bar"
$script:configPath = Join-Path $script:configDir "config.json"
$script:attemptLog = Join-Path $env:TEMP "ClaudeUsageBar.attempts.log"
$script:refreshing = $false
$script:haveData = $false
$script:backoffSeconds = 0
$script:retryAfterSeconds = 0
$script:nextAllowed = [DateTime]::MinValue
$script:refreshSeconds = 300
$script:refreshMarginMinutes = 2
$script:autoRefresh = $true
$script:offsetX = 12
$script:dragging = $false
$script:dragOrigin = 0
$script:taskbar = [IntPtr]::Zero
$script:lastTip = ""
$script:cacheFivePercent = $null
$script:cacheFiveReset = $null
$script:cacheSevenPercent = $null
$script:cacheSevenReset = $null

# ---------------------------------------------------------------- palette
function Test-LightTheme {
    try {
        $key = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        return ((Get-ItemProperty -Path $key -Name "SystemUsesLightTheme" -ErrorAction Stop).SystemUsesLightTheme -eq 1)
    } catch { return $false }
}

if (Test-LightTheme) {
    $ClaudeBase    = [System.Drawing.Color]::FromArgb(240, 238, 230)
    $ClaudeSurface = [System.Drawing.Color]::FromArgb(214, 211, 199)
    $ClaudeText    = [System.Drawing.Color]::FromArgb(20, 20, 19)
    $ClaudeMuted   = [System.Drawing.Color]::FromArgb(107, 104, 98)
    $ClaudeCoral   = [System.Drawing.Color]::FromArgb(201, 100, 66)
    $ClaudeSage    = [System.Drawing.Color]::FromArgb(95, 138, 95)
    $ClaudeAmber   = [System.Drawing.Color]::FromArgb(184, 122, 46)
    $ClaudeClay    = [System.Drawing.Color]::FromArgb(168, 50, 42)
} else {
    $ClaudeBase    = [System.Drawing.Color]::FromArgb(31, 30, 29)
    $ClaudeSurface = [System.Drawing.Color]::FromArgb(58, 57, 54)
    $ClaudeText    = [System.Drawing.Color]::FromArgb(245, 244, 239)
    $ClaudeMuted   = [System.Drawing.Color]::FromArgb(143, 141, 134)
    $ClaudeCoral   = [System.Drawing.Color]::FromArgb(217, 119, 87)
    $ClaudeSage    = [System.Drawing.Color]::FromArgb(127, 163, 127)
    $ClaudeAmber   = [System.Drawing.Color]::FromArgb(217, 160, 91)
    $ClaudeClay    = [System.Drawing.Color]::FromArgb(196, 78, 68)
}

function Get-UsageColor([double]$Percent) {
    if ($Percent -ge 90) { return $ClaudeClay }
    if ($Percent -ge 70) { return $ClaudeAmber }
    return $ClaudeSage
}

# ------------------------------------------------------------ persistence
function Get-SavedConfig {
    if (-not (Test-Path -LiteralPath $script:configPath)) { return $null }
    try { return Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json } catch { return $null }
}

function Save-Config {
    try {
        if (-not (Test-Path -LiteralPath $script:configDir)) {
            New-Item -ItemType Directory -Path $script:configDir -Force | Out-Null
        }
        [ordered]@{
            offsetX              = $script:offsetX
            refreshSeconds       = $script:refreshSeconds
            refreshMarginMinutes = $script:refreshMarginMinutes
            autoRefresh          = $script:autoRefresh
            cacheFivePercent     = $script:cacheFivePercent
            cacheFiveReset       = $script:cacheFiveReset
            cacheSevenPercent    = $script:cacheSevenPercent
            cacheSevenReset      = $script:cacheSevenReset
        } | ConvertTo-Json | Set-Content -LiteralPath $script:configPath -Encoding utf8
    } catch {}
}

function Write-AttemptLog([string]$Line) {
    try {
        $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Add-Content -LiteralPath $script:attemptLog -Value "$stamp  $Line" -Encoding utf8
        $all = @(Get-Content -LiteralPath $script:attemptLog -ErrorAction SilentlyContinue)
        if ($all.Count -gt 400) {
            Set-Content -LiteralPath $script:attemptLog -Value $all[-200..-1] -Encoding utf8
        }
    } catch {}
}

# ------------------------------------------------------------------ data
function Find-TokenInJson([string]$Text) {
    $root = $null
    try { $root = $Text | ConvertFrom-Json } catch { return $null }
    $token = $null
    $stack = New-Object System.Collections.Stack
    $stack.Push($root)
    while ($stack.Count -gt 0) {
        $node = $stack.Pop()
        if ($null -eq $node) { continue }
        foreach ($prop in $node.PSObject.Properties) {
            if ($prop.Name -match '^(accessToken|access_token)$' -and
                $prop.Value -is [string] -and $prop.Value.Length -gt 0) {
                $token = $prop.Value
            }
            if ($prop.Value -is [System.Management.Automation.PSCustomObject]) {
                $stack.Push($prop.Value)
            } elseif ($prop.Value -is [System.Object[]]) {
                foreach ($item in $prop.Value) {
                    if ($item -is [System.Management.Automation.PSCustomObject]) { $stack.Push($item) }
                }
            }
        }
    }
    return $token
}

function Get-TokenExpiry {
    $path = Join-Path $env:USERPROFILE ".claude\.credentials.json"
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try { $root = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json } catch { return $null }
    $value = $null
    $stack = New-Object System.Collections.Stack
    $stack.Push($root)
    while ($stack.Count -gt 0) {
        $node = $stack.Pop()
        if ($null -eq $node) { continue }
        foreach ($prop in $node.PSObject.Properties) {
            if ($prop.Name -eq "expiresAt" -and $prop.Value) { $value = $prop.Value }
            if ($prop.Value -is [System.Management.Automation.PSCustomObject]) { $stack.Push($prop.Value) }
        }
    }
    if ($null -eq $value) { return $null }
    try {
        $n = [int64]$value
        if ($n -le 0) { return $null }
        if ($n -gt 100000000000) { return [DateTimeOffset]::FromUnixTimeMilliseconds($n).LocalDateTime }
        return [DateTimeOffset]::FromUnixTimeSeconds($n).LocalDateTime
    } catch { return $null }
}

function Invoke-TokenRefresh {
    # Only a real API call makes the CLI renew its session and rewrite the
    # credentials file; "claude auth status" does not.
    if (-not $script:autoRefresh) { return $false }
    $claude = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claude) { Write-AttemptLog "REFRESH skipped - claude not on PATH"; return $false }
    Write-AttemptLog "REFRESH nudging the CLI to renew the token"
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $claude.Source
        $psi.Arguments = '-p "ok" --model claude-haiku-4-5-20251001 --output-format json'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        # Drain both pipes while waiting; a full pipe would block the child.
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()
        if (-not $proc.WaitForExit(60000)) {
            try { $proc.Kill() } catch {}
            Write-AttemptLog "REFRESH timed out"
            return $false
        }
        $outTask.Wait(); $errTask.Wait()
        Write-AttemptLog ("REFRESH done - exit " + $proc.ExitCode)
        if ($proc.ExitCode -ne 0) { return $false }
        return $true
    } catch {
        Write-AttemptLog ("REFRESH failed - " + $_.Exception.Message)
        return $false
    }
}

function Get-AccessToken {
    $targets = @()
    try { $targets = [BarCredMan]::ListTargets() | Where-Object { $_ -match 'claude|anthropic' } } catch {}
    foreach ($target in $targets) {
        $blob = $null
        try { $blob = [BarCredMan]::ReadBlob($target) } catch { continue }
        if ([string]::IsNullOrEmpty($blob)) { continue }
        $candidate = Find-TokenInJson $blob
        if (-not $candidate -and $blob.Length -gt 40 -and $blob -match '^[A-Za-z0-9_\-\.]+$') { $candidate = $blob }
        if ($candidate) { return $candidate }
    }
    $path = Join-Path $env:USERPROFILE ".claude\.credentials.json"
    if (Test-Path -LiteralPath $path) {
        $candidate = Find-TokenInJson (Get-Content -LiteralPath $path -Raw)
        if ($candidate) { return $candidate }
    }
    # Without this line a missing token fails every tick with nothing logged.
    Write-AttemptLog ("NO TOKEN - " + @($targets).Count + " credential targets, file exists=" + (Test-Path -LiteralPath $path))
    if (-not (Get-Command claude -ErrorAction SilentlyContinue) -and -not (Test-Path -LiteralPath $path)) { throw "NOT_INSTALLED" }
    throw "sign in"
}

function Invoke-UsageRequest {
    $token = Get-AccessToken
    # One request per refresh - retrying with extra headers is what tripped
    # this endpoint's rate limit during development.
    $headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
    try {
        $result = Invoke-RestMethod -Uri "https://api.anthropic.com/api/oauth/usage" `
            -Method Get -Headers $headers -TimeoutSec 15
        Write-AttemptLog "OK 200"
        return $result
    } catch {
        $status = $null
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        $detail = ""
        try {
            $hdrs = $_.Exception.Response.Headers
            foreach ($key in $hdrs.AllKeys) {
                if ($key -match 'retry|ratelimit|rate-limit') { $detail += " $key=$($hdrs[$key])" }
            }
        } catch {}
        Write-AttemptLog ("FAIL $status" + $detail)
        if ($status -eq 401 -or $status -eq 403) { throw "sign in" }
        if ($status -eq 429) {
            $retryAfter = 0
            try {
                $header = $_.Exception.Response.Headers["Retry-After"]
                if ($header) { $retryAfter = [int]$header }
            } catch {}
            $script:retryAfterSeconds = $retryAfter
            throw "RATE_LIMIT"
        }
        throw $_
    }
}

function Read-Percent($Node) {
    foreach ($key in @("utilization", "percent", "used_percent", "usedPercent")) {
        if ($null -ne $Node.$key) { try { return [double]$Node.$key } catch {} }
    }
    return $null
}

function Read-Reset($Node) {
    foreach ($key in @("resets_at", "resetsAt", "reset_at")) {
        if ($null -ne $Node.$key) { return $Node.$key }
    }
    return $null
}

function Find-UsageWindow($Payload, [string[]]$Names) {
    $stack = New-Object System.Collections.Stack
    $stack.Push($Payload)
    while ($stack.Count -gt 0) {
        $node = $stack.Pop()
        if ($null -eq $node) { continue }
        foreach ($prop in $node.PSObject.Properties) {
            if ($Names -contains $prop.Name -and $prop.Value -is [System.Management.Automation.PSCustomObject]) {
                $percent = Read-Percent $prop.Value
                if ($null -ne $percent) { return @{ Percent = $percent; Reset = (Read-Reset $prop.Value) } }
            }
            if ($prop.Value -is [System.Management.Automation.PSCustomObject]) { $stack.Push($prop.Value) }
        }
    }
    return $null
}

function ConvertTo-LocalMoment($Value) {
    if ($null -eq $Value) { return $null }
    try {
        # The endpoint sends ISO-8601; older shapes used epoch numbers.
        if ($Value -is [string] -and $Value -notmatch '^\d+$') {
            return ([DateTimeOffset]::Parse($Value)).LocalDateTime
        }
        $n = [int64]$Value
        if ($n -gt 100000000000) { return [DateTimeOffset]::FromUnixTimeMilliseconds($n).LocalDateTime }
        return [DateTimeOffset]::FromUnixTimeSeconds($n).LocalDateTime
    } catch { return $null }
}

function Format-Reset($Value) {
    $moment = ConvertTo-LocalMoment $Value
    if ($null -eq $moment) { return "--/-- --:--" }
    return $moment.ToString("MM/dd HH:mm")
}

function Format-Remaining($Value) {
    $moment = ConvertTo-LocalMoment $Value
    if ($null -eq $moment) { return "" }
    $span = $moment - (Get-Date)
    if ($span.TotalSeconds -le 0) { return "now" }
    if ($span.TotalDays -ge 1) { return ("{0}d {1}h" -f [int]$span.TotalDays, $span.Hours) }
    if ($span.TotalHours -ge 1) { return ("{0}h {1}m" -f [int]$span.TotalHours, $span.Minutes) }
    return ("{0}m" -f [int]$span.TotalMinutes)
}

# ------------------------------------------------------------------- UI
# The height tracks the taskbar. Column metrics match CodexUsageBar so the
# two strips sit alike.
$BarWidth = 405
$MarkX = 8;   $MarkW = 45
$LabelX = 58; $LabelW = 26
$GaugeX = 90; $GaugeH = 7
$PercentW = 48
$ResetW = 84
$RightMargin = 10
# The gauge takes whatever the fixed columns leave, so changing $BarWidth
# alone re-flows the strip.
$GaugeW = $BarWidth - $GaugeX - 6 - $PercentW - 8 - $ResetW - $RightMargin
$PercentX = $GaugeX + $GaugeW + 6
$ResetX = $PercentX + $PercentW + 8

$saved = Get-SavedConfig
if ($null -ne $saved) {
    if ($null -ne $saved.offsetX) { try { $script:offsetX = [int]$saved.offsetX } catch {} }
    if ($null -ne $saved.refreshSeconds) { try { $script:refreshSeconds = [Math]::Max(60, [int]$saved.refreshSeconds) } catch {} }
    if ($null -ne $saved.refreshMarginMinutes) { try { $script:refreshMarginMinutes = [int]$saved.refreshMarginMinutes } catch {} }
    if ($null -ne $saved.autoRefresh) { $script:autoRefresh = [bool]$saved.autoRefresh }
    $script:cacheFivePercent = $saved.cacheFivePercent
    $script:cacheFiveReset = $saved.cacheFiveReset
    $script:cacheSevenPercent = $saved.cacheSevenPercent
    $script:cacheSevenReset = $saved.cacheSevenReset
}

function Get-TaskbarRect {
    $script:taskbar = [BarNative]::FindWindow("Shell_TrayWnd", $null)
    $rect = New-Object BarRect
    if ($script:taskbar -ne [IntPtr]::Zero -and [BarNative]::GetWindowRect($script:taskbar, [ref]$rect)) {
        return $rect
    }
    return $null
}

$taskbarRect = Get-TaskbarRect
if ($null -eq $taskbarRect) {
    [System.Windows.Forms.MessageBox]::Show("Taskbar not found.", "Claude Usage Bar") | Out-Null
    exit 1
}
$taskbarHeight = $taskbarRect.Bottom - $taskbarRect.Top
$BarHeight = [Math]::Max(34, $taskbarHeight - 8)

$form = New-Object System.Windows.Forms.Form
$form.Text = "Claude Usage Bar"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.ShowInTaskbar = $false
$form.TopMost = $true
$form.BackColor = $ClaudeBase
$form.ClientSize = New-Object System.Drawing.Size($BarWidth, $BarHeight)

$rowHeight = [int](($BarHeight - 4) / 2)
$row1Y = 2
$row2Y = 2 + $rowHeight

function New-BarRow([string]$Name, [int]$Y) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Name
    $label.ForeColor = $ClaudeText
    $label.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
    $label.AutoSize = $false
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $label.Location = New-Object System.Drawing.Point($LabelX, $Y)
    $label.Size = New-Object System.Drawing.Size($LabelW, $rowHeight)
    $form.Controls.Add($label)

    $track = New-Object System.Windows.Forms.Panel
    $track.BackColor = $ClaudeSurface
    $track.Location = New-Object System.Drawing.Point($GaugeX, ($Y + [int](($rowHeight - $GaugeH) / 2)))
    $track.Size = New-Object System.Drawing.Size($GaugeW, $GaugeH)
    $form.Controls.Add($track)

    $fill = New-Object System.Windows.Forms.Panel
    $fill.BackColor = $ClaudeSage
    $fill.Location = New-Object System.Drawing.Point(0, 0)
    $fill.Size = New-Object System.Drawing.Size(0, $GaugeH)
    $track.Controls.Add($fill)

    $percent = New-Object System.Windows.Forms.Label
    $percent.Text = "--%"
    $percent.ForeColor = $ClaudeMuted
    $percent.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
    $percent.AutoSize = $false
    $percent.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $percent.Location = New-Object System.Drawing.Point($PercentX, $Y)
    $percent.Size = New-Object System.Drawing.Size($PercentW, $rowHeight)
    $form.Controls.Add($percent)

    # The reset stamp sits beside the percentage because the strip has no
    # room for a header row.
    $reset = New-Object System.Windows.Forms.Label
    $reset.Text = "--/-- --:--"
    $reset.ForeColor = $ClaudeMuted
    $reset.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $reset.AutoSize = $false
    $reset.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $reset.Location = New-Object System.Drawing.Point($ResetX, $Y)
    $reset.Size = New-Object System.Drawing.Size($ResetW, $rowHeight)
    $form.Controls.Add($reset)

    return @{ Label = $label; Track = $track; Fill = $fill; Percent = $percent; Reset = $reset }
}

$rowFive = New-BarRow "5h" $row1Y
$rowSeven = New-BarRow "7d" $row2Y
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
$mark.BackColor = $ClaudeBase
$mark.Size = New-Object System.Drawing.Size($MarkW, $BarHeight)
$mark.Location = New-Object System.Drawing.Point($MarkX, 0)
$form.Controls.Add($mark)
$mark.Add_Paint({
    param($sender, $e)
    Show-MarkText $e.Graphics $sender.ClientRectangle "Claude" $ClaudeCoral
})

$tooltip = New-Object System.Windows.Forms.ToolTip
$tooltip.AutoPopDelay = 12000
$tooltip.InitialDelay = 300

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$refreshItem = $menu.Items.Add("Refresh now")
$detailsItem = $menu.Items.Add("Details")
$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$exitItem = $menu.Items.Add("Exit")
$form.ContextMenuStrip = $menu

# --------------------------------------------------------------- overlay
# Windows 11 refuses SetParent into Shell_TrayWnd, so the strip is a
# topmost tool window parked over the taskbar instead.
function Set-BarPosition {
    $rect = Get-TaskbarRect
    if ($null -eq $rect) { return }
    $height = $rect.Bottom - $rect.Top
    $top = $rect.Top + [Math]::Max(0, [int](($height - $form.ClientSize.Height) / 2))
    # Keep the strip on screen if the saved offset came from a wider display.
    $maxX = [Math]::Max(0, ($rect.Right - $rect.Left) - $form.Width)
    $x = [Math]::Min([Math]::Max(0, $script:offsetX), $maxX)
    $form.Location = New-Object System.Drawing.Point($x, $top)
}

function Assert-TopMost {
    # HWND_TOPMOST with NOMOVE|NOSIZE|NOACTIVATE.
    [BarNative]::SetWindowPos($form.Handle, [IntPtr](-1), 0, 0, 0, 0, 0x13) | Out-Null
}

function Test-FullscreenForeground {
    # A game or full-screen video should not have a usage strip on top of
    # it, so step aside while one is in front.
    $fg = [BarNative]::GetForegroundWindow()
    if ($fg -eq [IntPtr]::Zero -or $fg -eq $form.Handle) { return $false }
    $rect = New-Object BarRect
    if (-not [BarNative]::GetWindowRect($fg, [ref]$rect)) { return $false }
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    return (($rect.Right - $rect.Left) -ge $screen.Width -and ($rect.Bottom - $rect.Top) -ge $screen.Height)
}

# --------------------------------------------------------------- display
function Set-BarRow($Row, $Window) {
    if ($null -eq $Window) {
        $Row.Percent.Text = "--%"
        $Row.Percent.ForeColor = $ClaudeMuted
        $Row.Fill.Width = 0
        return
    }
    $used = [Math]::Max(0, [Math]::Min(100, [double]$Window.Percent))
    $Row.Percent.Text = ("{0}%" -f [int][Math]::Round($used))
    $color = Get-UsageColor $used
    $Row.Percent.ForeColor = $color
    $Row.Fill.BackColor = $color
    $Row.Fill.Width = [int][Math]::Round($Row.Track.ClientSize.Width * $used / 100)
    $Row.Reset.Text = Format-Reset $Window.Reset
    $Row.Reset.ForeColor = $color
}

function Show-Message([string]$Text, $Color) {
    $rowFive.Reset.Text = $Text
    $rowFive.Reset.ForeColor = $Color
    $rowSeven.Reset.Text = ""
}

function Show-Cached {
    if ($null -eq $script:cacheFivePercent -and $null -eq $script:cacheSevenPercent) { return $false }
    if ($null -ne $script:cacheFivePercent) {
        Set-BarRow $rowFive @{ Percent = $script:cacheFivePercent; Reset = $script:cacheFiveReset }
    }
    if ($null -ne $script:cacheSevenPercent) {
        Set-BarRow $rowSeven @{ Percent = $script:cacheSevenPercent; Reset = $script:cacheSevenReset }
    }
    return $true
}

function Update-Usage {
    param([switch]$Force)
    if ($script:refreshing) { return }
    if (-not $Force -and (Get-Date) -lt $script:nextAllowed) { return }
    $script:refreshing = $true
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $expiry = Get-TokenExpiry
        # The margin must cover a whole timer interval, or the first tick to
        # notice can land after expiry - by then the CLI's renewal can fail
        # and leave the credentials empty (seen 2026-09-30).
        $margin = [Math]::Max($script:refreshMarginMinutes, [Math]::Ceiling($script:refreshSeconds / 60) + 5)
        if ($null -ne $expiry -and $expiry -lt (Get-Date).AddMinutes($margin)) {
            Write-AttemptLog ("RENEW due - token expires " + $expiry.ToString("MM-dd HH:mm"))
            if (-not (Invoke-TokenRefresh)) { throw "sign in" }
            $expiry = Get-TokenExpiry
            if ($null -ne $expiry -and $expiry -lt (Get-Date)) { throw "sign in" }
        }

        $payload = Invoke-UsageRequest
        $five = Find-UsageWindow $payload @("five_hour", "fiveHour")
        $seven = Find-UsageWindow $payload @("seven_day", "sevenDay")
        $opus = Find-UsageWindow $payload @("seven_day_opus", "sevenDayOpus")

        Set-BarRow $rowFive $five
        Set-BarRow $rowSeven $seven

        if ($null -ne $five) {
            $script:cacheFivePercent = $five.Percent
            $script:cacheFiveReset = "$($five.Reset)"
        }
        if ($null -ne $seven) {
            $script:cacheSevenPercent = $seven.Percent
            $script:cacheSevenReset = "$($seven.Reset)"
        }
        Save-Config

        $lines = @()
        foreach ($pair in @(@("5 hours", $five), @("7 days", $seven), @("7 days, Opus", $opus))) {
            if ($null -ne $pair[1]) {
                $lines += ("{0}: {1}% used - resets {2} ({3})" -f `
                    $pair[0], [int][Math]::Round($pair[1].Percent),
                    (Format-Reset $pair[1].Reset), (Format-Remaining $pair[1].Reset))
            }
        }
        $script:lastTip = $lines -join "`n"
        $targets = @($form, $mark)
        foreach ($row in $allRows) {
            $targets += $row.Label; $targets += $row.Track
            $targets += $row.Percent; $targets += $row.Reset
        }
        foreach ($t in $targets) { $tooltip.SetToolTip($t, $script:lastTip) }

        $script:haveData = $true
        $script:backoffSeconds = 0
        $script:retryAfterSeconds = 0
        $script:nextAllowed = [DateTime]::MinValue
    } catch {
        $raw = $_.Exception.Message
        if ($raw -eq "RATE_LIMIT" -or $_.ToString() -eq "RATE_LIMIT") {
            if ($script:retryAfterSeconds -gt 0) {
                $script:backoffSeconds = $script:retryAfterSeconds
            } elseif ($script:backoffSeconds -eq 0) {
                $script:backoffSeconds = 300
            } else {
                $script:backoffSeconds = [Math]::Min(1800, $script:backoffSeconds * 2)
            }
            $script:nextAllowed = (Get-Date).AddSeconds($script:backoffSeconds)
            $wait = [Math]::Max(1, [int][Math]::Round($script:backoffSeconds / 60))
            if (-not (Show-Cached)) { Set-BarRow $rowFive $null; Set-BarRow $rowSeven $null }
            Show-Message ("rate limited, ${wait}m") $ClaudeAmber
        } elseif ($raw -eq "NOT_INSTALLED") {
            Set-BarRow $rowFive $null
            Set-BarRow $rowSeven $null
            Show-Message "install Claude Code" $ClaudeClay
            $raw = "Claude Code was not found. Install it, then run: claude /login"
        } elseif ($raw -eq "sign in") {
            Write-AttemptLog "SIGN IN shown"
            Set-BarRow $rowFive $null
            Set-BarRow $rowSeven $null
            Show-Message "run: claude /login" $ClaudeClay
            $raw = "Claude Code is not signed in. Open a terminal and run: claude /login"
        } else {
            if (-not (Show-Cached)) { Set-BarRow $rowFive $null; Set-BarRow $rowSeven $null }
            $short = $raw
            if ($short.Length -gt 22) { $short = $short.Substring(0, 22) }
            Show-Message $short $ClaudeClay
            Write-AttemptLog ("ERROR - " + $raw)
        }
        $script:lastTip = $raw
        $tooltip.SetToolTip($form, $raw)
    } finally {
        $script:refreshing = $false
    }
}

# -------------------------------------------------------------- wiring
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = ($script:refreshSeconds * 1000)
$timer.Add_Tick({ Update-Usage })

$keeper = New-Object System.Windows.Forms.Timer
$keeper.Interval = 3000
$keeper.Add_Tick({
    if (Test-FullscreenForeground) {
        if ($form.Visible) { $form.Hide() }
        return
    }
    if (-not $form.Visible) {
        [BarNative]::ShowWindow($form.Handle, 8) | Out-Null
    }
    # The shell re-raises the taskbar, so keep claiming the top of the
    # topmost band and follow the taskbar if it moved or resized.
    Set-BarPosition
    Assert-TopMost
})

$refreshItem.Add_Click({ Update-Usage -Force })
$detailsItem.Add_Click({
    $text = $script:lastTip
    if (-not $text) { $text = "No data yet." }
    [System.Windows.Forms.MessageBox]::Show($text, "Claude Usage Bar $($script:version)") | Out-Null
})
$exitItem.Add_Click({ $form.Close() })

# Dragging slides the strip sideways along the taskbar.
$dragDown = {
    param($sender, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:dragging = $true
        $script:dragOrigin = [System.Windows.Forms.Cursor]::Position.X - $form.Location.X
    }
}
$dragMove = {
    if ($script:dragging) {
        $x = [System.Windows.Forms.Cursor]::Position.X - $script:dragOrigin
        if ($x -lt 0) { $x = 0 }
        $script:offsetX = $x
        $form.Location = New-Object System.Drawing.Point($x, $form.Location.Y)
    }
}
$dragUp = {
    if ($script:dragging) {
        $script:dragging = $false
        Save-Config
    }
}
$draggable = @($form, $mark)
foreach ($row in $allRows) {
    $draggable += $row.Label; $draggable += $row.Percent; $draggable += $row.Reset
}
foreach ($c in $draggable) {
    $c.Add_MouseDown($dragDown)
    $c.Add_MouseMove($dragMove)
    $c.Add_MouseUp($dragUp)
}

$form.Add_FormClosed({
    Save-Config
    $timer.Stop()
    $keeper.Stop()
    try { $script:singleInstance.ReleaseMutex() } catch {}
    $script:singleInstance.Dispose()
})

# The ex-styles must be in place before the window is ever shown, or it
# steals focus on the way up.
$handle = $form.Handle
$GWL_EXSTYLE = -20
$WS_EX_TOOLWINDOW = 0x00000080
$WS_EX_NOACTIVATE = 0x08000000
$ex = [BarNative]::GetWindowLong($handle, $GWL_EXSTYLE)
[BarNative]::SetWindowLong($handle, $GWL_EXSTYLE, ($ex -bor $WS_EX_TOOLWINDOW -bor $WS_EX_NOACTIVATE)) | Out-Null

Set-BarPosition
[BarNative]::ShowWindow($handle, 8) | Out-Null   # SW_SHOWNOACTIVATE
Assert-TopMost

Show-Cached | Out-Null
Update-Usage
$timer.Start()
$keeper.Start()

[System.Windows.Forms.Application]::Run()

[System.GC]::KeepAlive($script:singleInstance)
