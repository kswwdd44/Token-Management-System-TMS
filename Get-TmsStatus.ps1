[CmdletBinding()]
param([ValidateSet('Both','Claude','Codex')][string]$Product='Both', [string]$InstallBase=$env:LOCALAPPDATA)
$ErrorActionPreference = 'Stop'
function Test-AvailableCommand([string[]]$Names) {
    foreach ($name in $Names) { if (Get-Command $name -ErrorAction SilentlyContinue) { return $true } }
    return $false
}
$products = if ($Product -eq 'Both') { @('Claude','Codex') } else { @($Product) }
$results = @()
foreach ($name in $products) {
    $folder = Join-Path $InstallBase ($name + 'UsageBar')
    $scriptPath = Join-Path $folder ($name + 'UsageBar.ps1')
    $version = $null
    $installed = Test-Path -LiteralPath $scriptPath -PathType Leaf
    if ($installed) {
        $text = Get-Content -LiteralPath $scriptPath -Raw
        if ($text -match '\$script:version\s*=\s*["'']([0-9]+\.[0-9]+\.[0-9]+)["'']') { $version = $Matches[1] }
    }
    $cli = if ($name -eq 'Claude') { Test-AvailableCommand @('claude','claude.exe','claude.cmd') } else { Test-AvailableCommand @('codex','codex.exe','codex.cmd') }
    # Also check the desktop Codex CLI locations supported by the monitor.
    if ($name -eq 'Codex' -and -not $cli) {
        foreach ($relative in @('Programs\OpenAI\Codex\bin','OpenAI\Codex\bin')) {
            $candidate = Join-Path $env:LOCALAPPDATA $relative
            if ((Test-Path -LiteralPath $candidate) -and (Get-ChildItem -LiteralPath $candidate -Filter codex.exe -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1)) { $cli = $true }
        }
    }
    $startup = Join-Path ([Environment]::GetFolderPath('Startup')) "$name Usage Bar.lnk"
    $results += [ordered]@{
        product=$name; cliFound=[bool]$cli; defaultInstallFound=[bool]$installed;
        savedVersion=$version; actionsFileFound=[bool](Test-Path -LiteralPath (Join-Path $folder 'UsageBarActions.ps1'));
        signInShortcutFound=[bool](Test-Path -LiteralPath $startup);
        officialUsageUrl=$(if($name -eq 'Claude'){'https://claude.ai/settings/usage'}else{'https://chatgpt.com/settings/usage?tab=overview'})
    }
}
[ordered]@{
    diagnosticVersion='1.2.0'; windows=($env:OS -eq 'Windows_NT');
    powershellVersion=$PSVersionTable.PSVersion.ToString();
    inspection='Saved files and command availability only; no live account/quota check.';
    accountAccess='No credential contents read, no provider requests, no model runs.';
    products=@($results)
} | ConvertTo-Json -Depth 5
