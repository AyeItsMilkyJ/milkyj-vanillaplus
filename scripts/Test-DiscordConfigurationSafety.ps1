[CmdletBinding()]
param([string]$ProjectRoot)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$root = [IO.Path]::GetFullPath($ProjectRoot)
$testRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\discord-configuration-safety'))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\discord-configuration-safety'))
if (-not $testRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe Discord configuration test root.' }
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }

$serverRoot = Join-Path $testRoot 'server'
New-Item -ItemType Directory -Path (Join-Path $serverRoot 'libraries') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $serverRoot 'server.properties'), "server-port=25578`r`n", [Text.UTF8Encoding]::new($false))
$settingsPath = Join-Path $testRoot 'server-settings.json'
$settings = [ordered]@{
    packUrl = 'https://example.invalid/pack.toml'
    discordWebhookFile = 'discord-webhook.txt'
    discordServerName = 'Disposable Configuration Test'
    discordWebhookUsername = 'Disposable Status'
    discordAllowInsecureLocalTest = $true
    discordMaxAttempts = 3
    discordRetryBaseMilliseconds = 100
}
[IO.File]::WriteAllText($settingsPath, (($settings | ConvertTo-Json -Depth 5) + "`r`n"), [Text.UTF8Encoding]::new($false))

$webhookFile = Join-Path $serverRoot 'discord-webhook.txt'
$originalBytes = [Text.UTF8Encoding]::new($false).GetBytes("http://127.0.0.1:9/original`r`n")
[IO.File]::WriteAllBytes($webhookFile, $originalBytes)
$python = (Get-Command python -ErrorAction Stop).Source
$fakeServer = Join-Path $root 'tests\fake_discord_webhook.py'
$processes = [Collections.Generic.List[Diagnostics.Process]]::new()
$capturedOutput = [Collections.Generic.List[string]]::new()

