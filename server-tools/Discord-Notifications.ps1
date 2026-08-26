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

function Protect-DiscordWebhookFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Discord webhook file does not exist.' }
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { return }

    $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $administratorsSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $existingAcl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    $ownerSid = $null
    try {
        $ownerSid = ([Security.Principal.NTAccount]$existingAcl.Owner).Translate(
            [Security.Principal.SecurityIdentifier]
        )
    } catch { }

    $expectedSidValues = @($currentSid.Value, $systemSid.Value, $administratorsSid.Value) | Sort-Object -Unique
    $existingRules = @($existingAcl.Access)
    $existingSidValues = @($existingRules | ForEach-Object {
        try { $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value } catch { '' }
    } | Sort-Object -Unique)
    $rulesAlreadyExact = $existingAcl.AreAccessRulesProtected -and
        $ownerSid -and $ownerSid.Value -eq $currentSid.Value -and
        $existingRules.Count -eq $expectedSidValues.Count -and
        @(Compare-Object $expectedSidValues $existingSidValues).Count -eq 0 -and
        @($existingRules | Where-Object {
            $_.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
            $_.FileSystemRights -ne [Security.AccessControl.FileSystemRights]::FullControl -or
            $_.IsInherited
        }).Count -eq 0
    if ($rulesAlreadyExact) { return }

    # Apply a DACL-only descriptor when the file already belongs to the current
    # user.  Reapplying a descriptor that contains owner/SACL metadata can make
    # Set-Acl request SeSecurityPrivilege on a second run even though no privileged
    # change is needed.
    $acl = [Security.AccessControl.FileSecurity]::new()
    if (-not $ownerSid -or $ownerSid.Value -ne $currentSid.Value) {
        $acl.SetOwner($currentSid)
    }
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($sid in @($currentSid, $systemSid, $administratorsSid)) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new(
            $sid,
            [Security.AccessControl.FileSystemRights]::FullControl,
            [Security.AccessControl.AccessControlType]::Allow
        )
        $null = $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
}

function Write-DiscordNotificationAudit {
    param(
        [Parameter(Mandatory)][string]$ServerRoot,
        [Parameter(Mandatory)][string]$Event,
        [Parameter(Mandatory)][bool]$Succeeded,
        [Parameter(Mandatory)][int]$Attempts,
        [string]$Result
    )

    try {
        $managementRoot = Join-Path ([IO.Path]::GetFullPath($ServerRoot)) 'server-management'
        [IO.Directory]::CreateDirectory($managementRoot) | Out-Null
        $record = [ordered]@{
            recordedAt = [DateTimeOffset]::Now.ToString('o')
            event = $Event
            succeeded = $Succeeded
            attempts = $Attempts
            result = if ($Result) { $Result } else { if ($Succeeded) { 'delivered' } else { 'failed' } }
        }
        $line = ($record | ConvertTo-Json -Compress) + "`r`n"
        [IO.File]::AppendAllText((Join-Path $managementRoot 'discord-notifications.jsonl'), $line, [Text.UTF8Encoding]::new($false))
    } catch {
        # Discord reporting must never destabilise server lifecycle handling.
    }
}

