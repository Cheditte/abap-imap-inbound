# Exercise unchanged production functions with a fake network, never real mail.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$fixtureRoot = Join-Path (Join-Path $repo 'work') ('test-fetch-cleanup-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'script/imap.ps1'), [ref]$null, [ref]$null)
foreach ($name in 'Assert-ManagedPath','Get-WorkPath','Get-MailPath','Get-MailIdentity','Remove-FetchStage','Move-ManagedDirectory','Invoke-Fetch') {
    $functionAst = $ast.Find({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name
    }, $true)
    if (-not $functionAst) { throw "Production function missing: $name" }
    . ([scriptblock]::Create($functionAst.Extent.Text))
}
$OnWindows = $env:OS -eq 'Windows_NT'
$Latin1 = [Text.Encoding]::GetEncoding(28591)
$Utf8Strict = New-Object Text.UTF8Encoding -ArgumentList $false, $true
$Utf8NoBom = New-Object Text.UTF8Encoding -ArgumentList $false
$OutCodepage = 65001
$RxIgnoreCase = [Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant'
$RxIgnoreCaseDotAll = [Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant, Singleline'
$MimeLimits = @{ MaxParts = 1000; MaxDepth = 20; MaxBytes = 1000 }
. (Join-Path $repo 'script/mime.ps1')
function Get-SearchUids { return , @('1') }
function Get-MailboxUrl { return 'imaps://not-a-real-test-server.invalid/' }
function Write-Log { param($Text) $script:cleanupLog += $Text }
function Stop-Ok { throw 'Unexpected success in failure-only test' }
function Invoke-Curl {
    param([string[]]$Arguments)
    $outputIndex = [Array]::IndexOf($Arguments, '-o')
    if ($outputIndex -lt 0) { return '* 1 FETCH (UID 1 RFC822.SIZE 10)' }
    $path = $Arguments[$outputIndex + 1]
    switch ($script:scenario) {
        'transfer' {
            [IO.File]::WriteAllText($path, 'partial download')
            throw 'Simulated transfer failure'
        }
        'empty' { [IO.File]::WriteAllText($path, '') }
        'size' { [IO.File]::WriteAllText($path, ('x' * 1001)) }
        'parse' {
            # A valid attachment is written before the second part fails.
            $mail = @('Content-Type: multipart/mixed; boundary=B', '', '--B',
                'Content-Type: application/octet-stream; name=good.bin',
                'Content-Transfer-Encoding: base64', '', 'QUJD', '--B',
                'Content-Type: application/octet-stream; name=bad.bin',
                'Content-Transfer-Encoding: base64', '', 'A%%%', '--B--')
            [IO.File]::WriteAllText($path, ($mail -join "`r`n"))
        }
    }
}
foreach ($scenario in 'transfer','empty','size','parse') {
    $script:scenario = $scenario
    $script:cleanupLog = @()
    $Policy = @{ WorkDir = (Join-Path $fixtureRoot $scenario) }
    $Prof = @{ Name = 'TST_001_CLEANUP'; MAILBOX = 'INBOX'; DONEBOX = 'Processed'; MaxBytes = 1000 }
    foreach ($dir in 'tmp','in','done') {
        New-Item -ItemType Directory -Path (Join-Path $Policy.WorkDir $dir) -Force | Out-Null
    }
    $sentinels = @()
    foreach ($dir in 'tmp','in','done') {
        $sentinel = Join-Path (Join-Path $Policy.WorkDir $dir) 'keep-existing.txt'
        [IO.File]::WriteAllText($sentinel, 'preserve existing data')
        $sentinels += $sentinel
    }
    $failed = $false
    try { Invoke-Fetch '1' '123' } catch { $failed = $true; $failure = $_.Exception.Message }
    if (-not $failed) { throw "Expected failure: $scenario" }
    $expected = @{ transfer = 'Simulated transfer failure'; empty = 'NOMAIL:*'; size = 'SIZE:*'; parse = 'PARSE:*' }
    if ($failure -notlike $expected[$scenario]) { throw "Wrong failure in ${scenario}: $failure" }
    if ($script:cleanupLog.Count) { throw "Cleanup error: $($script:cleanupLog -join ';')" }
    foreach ($sentinel in $sentinels) {
        if ([IO.File]::ReadAllText($sentinel) -cne 'preserve existing data') { throw 'Existing data changed' }
    }
    $tmpEntries = @(Get-ChildItem -LiteralPath (Join-Path $Policy.WorkDir 'tmp') -Force)
    if ($tmpEntries.Count -ne 1 -or $tmpEntries[0].Name -cne 'keep-existing.txt') { throw "Temporary files leaked: $scenario" }
    if (Test-Path -LiteralPath (Join-Path $Policy.WorkDir 'in/TST_001_CLEANUP/123-1/ready.flg')) { throw 'Failed mail was published' }
    Write-Host "  ok    $scenario failure cleans only its own temporary files"
}
# The cleanup helper must refuse a plausible staging name under published data.
$unsafe = Join-Path (Join-Path $Policy.WorkDir 'in') (([Guid]::NewGuid().ToString('N')) + '.parsed')
New-Item -ItemType Directory -Path $unsafe | Out-Null
$rejected = $false
try { Remove-FetchStage $unsafe } catch { $rejected = $true }
if (-not $rejected -or -not (Test-Path -LiteralPath $unsafe)) { throw 'Cleanup escaped its tmp boundary' }
$source = Join-Path $Policy.WorkDir 'tmp/move-source'
$target = Join-Path $Policy.WorkDir 'in/move-target'
New-Item -ItemType Directory -Path $source | Out-Null
[IO.File]::WriteAllText((Join-Path $source 'mail.eml'), 'preserve on rename')
Move-ManagedDirectory $source $target
if ((Test-Path -LiteralPath $source) -or [IO.File]::ReadAllText((Join-Path $target 'mail.eml')) -cne 'preserve on rename') { throw 'Managed rename failed' }
New-Item -ItemType Directory -Path $source | Out-Null
[IO.File]::WriteAllText((Join-Path $source 'mail.eml'), 'keep separate source')
$rejected = $false
try { Move-ManagedDirectory $source $target } catch { $rejected = $true }
if (-not $rejected -or [IO.File]::ReadAllText((Join-Path $source 'mail.eml')) -cne 'keep separate source' -or
    [IO.File]::ReadAllText((Join-Path $target 'mail.eml')) -cne 'preserve on rename') { throw 'Managed rename overwrote existing data' }
Write-Host '  ok    managed rename preserves data and rejects existing targets'
Write-Host 'ALL FETCH CLEANUP TESTS PASSED'