function Start-FakeWebhook([string]$Responses, [string]$Name) {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    $listener.Stop()
    $recording = Join-Path $testRoot "$Name-requests.jsonl"
    $process = Start-Process -FilePath $python -ArgumentList @(
        ('"' + $fakeServer + '"'), '--port', "$port", '--output', ('"' + $recording + '"'), '--responses', $Responses
    ) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $testRoot "$Name-stdout.log") `
        -RedirectStandardError (Join-Path $testRoot "$Name-stderr.log") -PassThru
    $processes.Add($process)
    $deadline = (Get-Date).AddSeconds(10)
    $ready = $false
    do {
        try {
            $client = [Net.Sockets.TcpClient]::new()
            $client.Connect('127.0.0.1', $port)
            $ready = $client.Connected
            $client.Dispose()
        } catch { Start-Sleep -Milliseconds 100 }
    } while (-not $ready -and (Get-Date) -lt $deadline)
    if (-not $ready) { throw "Disposable webhook '$Name' did not start." }
    return [pscustomobject]@{ Port = $port; Process = $process; Recording = $recording }
}

try {
    $failing = Start-FakeWebhook -Responses '500' -Name 'failing'
    $failingUrl = "http://127.0.0.1:$($failing.Port)/webhook"
    $failedAsExpected = $false
    try {
        & (Join-Path $root 'server-tools\Configure-DiscordNotifications.ps1') -ServerRoot $serverRoot `
            -SettingsPath $settingsPath -WebhookUrl $failingUrl *>&1 | ForEach-Object { $capturedOutput.Add([string]$_) }
    } catch {
        $failedAsExpected = $_.Exception.Message -like "Discord notification 'test' failed after 3 attempt(s): HTTP 500*"
    }
    if (-not $failedAsExpected) { throw 'A failed connection test was not reported safely.' }
    if (-not ([Linq.Enumerable]::SequenceEqual([byte[]]$originalBytes, [byte[]][IO.File]::ReadAllBytes($webhookFile)))) {
        throw 'A failed connection test replaced the previously saved webhook.'
    }

    [IO.File]::WriteAllText($webhookFile, "invalid-value`r`n", [Text.UTF8Encoding]::new($false))
    $invalidStatus = & (Join-Path $root 'server-tools\Get-ServerStatus.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -AsJson | ConvertFrom-Json
    if ($invalidStatus.discordNotifications -ne 'INVALID SAVED VALUE') { throw 'Status did not identify an invalid saved webhook.' }

    $working = Start-FakeWebhook -Responses '200' -Name 'working'
    $workingUrl = "http://127.0.0.1:$($working.Port)/webhook"
    & (Join-Path $root 'server-tools\Configure-DiscordNotifications.ps1') -ServerRoot $serverRoot `
        -SettingsPath $settingsPath -WebhookUrl $workingUrl *>&1 | ForEach-Object { $capturedOutput.Add([string]$_) }
    $configuredStatus = & (Join-Path $root 'server-tools\Get-ServerStatus.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -AsJson | ConvertFrom-Json
    if ($configuredStatus.discordNotifications -ne 'CONFIGURED') { throw 'Status did not recognise a tested webhook.' }
    if ($configuredStatus.discordLastEvent -ne 'test' -or $configuredStatus.discordLastDelivery -ne 'DELIVERED') {
        throw 'Status did not expose the latest successful notification audit.'
    }
    $acl = Get-Acl -LiteralPath $webhookFile
    if (-not $acl.AreAccessRulesProtected) { throw 'The saved webhook still inherits broad parent-directory permissions.' }
    $expectedSids = @(
        [Security.Principal.WindowsIdentity]::GetCurrent().User.Value,
        'S-1-5-18',
        'S-1-5-32-544'
    ) | Sort-Object -Unique
    $actualRules = @($acl.Access)
    $actualSids = @($actualRules | ForEach-Object {
        $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
    } | Sort-Object -Unique)
    if (@(Compare-Object $expectedSids $actualSids).Count -ne 0 -or @($actualRules | Where-Object { $_.AccessControlType -ne 'Allow' }).Count -gt 0) {
        throw 'The saved webhook ACL contains an unexpected identity or deny rule.'
    }
    if ($acl.Owner -ne [Security.Principal.WindowsIdentity]::GetCurrent().Name) { throw 'The saved webhook owner is not the configuring user.' }
    if (@(Get-ChildItem -LiteralPath $serverRoot -Recurse -Force -File -Filter '.discord-webhook-*.tmp').Count -ne 0) {
        throw 'A plaintext Discord webhook temporary file remained after configuration.'
    }

    . (Join-Path $root 'server-tools\Discord-Notifications.ps1')
    Protect-DiscordWebhookFile -Path $webhookFile
    Protect-DiscordWebhookFile -Path $webhookFile
    $repeatAcl = Get-Acl -LiteralPath $webhookFile
    if (-not $repeatAcl.AreAccessRulesProtected -or @($repeatAcl.Access).Count -ne 3) {
        throw 'Webhook ACL protection was not idempotent.'
    }
    $settingsObject = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    $webhookLock = [IO.File]::Open($webhookFile, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    try {
        $unreadableResult = Send-DiscordServerNotification -ServerRoot $serverRoot -Settings $settingsObject -Event warning `
            -Description 'Disposable unreadable-secret test.' -PassThru 3>&1 2>&1 | ForEach-Object {
                if ($_ -is [bool]) { $_ } else { $capturedOutput.Add([string]$_) }
            }
    } finally {
        $webhookLock.Dispose()
    }
    if ([bool]$unreadableResult) { throw 'An unreadable webhook file was reported as delivered.' }

    $malformedSettings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    $malformedSettings.discordMaxAttempts = 'not-an-integer'
    $malformedResult = Send-DiscordServerNotification -ServerRoot $serverRoot -Settings $malformedSettings -WebhookUrl $workingUrl `
        -Event warning -Description 'Disposable malformed-settings test.' -PassThru 3>&1 2>&1 | ForEach-Object {
            if ($_ -is [bool]) { $_ } else { $capturedOutput.Add([string]$_) }
        }
    if ([bool]$malformedResult) { throw 'Malformed Discord retry settings were reported as delivered.' }

    $auditLines = @(Get-Content -LiteralPath (Join-Path $serverRoot 'server-management\discord-notifications.jsonl'))
    $auditRecords = @($auditLines | ForEach-Object { $_ | ConvertFrom-Json })
    if ($auditRecords.Count -ne 4 -or [bool]$auditRecords[0].succeeded -or -not [bool]$auditRecords[1].succeeded -or
        [bool]$auditRecords[2].succeeded -or [bool]$auditRecords[3].succeeded -or
        [int]$auditRecords[2].attempts -ne 0 -or [int]$auditRecords[3].attempts -ne 0) {
        throw 'Durable notification audit did not record delivery and preflight outcomes correctly.'
    }
    $capturedText = $capturedOutput -join "`n"
    $auditText = $auditLines -join "`n"
    if ($capturedText.Contains($failingUrl) -or $capturedText.Contains($workingUrl) -or
        $auditText.Contains($failingUrl) -or $auditText.Contains($workingUrl)) {
        throw 'A webhook URL appeared in captured output or the durable notification audit.'
    }

    $legacySupervisor = Join-Path $serverRoot 'server-supervisor.ps1'
    $legacyStatus = Join-Path $serverRoot 'logs\supervisor-status.json'
    New-Item -ItemType Directory -Path (Split-Path -Parent $legacyStatus) -Force | Out-Null
    [IO.File]::WriteAllText($legacySupervisor, '# retired disposable supervisor', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($legacyStatus, '{"state":"running"}', [Text.UTF8Encoding]::new($false))
    & (Join-Path $root 'server-tools\Install-ServerTools.ps1') -ServerRoot $serverRoot -InstallRootLaunchers
    if ((Test-Path -LiteralPath $legacySupervisor) -or (Test-Path -LiteralPath $legacyStatus)) {
        throw 'Retired runtime status files were left active after tool deployment.'
    }
    $quarantinedLegacyFiles = @(Get-ChildItem -LiteralPath (Join-Path $serverRoot 'server-management\deployment-backups') -Recurse -File |
        Where-Object { $_.FullName -match '[\\/]legacy-runtime[\\/]' })
    if ($quarantinedLegacyFiles.Count -ne 2) { throw 'Retired runtime status files were not preserved in the deployment backup.' }

    $result = [ordered]@{
        testedAt = (Get-Date).ToString('o')
        powershellVersion = $PSVersionTable.PSVersion.ToString()
        status = 'PASS'
        failedTestPreservedPreviousSecret = $true
        failedTestAttempts = [int]$auditRecords[0].attempts
        invalidSavedValueDetected = $true
        successfulTestSavedReplacement = $true
        webhookAclInheritanceDisabled = $true
        webhookAclExactAllowedSids = $true
        webhookAclProtectionIdempotent = $true
        noPlaintextTemporaryFileRemained = $true
        latestDeliveryExposedByStatus = $true
        unreadableWebhookWasNonFatal = $true
        malformedRetrySettingWasNonFatal = $true
        retiredRuntimeFilesQuarantined = $true
        secretsPrintedOrRecorded = $false
        realDiscordContacted = $false
        liveServerTouched = $false
    }
    $auditPath = Join-Path $root 'audit\discord-configuration-safety.json'
    [IO.File]::WriteAllText($auditPath, (($result | ConvertTo-Json -Depth 5) + "`r`n"), [Text.UTF8Encoding]::new($false))
    $result | ConvertTo-Json -Depth 5
} finally {
    foreach ($process in $processes) {
        if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id -Force }
    }
}