function Send-DiscordServerNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ServerRoot,
        [Parameter(Mandatory)]
        [ValidateSet('online', 'offline', 'starting', 'restarting', 'updating', 'updated', 'rollingback', 'rolledback', 'crashed', 'failed', 'warning', 'test')]
        [string]$Event,
        [Parameter(Mandatory)][string]$Description,
        $Settings,
        [hashtable]$Fields,
        [string]$WebhookUrl,
        [switch]$ThrowOnFailure,
        [switch]$PassThru
    )

    try {
        $url = Get-DiscordWebhookUrl -ServerRoot $ServerRoot -Settings $Settings -WebhookUrl $WebhookUrl
    } catch {
        $safeReason = $_.Exception.GetType().Name
        Write-DiscordNotificationAudit -ServerRoot $ServerRoot -Event $Event -Succeeded $false -Attempts 0 -Result $safeReason
        $safeMessage = "Discord notification '$Event' preflight failed: $safeReason. The webhook URL was not printed."
        if ($ThrowOnFailure) { throw $safeMessage }
        try { Write-Warning $safeMessage } catch { }
        if ($PassThru) { return $false }
        return
    }
    if (-not $url) {
        if ($ThrowOnFailure) { throw 'Discord webhook is not configured.' }
        if ($PassThru) { return $false }
        return
    }

    try {
    $eventStyle = @{
        online     = @{ Emoji = [char]::ConvertFromUtf32(0x1F7E2); Label = 'Online'; Color = 0x57F287 }
        offline    = @{ Emoji = [char]::ConvertFromUtf32(0x1F534); Label = 'Offline'; Color = 0xED4245 }
        starting   = @{ Emoji = [char]::ConvertFromUtf32(0x1F535); Label = 'Starting'; Color = 0x5865F2 }
        restarting = @{ Emoji = [char]::ConvertFromUtf32(0x1F7E0); Label = 'Restarting'; Color = 0xFEE75C }
        updating   = @{ Emoji = [char]::ConvertFromUtf32(0x1F6E0); Label = 'Updating'; Color = 0x5865F2 }
        updated    = @{ Emoji = [char]::ConvertFromUtf32(0x1F4E6); Label = 'Update installed'; Color = 0x57F287 }
        rollingback = @{ Emoji = [char]::ConvertFromUtf32(0x23EA); Label = 'Rolling back'; Color = 0xFEE75C }
        rolledback = @{ Emoji = [char]::ConvertFromUtf32(0x2705); Label = 'Rollback complete'; Color = 0x57F287 }
        crashed    = @{ Emoji = [char]::ConvertFromUtf32(0x1F6A8); Label = 'Crashed'; Color = 0xED4245 }
        failed     = @{ Emoji = [char]::ConvertFromUtf32(0x26D4); Label = 'Needs attention'; Color = 0x992D22 }
        warning    = @{ Emoji = [char]::ConvertFromUtf32(0x26A0); Label = 'Warning'; Color = 0xFEE75C }
        test       = @{ Emoji = [char]::ConvertFromUtf32(0x2705); Label = 'Notifications connected'; Color = 0x57F287 }
    }
    $style = $eventStyle[$Event]
    $serverName = [string](Get-DiscordSettingValue $Settings 'discordServerName' 'MilkyCraft Vanilla+')
    $username = [string](Get-DiscordSettingValue $Settings 'discordWebhookUsername' 'MilkyCraft Server Status')
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
        footer = [ordered]@{ text = "MilkyCraft server status | event=$Event" }
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

    $maxAttempts = [Math]::Max(1, [Math]::Min(5, [int](Get-DiscordSettingValue $Settings 'discordMaxAttempts' 3)))
    $retryBaseMilliseconds = [Math]::Max(100, [Math]::Min(5000, [int](Get-DiscordSettingValue $Settings 'discordRetryBaseMilliseconds' 500)))
    } catch {
        $safeReason = $_.Exception.GetType().Name
        Write-DiscordNotificationAudit -ServerRoot $ServerRoot -Event $Event -Succeeded $false -Attempts 0 -Result $safeReason
        $safeMessage = "Discord notification '$Event' payload preflight failed: $safeReason. The webhook URL was not printed."
        if ($ThrowOnFailure) { throw $safeMessage }
        try { Write-Warning $safeMessage } catch { }
        if ($PassThru) { return $false }
        return
    }
    $lastSafeReason = 'delivery failed'
    $attemptsUsed = 0

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $attemptsUsed = $attempt
        try {
            $null = Invoke-RestMethod -Method Post -Uri $endpoint -ContentType 'application/json; charset=utf-8' `
                -Body $bodyBytes -TimeoutSec 10 -ErrorAction Stop
            Write-DiscordNotificationAudit -ServerRoot $ServerRoot -Event $Event -Succeeded $true -Attempts $attempt
            if ($PassThru) { return $true }
            return
        } catch {
            $response = $null
            $statusCode = $null
            try { $response = $_.Exception.Response } catch { }
            try { $statusCode = [int]$response.StatusCode } catch { }
            $lastSafeReason = if ($null -ne $statusCode) { "HTTP $statusCode" } else { $_.Exception.GetType().Name }
            $retryable = ($null -eq $statusCode) -or $statusCode -eq 408 -or $statusCode -eq 429 -or $statusCode -ge 500
            if (-not $retryable -or $attempt -ge $maxAttempts) { break }

            $delayMilliseconds = [int]($retryBaseMilliseconds * [Math]::Pow(2, $attempt - 1))
            if ($statusCode -eq 429 -and $response) {
                try {
                    $retryAfter = [string]$response.Headers['Retry-After']
                    $retrySeconds = 0.0
                    if ([double]::TryParse($retryAfter, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$retrySeconds)) {
                        $delayMilliseconds = [int][Math]::Ceiling($retrySeconds * 1000)
                    }
                } catch { }
            }
            $delayMilliseconds = [Math]::Max(100, [Math]::Min(5000, $delayMilliseconds))
            Start-Sleep -Milliseconds $delayMilliseconds
        }
    }

    Write-DiscordNotificationAudit -ServerRoot $ServerRoot -Event $Event -Succeeded $false -Attempts $attemptsUsed -Result $lastSafeReason
    $safeMessage = "Discord notification '$Event' failed after $attemptsUsed attempt(s): $lastSafeReason. The webhook URL was not printed."
    if ($ThrowOnFailure) { throw $safeMessage }
    try { Write-Warning $safeMessage } catch { }
    if ($PassThru) { return $false }
}
