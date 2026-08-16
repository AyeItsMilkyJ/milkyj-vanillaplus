Set-StrictMode -Version Latest

function Get-DiscordSettingValue {
    param($Settings, [string]$Name, $DefaultValue)

    if ($null -ne $Settings) {
        $property = $Settings.PSObject.Properties[$Name]
        if ($null -ne $property -and $null -ne $property.Value -and [string]$property.Value) {
            return $property.Value
        }
    }
    return $DefaultValue
}

function Get-DiscordWebhookFilePath {
    param([Parameter(Mandatory)][string]$ServerRoot, $Settings)

    $configured = [string](Get-DiscordSettingValue $Settings 'discordWebhookFile' 'discord-webhook.txt')
    if ([IO.Path]::IsPathRooted($configured)) { return [IO.Path]::GetFullPath($configured) }
    return [IO.Path]::GetFullPath((Join-Path $ServerRoot $configured))
}

function Test-DiscordWebhookUrl {
    param([string]$WebhookUrl, [switch]$AllowLocalTest)

    if (-not $WebhookUrl) { return $false }
    if ($WebhookUrl -match '^https://(?:(?:canary|ptb)\.)?discord(?:app)?\.com/api(?:/v\d+)?/webhooks/\d+/[A-Za-z0-9._-]+(?:\?.*)?$') {
        return $true
    }
    if ($AllowLocalTest) {
        try {
            $uri = [Uri]$WebhookUrl
            return $uri.Scheme -eq 'http' -and $uri.Host -in @('127.0.0.1', 'localhost', '::1')
        } catch { return $false }
    }
    return $false
}

function Get-DiscordWebhookUrl {
    param([Parameter(Mandatory)][string]$ServerRoot, $Settings, [string]$WebhookUrl)

    $candidate = $WebhookUrl
    if (-not $candidate) { $candidate = [Environment]::GetEnvironmentVariable('MILKYJ_DISCORD_WEBHOOK_URL') }
    if (-not $candidate) {
        $webhookFile = Get-DiscordWebhookFilePath -ServerRoot $ServerRoot -Settings $Settings
        if (Test-Path -LiteralPath $webhookFile -PathType Leaf) {
            $candidate = [IO.File]::ReadAllText($webhookFile).Trim()
        }
    }
    if (-not $candidate) { return $null }

    $allowLocal = [bool](Get-DiscordSettingValue $Settings 'discordAllowInsecureLocalTest' $false)
    if (-not (Test-DiscordWebhookUrl -WebhookUrl $candidate -AllowLocalTest:$allowLocal)) {
        try { Write-Warning 'Discord notifications are disabled because the configured webhook URL is invalid. The URL was not printed.' } catch { }
        return $null
    }
    return $candidate
}

function Send-DiscordServerNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ServerRoot,
        [Parameter(Mandatory)]
        [ValidateSet('online', 'offline', 'starting', 'restarting', 'crashed', 'failed', 'warning', 'test')]
        [string]$Event,
        [Parameter(Mandatory)][string]$Description,
        $Settings,
        [hashtable]$Fields,
        [string]$WebhookUrl,
        [switch]$ThrowOnFailure,
        [switch]$PassThru
    )

    $url = Get-DiscordWebhookUrl -ServerRoot $ServerRoot -Settings $Settings -WebhookUrl $WebhookUrl
    if (-not $url) {
        if ($ThrowOnFailure) { throw 'Discord webhook is not configured.' }
        if ($PassThru) { return $false }
        return
    }

    $eventStyle = @{
        online     = @{ Emoji = [char]::ConvertFromUtf32(0x1F7E2); Label = 'Online'; Color = 0x57F287 }
        offline    = @{ Emoji = [char]::ConvertFromUtf32(0x1F534); Label = 'Offline'; Color = 0xED4245 }
        starting   = @{ Emoji = [char]::ConvertFromUtf32(0x1F535); Label = 'Starting'; Color = 0x5865F2 }
        restarting = @{ Emoji = [char]::ConvertFromUtf32(0x1F7E0); Label = 'Restarting'; Color = 0xFEE75C }
        crashed    = @{ Emoji = [char]::ConvertFromUtf32(0x1F6A8); Label = 'Crashed'; Color = 0xED4245 }
        failed     = @{ Emoji = [char]::ConvertFromUtf32(0x26D4); Label = 'Needs attention'; Color = 0x992D22 }
        warning    = @{ Emoji = [char]::ConvertFromUtf32(0x26A0); Label = 'Warning'; Color = 0xFEE75C }
        test       = @{ Emoji = [char]::ConvertFromUtf32(0x2705); Label = 'Notifications connected'; Color = 0x57F287 }
    }
    $style = $eventStyle[$Event]
    $serverName = [string](Get-DiscordSettingValue $Settings 'discordServerName' 'MilkyJ Vanilla+')
    $username = [string](Get-DiscordSettingValue $Settings 'discordWebhookUsername' 'MilkyJ Server Status')
    $descriptionLimited = if ($Description.Length -gt 3900) { $Description.Substring(0, 3900) + '...' } else { $Description }
    $embedFields = @()
    if ($Fields) {
        foreach ($entry in $Fields.GetEnumerator() | Sort-Object Name) {
            $embedFields += [ordered]@{
                name = ([string]$entry.Key).Substring(0, [Math]::Min(256, ([string]$entry.Key).Length))
                value = ([string]$entry.Value).Substring(0, [Math]::Min(1024, ([string]$entry.Value).Length))
                inline = $true
            }
        }
    }
    $embed = [ordered]@{
        title = "$($style.Emoji) $serverName - $($style.Label)"
        description = $descriptionLimited
        color = [int]$style.Color
        timestamp = [DateTimeOffset]::UtcNow.ToString('o')
        footer = [ordered]@{ text = "MilkyJ server status | event=$Event" }
    }
    if ($embedFields.Count -gt 0) { $embed['fields'] = $embedFields }
    $payload = [ordered]@{
        username = $username
        allowed_mentions = [ordered]@{ parse = @() }
        embeds = @($embed)
    }
    $separator = if ($url.Contains('?')) { '&' } else { '?' }
    $endpoint = $url + $separator + 'wait=true'
    $json = $payload | ConvertTo-Json -Depth 10 -Compress
    # Windows PowerShell 5.1 can otherwise submit a string request body using an
    # ANSI-compatible encoding, which turns emoji into question marks.
    $bodyBytes = [Text.UTF8Encoding]::new($false).GetBytes($json)

    try {
        $null = Invoke-RestMethod -Method Post -Uri $endpoint -ContentType 'application/json; charset=utf-8' `
            -Body $bodyBytes -TimeoutSec 10
        if ($PassThru) { return $true }
    } catch {
        $safeMessage = "Discord notification '$Event' failed: $($_.Exception.Message)"
        if ($ThrowOnFailure) { throw $safeMessage }
        try { Write-Warning $safeMessage } catch { }
        if ($PassThru) { return $false }
    }
}
