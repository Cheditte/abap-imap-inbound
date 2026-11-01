# Integration tests require a disposable GreenMail instance with its REST API.
# A unique mailbox is created per run; existing mailboxes are never purged.
param(
    [string]$Shell = $(if ($env:OS -eq 'Windows_NT') { 'powershell.exe' } else { 'pwsh' }),
    [string]$MailHost = '127.0.0.1',
    [int]$ImapsPort = 3993,
    [int]$SmtpPort = 3025,
    [int]$ApiPort = 8080
)

$ErrorActionPreference = 'Stop'
if ($MailHost -notin @('localhost', '127.0.0.1', 'greenmail')) {
    throw 'Integration tests accept only a local/disposable GreenMail test host'
}
if ($ApiPort -lt 1) { throw 'GreenMail REST API is required for isolated test users' }
$repo = Split-Path $PSScriptRoot -Parent
$imap = Join-Path $repo 'script/imap.ps1'
$OnWindows = ($env:OS -eq 'Windows_NT')
$curl = if ($OnWindows) { Join-Path $env:SystemRoot 'System32/curl.exe' } else { '/usr/bin/curl' }
$nullDevice = if ($OnWindows) { 'NUL' } else { '/dev/null' }
$work = Join-Path (Join-Path $repo 'work') ('test-imap-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
foreach ($dir in 'conf', 'secret', 'in', 'done', 'tmp', 'log') {
    New-Item -ItemType Directory -Path (Join-Path $work $dir) | Out-Null
}
Write-Host "Integration fixtures: $work"
$utf8 = New-Object Text.UTF8Encoding -ArgumentList $false
$OutputEncoding = $utf8
try { [Console]::InputEncoding = $utf8 } catch { }
$samples = Join-Path $work 'samples'
& $Shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run-tests.ps1') -Shell $Shell -WorkDir $samples
if ($LASTEXITCODE -ne 0) { throw 'Parser tests failed; integration test stopped' }

$policy = Join-Path $work 'policy.psd1'
$env:SAPIMAP_POLICY = $policy
$revision = '0000000001'
$key = 'TST_001_DEMO'
$testUser = 'run' + [Guid]::NewGuid().ToString('N') + '@demo.local'
$testPassword = 'p@ss "w0rd\ =x'
$script:fail = 0
function Check([string]$name, [bool]$condition, [string]$detail) {
    if ($condition) { Write-Host "  ok    $name" }
    else { Write-Host "  FAIL  $name  $detail" -ForegroundColor Red; $script:fail++ }
}
function Write-Policy([bool]$AllowInsecure) {
    $escapedWork = $work.Replace("'", "''")
    $flag = if ($AllowInsecure) { '$true' } else { '$false' }
    [IO.File]::WriteAllText($policy, "@{ WorkDir = '$escapedWork'; AllowedHosts = @('$MailHost'); AllowInsecure = $flag; MaxMailBytes = 52428800 }", $utf8)
}
function Write-Profile([string]$Name, [string]$HostName = $MailHost, [string]$UserName = $testUser,
    [string]$Password = $testPassword, [string]$Mailbox = 'INBOX', [string]$MoveMode = 'MOVE',
    [string]$Rev = $revision, [string]$SecretUser = '', [string]$Donebox = 'SAP-Processed') {
    [IO.File]::WriteAllLines((Join-Path (Join-Path $work 'conf') "${Name}_$Rev.conf"), @(
        "PROFILE=$Name", "REVISION=$Rev", 'CREDSRC=S', "CREDREV=$Rev",
        "HOST=$HostName", "PORT=$ImapsPort", 'SECURITY=IMAPS', 'VERIFY=',
        "USER=$UserName", "MAILBOX=$Mailbox", "DONEBOX=$Donebox", "MOVEMODE=$MoveMode",
        'MAXMB=20', 'TIMEOUT=30', 'RETENTION=1', 'CODEPAGE=65001'), $utf8)
    $lines = @("PASSWORD=$Password")
    if ($SecretUser) { $lines += "USER=$SecretUser" }
    [IO.File]::WriteAllLines((Join-Path (Join-Path $work 'secret') "${Name}_$Rev.cred"), $lines, $utf8)
}
function Imap([string[]]$Arguments) {
    $output = @(& $Shell -NoProfile -ExecutionPolicy Bypass -File $imap @Arguments)
    $script:lastImapExit = $LASTEXITCODE
    Write-Host ('  > ' + ($Arguments -join ' ')) -ForegroundColor DarkGray
    foreach ($line in $output) { Write-Host "    $line" -ForegroundColor DarkGray }
    return , $output
}
function Require-Ok([string[]]$Arguments) {
    $output = Imap $Arguments
    Check ($Arguments[0] + ' succeeded') ($script:lastImapExit -eq 0 -and $output[-1] -ceq 'OK') ($output -join ' | ')
    Check 'protocol version' ($output -ccontains 'PROTOCOL 2') ($output -join ' | ')
    return , $output
}
function CurlImap([string]$Mailbox, [string]$Command) {
    $escaped = ($testUser + ':' + $testPassword).Replace('\', '\\').Replace('"', '\"')
    $oldErrorAction = $ErrorActionPreference
    try {
        # Windows PowerShell treats native stderr as ErrorRecord objects.
        $ErrorActionPreference = 'Continue'
        $output = @('user = "' + $escaped + '"' | & $curl --config - --silent --show-error --insecure --max-time 30 "imaps://${MailHost}:$ImapsPort/$Mailbox" -X $Command 2>&1 | ForEach-Object { "$_" })
        $curlExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $oldErrorAction }
    if ($curlExit -ne 0) { throw ('Test IMAP command failed: ' + ($output -join ' ')) }
    return , $output
}

Write-Host 'isolated mailbox preparation'
$body = @{ email = $testUser; login = $testUser; password = $testPassword } | ConvertTo-Json -Compress
$userJson = Join-Path $work 'user.json'
[IO.File]::WriteAllText($userJson, $body, $utf8)
& $curl --fail --silent --show-error -o $nullDevice -X POST -H 'Content-Type: application/json' --data-binary "@$userJson" "http://${MailHost}:$ApiPort/api/user"
if ($LASTEXITCODE -ne 0) { throw 'Could not create isolated GreenMail test user' }
CurlImap '' 'CREATE SAP-Processed' | Out-Null
foreach ($mail in 'plain-utf8', 'qp-8859-9', 'multipart', 'html-1254') {
    & $curl --fail --silent --show-error --max-time 30 "smtp://${MailHost}:$SmtpPort" --mail-from 'supplier@demo.local' --mail-rcpt $testUser -T (Join-Path $samples "$mail.eml")
    if ($LASTEXITCODE -ne 0) { throw "Could not deliver $mail test fixture" }
}
Write-Policy $true
Write-Profile $key
Require-Ok @('test') | Out-Null
Require-Ok @('test', $key, $revision) | Out-Null

Write-Host 'read-only list and production fetch'
$r = Require-Ok @('list', $key, $revision)
$uidv = @($r | Where-Object { $_ -cmatch '^UIDVALIDITY [0-9]+$' } | ForEach-Object { $_.Substring(12) })[0]
$uids = @($r | Where-Object { $_ -cmatch '^UID [0-9]+$' } | ForEach-Object { $_.Substring(4) })
Check 'mailbox identity provided' ([bool]$uidv) ($r -join ' | ')
Check 'four unique mails' ($uids.Count -eq 4 -and @($uids | Sort-Object -Unique).Count -eq 4) ($uids -join ',')
if (-not $uidv -or $uids.Count -ne 4) { throw 'Cannot continue without expected fixture mail identity' }
# Listing must not delete old local archives (also used by ABAP test mode).
$oldDir = Join-Path (Join-Path (Join-Path $work 'done') $key) '1-999999'
New-Item -ItemType Directory -Path $oldDir -Force | Out-Null
$oldMarker = Join-Path $oldDir 'mail.eml'
[IO.File]::WriteAllText($oldMarker, "Subject: disposable retention fixture`r`n`r`nbody", $utf8)
[IO.File]::WriteAllText((Join-Path $oldDir 'ready.flg'), 'OK', $utf8)
[IO.File]::WriteAllLines((Join-Path $oldDir 'identity.txt'), @($key, '1', '999999'), $utf8)
[IO.File]::WriteAllText((Join-Path $oldDir 'remote.done'), 'OK', $utf8)
[IO.File]::WriteAllText((Join-Path $oldDir 'completed.utc'), [DateTime]::UtcNow.AddDays(-10).ToString('o'), $utf8)
Require-Ok @('list', $key, $revision) | Out-Null
Check 'list preserves archives' (Test-Path -LiteralPath $oldMarker) ''
Require-Ok @('list', $key, $revision, 'PURGE') | Out-Null
Check 'explicit processing list expires eligible old archive' (-not (Test-Path -LiteralPath $oldMarker)) ''
$seen = (CurlImap 'INBOX' 'UID SEARCH SEEN') -join ' '
Check 'list does not mark messages as seen' ($seen -cmatch '\* SEARCH\s*$') $seen
foreach ($uid in $uids) {
    Require-Ok @('fetch', $key, $uid, $uidv, $revision) | Out-Null
    $dir = Join-Path (Join-Path (Join-Path $work 'in') $key) "$uidv-$uid"
    Check 'fetch publishes ready' (Test-Path -LiteralPath (Join-Path $dir 'ready.flg')) $dir
}
$headPath = Join-Path (Join-Path (Join-Path (Join-Path $work 'in') $key) "$uidv-$($uids[2])") 'header.txt'
Check 'multipart attachments intact' ([IO.File]::ReadAllLines($headPath) -ccontains 'ATTCOUNT=3') ''

Write-Host 'cached mail belongs to the same mailbox workflow'
$cachedMail = Join-Path (Join-Path (Join-Path (Join-Path $work 'in') $key) "$uidv-$($uids[0])") 'mail.eml'
$cachedHash = (Get-FileHash -LiteralPath $cachedMail -Algorithm SHA256).Hash
$secondRevision = '0000000002'
Write-Profile $key -Rev $secondRevision
$secondConfig = Join-Path (Join-Path $work 'conf') "${key}_$secondRevision.conf"
$secondText = [IO.File]::ReadAllText($secondConfig).Replace('DONEBOX=SAP-Processed', 'DONEBOX=Another-Processed')
[IO.File]::WriteAllText($secondConfig, $secondText, $utf8)
$r = Imap @('fetch', $key, $uids[0], $uidv, $secondRevision)
Check 'changed workflow cannot reuse cached mail' ($script:lastImapExit -ne 0 -and $r[-1] -clike 'ERR CFG *') ($r -join ' | ')
Check 'rejected workflow preserves cached original' ((Get-FileHash -LiteralPath $cachedMail -Algorithm SHA256).Hash -ceq $cachedHash) ''

Write-Host 'identity failures do not move mail'
$wrongUidv = ([uint64]$uidv + 1).ToString()
foreach ($action in 'fetch', 'done') {
    $r = Imap @($action, $key, $uids[0], $wrongUidv, $revision)
    Check 'wrong UIDVALIDITY rejected' ($script:lastImapExit -ne 0 -and $r[-1] -clike 'ERR *') ($r -join ' | ')
}
$r = Imap @('list', $key, '0000000003')
Check 'missing revision rejected' ($script:lastImapExit -ne 0 -and $r[-1] -clike 'ERR CFG *') ($r -join ' | ')
$r = Require-Ok @('list', $key, $revision)
Check 'identity failures preserve all mail' (@($r | Where-Object { $_ -cmatch '^UID [0-9]+$' }).Count -eq 4) ($r -join ' | ')

Write-Host 'move and retry'
Require-Ok @('done', $key, $uids[0], $uidv, $revision) | Out-Null
$archive = Join-Path (Join-Path (Join-Path $work 'done') $key) "$uidv-$($uids[0])"
Check 'archive retains original mail' (Test-Path -LiteralPath (Join-Path $archive 'mail.eml')) $archive
Require-Ok @('done', $key, $uids[0], $uidv, $revision) | Out-Null
$count = (CurlImap '' 'STATUS SAP-Processed (MESSAGES)') -join ' '
Check 'retry does not duplicate processed mail' ($count -cmatch 'MESSAGES 1\b') $count

Write-Host 'recovery after remote MOVE and before local checkpoint'
# Model a process ending immediately after the server accepted MOVE.
# The source fixture and identity remain local; no journal marker exists yet.
CurlImap 'INBOX' ("UID MOVE " + $uids[1] + ' SAP-Processed') | Out-Null
Require-Ok @('done', $key, $uids[1], $uidv, $revision) | Out-Null
$recovered = Join-Path (Join-Path (Join-Path $work 'done') $key) "$uidv-$($uids[1])"
Check 'interrupted move retains original mail' (Test-Path -LiteralPath (Join-Path $recovered 'mail.eml')) $recovered
Check 'interrupted move records remote completion' (Test-Path -LiteralPath (Join-Path $recovered 'remote.done')) $recovered
Require-Ok @('done', $key, $uids[1], $uidv, $revision) | Out-Null
$count = (CurlImap '' 'STATUS SAP-Processed (MESSAGES)') -join ' '
Check 'recovery retry does not duplicate remote mail' ($count -cmatch 'MESSAGES 2\b') $count

Write-Host 'policy, credentials and configuration failures'
Write-Profile 'TST_001_OUTSIDE' 'outside.invalid'
$r = Imap @('list', 'TST_001_OUTSIDE', $revision)
Check 'host policy enforced' ($script:lastImapExit -ne 0 -and $r[-1] -clike 'ERR POLICY *') ($r -join ' | ')
Write-Profile 'TST_001_BADFOLDER' -Mailbox 'INBOX with spaces'
$r = Imap @('list', 'TST_001_BADFOLDER', $revision)
Check 'invalid mailbox rejected' ($script:lastImapExit -ne 0 -and $r[-1] -clike 'ERR CFG *') ($r -join ' | ')
Write-Profile 'TST_001_WRONGPW' -Password 'not-the-test-password'
$r = Imap @('list', 'TST_001_WRONGPW', $revision)
Check 'wrong password rejected' ($script:lastImapExit -ne 0 -and $r[-1] -clike 'ERR AUTH *') ($r -join ' | ')
Write-Profile 'TST_001_OTHERUSER' -SecretUser 'other@demo.local'
$r = Imap @('list', 'TST_001_OTHERUSER', $revision)
Check 'secret cannot replace configured mailbox user' ($script:lastImapExit -ne 0 -and $r[-1] -clike 'ERR CFG *') ($r -join ' | ')
Write-Profile 'TST_001_BADREV'
$badRevisionPath = Join-Path (Join-Path $work 'conf') "TST_001_BADREV_$revision.conf"
$badRevisionText = [IO.File]::ReadAllText($badRevisionPath).Replace("REVISION=$revision", 'REVISION=0000000002')
[IO.File]::WriteAllText($badRevisionPath, $badRevisionText, $utf8)
$r = Imap @('list', 'TST_001_BADREV', $revision)
Check 'config content must match requested revision' ($script:lastImapExit -ne 0 -and $r[-1] -clike 'ERR CFG *') ($r -join ' | ')
Write-Profile 'TST_002_DEMO' 'outside.invalid'
$r = Imap @('list', 'TST_002_DEMO', $revision)
Check 'client namespaces remain distinct' ($script:lastImapExit -ne 0 -and $r[-1] -clike 'ERR POLICY *') ($r -join ' | ')
Require-Ok @('list', $key, $revision) | Out-Null
Write-Profile 'TST_001_COPY' -MoveMode 'COPY'
$r = Imap @('list', 'TST_001_COPY', $revision)
Check 'unsafe COPY fallback disabled' ($script:lastImapExit -ne 0 -and $r[-1] -clike 'ERR CFG *') ($r -join ' | ')
foreach ($folders in @(@('INBOX','INBOX'), @('inbox','INBOX'), @('Archive','archive'))) {
    Write-Profile 'TST_001_SAME' -Mailbox $folders[0] -Donebox $folders[1]
    foreach ($request in @(
        @('test', 'TST_001_SAME', $revision),
        @('list', 'TST_001_SAME', $revision),
        @('fetch', 'TST_001_SAME', $uids[2], $uidv, $revision),
        @('done', 'TST_001_SAME', $uids[2], $uidv, $revision)
    )) {
        $r = Imap $request
        Check 'same source/destination rejected before mail processing' ($script:lastImapExit -ne 0 -and $r[-1] -clike 'ERR CFG *different*') ($r -join ' | ')
    }
}
$remaining = Require-Ok @('list', $key, $revision)
Check 'rejected self-folder actions preserve original UIDs' (@($remaining | Where-Object { $_ -cmatch '^UID [0-9]+$' }).Count -eq 2 -and $remaining -ccontains ('UID ' + $uids[2])) ($remaining -join ' | ')

Write-Host 'oversized message rejected before download'
$largeMail = Join-Path $work 'oversized.eml'
$largeBody = ((('x' * 120) + "`r`n") * 9500)
[IO.File]::WriteAllText($largeMail, "Subject: disposable size-limit fixture`r`nContent-Type: text/plain`r`n`r`n" + $largeBody, $utf8)
& $curl --fail --silent --show-error --max-time 30 "smtp://${MailHost}:$SmtpPort" --mail-from 'supplier@demo.local' --mail-rcpt $testUser -T $largeMail
if ($LASTEXITCODE -ne 0) { throw 'Could not deliver oversized test fixture' }
$r = Require-Ok @('list', $key, $revision)
$largeUids = @($r | Where-Object { $_ -cmatch '^UID [0-9]+$' } | ForEach-Object { $_.Substring(4) } | Where-Object { $uids -notcontains $_ })
Check 'one new oversized fixture UID' ($largeUids.Count -eq 1) ($largeUids -join ',')
if ($largeUids.Count -ne 1) { throw 'Cannot identify oversized test fixture UID' }
$smallKey = 'TST_001_SMALL'
Write-Profile $smallKey
$smallConfig = Join-Path (Join-Path $work 'conf') "${smallKey}_$revision.conf"
$smallText = [IO.File]::ReadAllText($smallConfig).Replace('MAXMB=20', 'MAXMB=1')
[IO.File]::WriteAllText($smallConfig, $smallText, $utf8)
$tempDir = Join-Path $work 'tmp'
$tempBefore = @(Get-ChildItem -LiteralPath $tempDir -File | Select-Object -ExpandProperty FullName)
$r = Imap @('fetch', $smallKey, $largeUids[0], $uidv, $revision)
Check 'oversize mail returns SIZE' ($script:lastImapExit -ne 0 -and $r[-1] -clike 'ERR SIZE *') ($r -join ' | ')
$largeOutput = Join-Path (Join-Path (Join-Path $work 'in') $smallKey) "$uidv-$($largeUids[0])"
Check 'oversize mail is not published' (-not (Test-Path -LiteralPath (Join-Path $largeOutput 'ready.flg'))) ''
$newTempFiles = @(Get-ChildItem -LiteralPath $tempDir -File | Where-Object { $tempBefore -notcontains $_.FullName })
Check 'oversize preflight creates no temporary download' ($newTempFiles.Count -eq 0) ($newTempFiles.Name -join ',')

Write-Host 'failed production fetch cleans raw mail and partial attachments'
$badMail = Join-Path $work 'malformed-production.eml'
$badLines = @('Subject: isolated malformed MIME fixture',
    'Content-Type: multipart/mixed; boundary=BAD', '', '--BAD',
    'Content-Type: application/octet-stream; name=good.bin',
    'Content-Transfer-Encoding: base64', '', 'QUJD', '--BAD',
    'Content-Type: application/octet-stream; name=bad.bin',
    'Content-Transfer-Encoding: base64', '', 'A%%%', '--BAD--')
[IO.File]::WriteAllText($badMail, ($badLines -join "`r`n"), $utf8)
& $curl --fail --silent --show-error --max-time 30 "smtp://${MailHost}:$SmtpPort" --mail-from 'supplier@demo.local' --mail-rcpt $testUser -T $badMail
if ($LASTEXITCODE -ne 0) { throw 'Could not deliver malformed MIME fixture' }
$r = Require-Ok @('list', $key, $revision)
$badUids = @($r | Where-Object { $_ -cmatch '^UID [0-9]+$' } | ForEach-Object { $_.Substring(4) } | Where-Object { $uids -notcontains $_ -and $largeUids -notcontains $_ })
Check 'one malformed fixture UID' ($badUids.Count -eq 1) ($badUids -join ',')
if ($badUids.Count -ne 1) { throw 'Cannot identify malformed fixture' }
$sentinel = Join-Path $tempDir 'preserve-unrelated.txt'
[IO.File]::WriteAllText($sentinel, 'existing data', $utf8)
$archiveHash = (Get-FileHash -LiteralPath (Join-Path $archive 'mail.eml') -Algorithm SHA256).Hash
foreach ($attempt in 1,2) {
    $r = Imap @('fetch', $key, $badUids[0], $uidv, $revision)
    Check 'bad MIME reports PARSE' ($script:lastImapExit -ne 0 -and $r[-1] -clike 'ERR PARSE *') ($r -join ' | ')
    $debris = @(Get-ChildItem -LiteralPath $tempDir -Force | Where-Object { $_.Name -cne 'preserve-unrelated.txt' })
    Check 'bad MIME leaves no temporary files or directories' ($debris.Count -eq 0) ($debris.Name -join ',')
    Check 'cleanup preserves unrelated file' ([IO.File]::ReadAllText($sentinel) -ceq 'existing data') ''
    Check 'cleanup preserves completed mail' ((Get-FileHash -LiteralPath (Join-Path $archive 'mail.eml') -Algorithm SHA256).Hash -ceq $archiveHash) ''
}

Write-Policy $false
$r = Imap @('list', $key, $revision)
Check 'TLS policy enforced' ($script:lastImapExit -ne 0 -and $r[-1] -clike 'ERR POLICY *') ($r -join ' | ')

if ($script:fail -gt 0) { Write-Host "$script:fail integration checks failed" -ForegroundColor Red; exit 1 }
Write-Host 'ALL IMAP TESTS PASSED' -ForegroundColor Green
exit 0
