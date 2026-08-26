[CmdletBinding()]
param([string]$ProjectRoot)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$root = [IO.Path]::GetFullPath($ProjectRoot)
$testRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\discord-notification-test'))
$expected = [IO.Path]::GetFullPath((Join-Path $root 'build\discord-notification-test'))
if (-not $testRoot.Equals($expected, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe Discord test root.' }
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
$listener.Stop()
$recording = Join-Path $testRoot 'requests.jsonl'
$stdout = Join-Path $testRoot 'webhook.stdout.log'
$stderr = Join-Path $testRoot 'webhook.stderr.log'
$python = (Get-Command python -ErrorAction Stop).Source
$fakeServer = Join-Path $root 'tests\fake_discord_webhook.py'
$webhookProcess = Start-Process -FilePath $python -ArgumentList @(
    ('"' + $fakeServer + '"'), '--port', "$port", '--output', ('"' + $recording + '"'), '--responses', '429,500,200'
) -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru

try {
    $deadline = (Get-Date).AddSeconds(10)
    do {
        try {
            $client = [Net.Sockets.TcpClient]::new()
            $client.Connect('127.0.0.1', $port)
            $ready = $client.Connected
            $client.Dispose()
        } catch { Start-Sleep -Milliseconds 100 }
    } while (-not $ready -and (Get-Date) -lt $deadline)
    if (-not $ready) { throw "Fake Discord webhook did not start. See $stderr" }

    . (Join-Path $root 'server-tools\Discord-Notifications.ps1')
    $settings = [pscustomobject]@{
        discordAllowInsecureLocalTest = $true
        discordServerName = 'Disposable MilkyJ Test'
        discordWebhookUsername = 'Test Status'
        discordWebhookFile = 'unused.txt'
    }
    $url = "http://127.0.0.1:$port/webhook"
    $events = @('test', 'starting', 'online', 'restarting', 'updating', 'updated', 'rollingback', 'rolledback', 'crashed', 'warning', 'offline', 'failed')
    foreach ($event in $events) {
        $sent = Send-DiscordServerNotification -ServerRoot $testRoot -Settings $settings -WebhookUrl $url `
            -Event $event -Description "Disposable $event notification." -Fields @{ Port = 25577 } -ThrowOnFailure -PassThru
        if (-not $sent) { throw "Notification did not report success: $event" }
    }

    $expectedRequests = $events.Count + 2
    $deadline = (Get-Date).AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 100
        $records = if (Test-Path -LiteralPath $recording) { @(Get-Content -LiteralPath $recording) } else { @() }
    } while ($records.Count -lt $expectedRequests -and (Get-Date) -lt $deadline)
    if ($records.Count -ne $expectedRequests) { throw "Expected $expectedRequests webhook requests including retries; recorded $($records.Count)." }

    $parsed = @($records | ForEach-Object { $_ | ConvertFrom-Json })
    $recordedEvents = @($parsed | ForEach-Object {
        if ($_.body.allowed_mentions.parse.Count -ne 0) { throw 'A test payload allowed Discord mentions.' }
        if ($_.path -notmatch 'wait=true') { throw 'Webhook request did not request Discord delivery confirmation.' }
        [regex]::Match([string]$_.body.embeds[0].footer.text, 'event=([a-z]+)').Groups[1].Value
    })
    $uniqueRecordedEvents = @($recordedEvents | Sort-Object -Unique)
    if (@(Compare-Object ($events | Sort-Object -Unique) $uniqueRecordedEvents).Count -ne 0) {
        throw "Webhook event mismatch. Expected=$($events -join ','); actual=$($uniqueRecordedEvents -join ',')"
    }
    if (@($recordedEvents | Where-Object { $_ -eq 'test' }).Count -ne 3) { throw 'The 429/500 retry sequence did not produce exactly three test attempts.' }
    $notificationAuditPath = Join-Path $testRoot 'server-management\discord-notifications.jsonl'
    $notificationAuditText = Get-Content -LiteralPath $notificationAuditPath -Raw
    $notificationAudits = @($notificationAuditText -split "`r?`n" | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json })
    if ($notificationAudits.Count -ne $events.Count -or @($notificationAudits | Where-Object { -not $_.succeeded }).Count -ne 0) {
        throw 'Durable notification audit did not contain one successful terminal record per event.'
    }
    foreach ($event in $events) {
        $eventAudits = @($notificationAudits | Where-Object { $_.event -eq $event })
        $expectedAttempts = if ($event -eq 'test') { 3 } else { 1 }
        if ($eventAudits.Count -ne 1 -or [int]$eventAudits[0].attempts -ne $expectedAttempts) {
            throw "Durable notification audit attempt count is wrong for event '$event'."
        }
    }
    if ($notificationAuditText.Contains($url)) { throw 'The durable notification audit contains the webhook URL.' }

    $result = [ordered]@{
        testedAt = (Get-Date).ToString('o')
        powershellVersion = $PSVersionTable.PSVersion.ToString()
        status = 'PASS'
        loopbackPort = $port
        events = $uniqueRecordedEvents
        requestCount = $records.Count
        retrySequence = @('429', '500', '200')
        deliveryConfirmationRequested = $true
        mentionsDisabled = $true
        durableAuditRecords = $notificationAudits.Count
        realDiscordContacted = $false
        productionPortTouched = $false
        liveServerTouched = $false
    }
    $auditPath = Join-Path $root 'audit\discord-notification-transport.json'
    [IO.File]::WriteAllText($auditPath, (($result | ConvertTo-Json -Depth 5) + "`r`n"), [Text.UTF8Encoding]::new($false))
    $result | ConvertTo-Json -Depth 5
} finally {
    if ($webhookProcess -and -not $webhookProcess.HasExited) { Stop-Process -Id $webhookProcess.Id -Force }
}
