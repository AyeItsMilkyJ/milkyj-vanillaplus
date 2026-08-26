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
$allowLocalTest = [bool](Get-DiscordSettingValue $settings 'discordAllowInsecureLocalTest' $false)
if (-not (Test-DiscordWebhookUrl -WebhookUrl $WebhookUrl -AllowLocalTest:$allowLocalTest)) {
    throw 'That is not a valid Discord incoming-webhook URL. Nothing was saved.'
}

$webhookFile = Get-DiscordWebhookFilePath -ServerRoot $serverRootResolved -Settings $settings
if (-not $SkipConnectionTest) {
    Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -WebhookUrl $WebhookUrl -Event test `
        -Description 'The webhook connection test passed. Runtime, update and rollback alerts will use it after the local secret is saved.' `
        -Fields @{ Port = Get-ServerPort $serverRootResolved } -ThrowOnFailure
}

$webhookParent = Split-Path -Parent $webhookFile
New-Item -ItemType Directory -Path $webhookParent -Force | Out-Null
$temporaryWebhookFile = Join-Path $webhookParent ('.discord-webhook-' + [guid]::NewGuid().ToString('N') + '.tmp')
try {
    $temporaryStream = [IO.File]::Open($temporaryWebhookFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $temporaryStream.Dispose()
    Protect-DiscordWebhookFile -Path $temporaryWebhookFile
    [IO.File]::WriteAllText($temporaryWebhookFile, ($WebhookUrl.Trim() + "`r`n"), [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryWebhookFile -Destination $webhookFile -Force
} finally {
    if (Test-Path -LiteralPath $temporaryWebhookFile) { Remove-Item -LiteralPath $temporaryWebhookFile -Force }
}

Write-Host "Discord notifications configured. Secret saved locally at: $webhookFile"
Write-Host 'The webhook URL was not printed and must never be committed or shared.'
