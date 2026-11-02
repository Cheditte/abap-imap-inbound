# Run production helpers against disposable local fixtures only.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$root = Join-Path (Join-Path $repo 'work') ('test-policy-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'script/imap.ps1'), [ref]$null, [ref]$null)
foreach ($name in 'Read-KeyValueFile','Assert-ManagedPath','Get-WorkPath','Get-Int','Remove-OldInboxCache','Remove-FailedCache','Read-Profile','Assert-Revision') {
    $node = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $name }, $true)
    if (-not $node) { throw "Missing production helper: $name" }
    . ([scriptblock]::Create($node.Extent.Text))
}
$Policy = @{ WorkDir = $root; InCacheRetentionDays = 30 }
$Prof = @{ Name = 'TST_001_POLICY' }
$OnWindows = $env:OS -eq 'Windows_NT'
$Latin1 = [Text.Encoding]::GetEncoding(28591)
$OutCodepage = 1251
$cp = [Text.Encoding]::GetEncoding(1251)
$text = [string][char]0x0416
$config = Join-Path $root 'profile.conf'
[IO.File]::WriteAllText($config, ("CODEPAGE=1251`nDISPLAY=" + $text), $cp)
$parsed = Read-KeyValueFile $config
if ($parsed.DISPLAY -cne $text) { throw 'Declared profile codepage was not used' }
$credential = Join-Path $root 'synthetic.cred'
[IO.File]::WriteAllText($credential, ("PASSWORD=" + $text), $cp)
$parsed = Read-KeyValueFile $credential 1251
if ($parsed.PASSWORD -cne $text) { throw 'Credential codepage was not used' }
Write-Host '  ok    declared codepage is used for profile and credentials'

foreach ($case in @(@('1-1', $true), @('1-2', $false))) {
    $dir = Join-Path (Get-WorkPath 'in') $case[0]
    [IO.Directory]::CreateDirectory($dir) | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir 'mail.eml'), 'Synthetic mail; no real data')
    if ($case[1]) {
        $marker = Join-Path $dir 'failed.utc'
        [IO.File]::WriteAllText($marker, 'E')
        [IO.File]::SetLastWriteTimeUtc($marker, [DateTime]::UtcNow.AddDays(-31))
    }
}
Remove-OldInboxCache
if (Test-Path -LiteralPath (Join-Path (Get-WorkPath 'in') '1-1')) { throw 'Expired E cache retained' }
if (-not (Test-Path -LiteralPath (Join-Path (Get-WorkPath 'in') '1-2/mail.eml'))) { throw 'Unmarked H/recovery cache removed' }
Write-Host '  ok    failed-cache retention preserves unmarked recovery data'

$unsafe = Join-Path $root 'outside-in'
[IO.Directory]::CreateDirectory($unsafe) | Out-Null
$rejected = $false
try { Remove-FailedCache $unsafe } catch { $rejected = $true }
if (-not $rejected -or -not (Test-Path -LiteralPath $unsafe)) { throw 'Retention escaped its input directory' }
Write-Host '  ok    retention refuses paths outside the current profile cache'

function Stop-WithError([string]$Code, [string]$Text) { throw ($Code + ': ' + $Text) }
$Policy.AllowedHosts = @('mail.example.invalid')
$Policy.MaxMailBytes = 52428800
$Policy.TimeoutSecMax = 600
$Policy.RetentionDaysMax = 365
foreach ($dir in 'conf','secret') { [IO.Directory]::CreateDirectory((Join-Path $root $dir)) | Out-Null }
$key = 'TST_001_POLICY'
$revision = '0000000001'
[IO.File]::WriteAllLines((Join-Path $root "conf/${key}_$revision.conf"), @(
    "PROFILE=$key", "REVISION=$revision", 'CREDSRC=O',
    'HOST=mail.example.invalid', 'PORT=993', 'SECURITY=IMAPS', 'VERIFY=X',
    'USER=fixture@example.invalid', 'MAILBOX=INBOX', 'DONEBOX=Processed',
    'MOVEMODE=MOVE', 'CODEPAGE=1251'), $cp)
[IO.File]::WriteAllText((Join-Path $root "secret/$key.cred"), ('PASSWORD=' + $text), [Text.UTF8Encoding]::new($false))
$profile = Read-Profile $key $revision
if ($profile.Password -cne $text) { throw 'Basis UTF-8 credential decoded with SAP codepage' }
Write-Host '  ok    Basis UTF-8 credentials are independent of SAP display codepage'
