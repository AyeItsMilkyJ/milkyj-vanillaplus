[CmdletBinding()]
param(
    [string]$ServerRoot,
    [string]$SettingsPath,
    [string]$WebhookUrl,
    [switch]$SkipConnectionTest
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'Discord-Notifications.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$settings = Get-ServerSettings -ServerRoot $serverRootResolved -SettingsPath $SettingsPath

if (-not $WebhookUrl) {
    $secure = Read-Host 'Paste the Discord webhook URL (input is hidden)' -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { $WebhookUrl = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}
if (-not (Test-DiscordWebhookUrl -WebhookUrl $WebhookUrl)) {
    throw 'That is not a valid Discord incoming-webhook URL. Nothing was saved.'
}

$webhookFile = Get-DiscordWebhookFilePath -ServerRoot $serverRootResolved -Settings $settings
$webhookParent = Split-Path -Parent $webhookFile
New-Item -ItemType Directory -Path $webhookParent -Force | Out-Null
[IO.File]::WriteAllText($webhookFile, ($WebhookUrl.Trim() + "`r`n"), [Text.UTF8Encoding]::new($false))

if (-not $SkipConnectionTest) {
    Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event test `
        -Description 'Discord status notifications are configured. Online/offline and restart alerts will appear here.' `
        -Fields @{ Port = Get-ServerPort $serverRootResolved } -ThrowOnFailure
}

Write-Host "Discord notifications configured. Secret saved locally at: $webhookFile"
Write-Host 'The webhook URL was not printed and must never be committed or shared.'
