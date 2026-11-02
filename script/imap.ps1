<#
  imap.ps1 - abap-imap-inbound script. SAP calls this script through
  SM69 commands (SXPG_COMMAND_EXECUTE).
  Windows: Windows PowerShell 5.1. Linux: PowerShell 7 (pwsh) and curl.

  Positional protocol 2 (KEY = SID_CLIENT_PROFILE, REV = 10 digits):
    imap.ps1 list  KEY REV [PURGE]
    imap.ps1 fetch KEY UID UIDVALIDITY REV
    imap.ps1 done  KEY UID UIDVALIDITY REV
    imap.ps1 test [KEY REV]

  Settings:
    bin\policy.psd1        Basis: work folder, allowed servers, limits
    conf\KEY_REV.conf      immutable SAP profile snapshot
    secret\KEY_CREDREV.cred (S) or secret\KEY.cred (O, Basis)

  Output rule: the last line is "OK" or "ERR <CODE> <description>".
  Codes: ARG CFG POLICY CONNECT TLS AUTH MAILBOX NOMAIL SIZE EXC CURL<n>
  SAP protocol lines are 128 characters, so lines are kept short.

  Contents of in\KEY\UIDVALIDITY-UID\ (then done\KEY\UIDVALIDITY-UID\):
    header.txt   FROM=, TO=, CC=, SUBJECT=, DATE=, MESSAGEID=, ATTCOUNT=
    body.txt     plain text body, lines at most 250 characters
    attach.txt   name|size|mime|attachment or inline|original name
    att\         attachment files (names are ASCII only)
    mail.eml     original mail
    ready.flg    written last; if missing, parsing did not finish

  This file intentionally contains ASCII characters only.
#>
# Deliberately no param block: named PowerShell options must never override
# the action fixed in SM69. Only the exact positional protocol is accepted.
$RequestArgs = @($args)
$Action = ''; $Arg1 = ''; $Arg2 = ''; $Arg3 = ''; $Arg4 = ''
if ($RequestArgs.Count -gt 0) { $Action = [string]$RequestArgs[0] }
if ($RequestArgs.Count -gt 1) { $Arg1 = [string]$RequestArgs[1] }
if ($RequestArgs.Count -gt 2) { $Arg2 = [string]$RequestArgs[2] }
if ($RequestArgs.Count -gt 3) { $Arg3 = [string]$RequestArgs[3] }
if ($RequestArgs.Count -gt 4) { $Arg4 = [string]$RequestArgs[4] }

$Version = '0.9.1'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Latin1 = [System.Text.Encoding]::GetEncoding(28591)
$Utf8Strict = New-Object System.Text.UTF8Encoding -ArgumentList $false, $true
$Utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
# The password goes to curl on standard input as UTF-8. Windows PowerShell
# 5.1 writes to standard input in the console input encoding and adds a
# BOM at the start; curl takes it as part of the first line. Both are set
# to UTF-8 without BOM.
$OutputEncoding = $Utf8NoBom
try { [Console]::InputEncoding = $Utf8NoBom } catch { }
# $IsWindows is not defined in Windows PowerShell 5.1
$OnWindows = ($env:OS -eq 'Windows_NT')
$Policy = $null
$Prof = $null
$OutCodepage = 1254

# On Turkish Windows, case-insensitive matching does not treat "I" and
# "i" as equal (I -> dotless i). So case-insensitive regexes always run
# with CultureInvariant; -creplace is used instead of -replace.
$RxIgnoreCase = [System.Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant'
$RxIgnoreCaseDotAll = [System.Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant, Singleline'

# --- output and log ----------------------------------------------------------

function Write-Out([string]$Text) {
    if ($Text.Length -gt 120) { $Text = $Text.Substring(0, 120) }
    [Console]::Out.WriteLine($Text)
}

function Write-Log([string]$Text) {
    if (-not $Policy) { return }
    try {
        $dir = Join-Path $Policy.WorkDir 'log'
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        $file = Join-Path $dir ('imap-{0:yyyyMMdd}.log' -f (Get-Date))
        $line = '{0:yyyy-MM-dd HH:mm:ss} {1} {2} {3} {4}' -f (Get-Date), $Action, $Arg1, $Arg2, $Text
        Add-Content -Path $file -Value $line -Encoding UTF8
    } catch { }
}

function Stop-WithError([string]$Code, [string]$Text) {
    $Text = ($Text -creplace '[\x00-\x1F\x7F]+', ' ').Trim()
    Write-Log "ERR $Code $Text"
    Write-Out "ERR $Code $Text"
    exit 1
}

function Stop-Ok {
    Write-Log 'OK'
    Write-Out 'OK'
    exit 0
}

# --- validation --------------------------------------------------------------

function Assert-Profile([string]$Name) {
    if ($Name -cnotmatch '^[A-Z0-9]{3}_[0-9]{3}_[A-Z0-9_]{1,20}$') { Stop-WithError 'ARG' 'invalid profile name' }
}

function Assert-Digits([string]$Value, [string]$What) {
    if ($Value -cnotmatch '^[0-9]{1,10}$' -or [decimal]$Value -lt 1 -or [decimal]$Value -gt 4294967295) { Stop-WithError 'ARG' "invalid $What" }
}

# --- policy (Basis) ----------------------------------------------------------

function Read-Policy {
    $path = Join-Path $PSScriptRoot 'policy.psd1'
    if (-not (Test-Path $path)) { Stop-WithError 'CFG' "policy.psd1 not found: $path" }
    # Parsed like Import-PowerShellDataFile, but without that cmdlet: it
    # lives in a module that is not found when PSModulePath points to
    # PowerShell 7 modules. Only constant values are accepted.
    $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errs)
    $ht = $ast.Find({ $args[0] -is [System.Management.Automation.Language.HashtableAst] }, $false)
    if ($errs -or -not $ht) { Stop-WithError 'CFG' "policy.psd1 is not a valid data file: $path" }
    try { $p = $ht.SafeGetValue() }
    catch { Stop-WithError 'CFG' "policy.psd1 contains non-constant values: $path" }
    if (-not $p.WorkDir) { Stop-WithError 'CFG' 'policy.psd1: WorkDir missing' }
    if (-not $p.AllowedHosts) { Stop-WithError 'CFG' 'policy.psd1: AllowedHosts missing' }
    $defaults = @{
        AllowInsecure = $false; AllowPlainImap = $false; CheckRevoke = $false
        MaxMailBytes = 52428800; RetentionDaysMax = 365; TimeoutSecMax = 600
        CaCert = ''; CurlPath = ''
    }
    foreach ($k in $defaults.Keys) {
        if (-not $p.ContainsKey($k)) { $p[$k] = $defaults[$k] }
    }
    if (-not $p.CurlPath) {
        if ($OnWindows) { $p.CurlPath = Join-Path $env:SystemRoot 'System32\curl.exe' }
        else { $p.CurlPath = '/usr/bin/curl' }
    }
    $versionLines = @(& $p.CurlPath --version)
    $versionText = $versionLines[0]
    if ($LASTEXITCODE -ne 0 -or $versionText -notmatch '^curl ([0-9]+)\.([0-9]+)\.') { throw 'CFG: cannot determine curl version' }
    if ([int]$Matches[1] -lt 8) { throw 'CFG: curl 8.0.0 or newer is required' }
    $p.AllowedHosts = @($p.AllowedHosts | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
    $p
}

# KEY=VALUE file. SAP writes it in the system code page: UTF-8 is tried
# from the declared CODEPAGE. The value is the rest of the line (it may
# contain '='); spaces are kept.
function Read-KeyValueFile([string]$Path, [int]$Codepage = 0) {
    $h = @{}
    if ($Policy) { $null = Assert-ManagedPath $Path }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if (-not $Codepage) {
        $declared = [regex]::Match($Latin1.GetString($bytes), '(?m)^CODEPAGE=([0-9]+)\r?$')
        if (-not $declared.Success) { throw 'CFG: missing CODEPAGE' }
        $Codepage = [int]$declared.Groups[1].Value
    }
    try { $text = [Text.Encoding]::GetEncoding($Codepage).GetString($bytes) }
    catch { throw 'CFG: unsupported profile code page' }
    foreach ($line in ($text -split '\r?\n')) {
        if ($line -cmatch '^\s*(#|$)') { continue }
        $i = $line.IndexOf('=')
        if ($i -le 0) { continue }
        $key = $line.Substring(0, $i).Trim().ToUpperInvariant()
        if ($h.ContainsKey($key)) { throw 'CFG: duplicate setting key' }
        $h[$key] = $line.Substring($i + 1).TrimEnd("`r")
    }
    $h
}

function Get-Int($Value, [int]$Default) {
    $s = ([string]$Value).Trim()
    if ($s -cmatch '^\d{1,9}$') { return [int]$s }
    $Default
}

# Reads the profile settings and validates them against the policy.
function Read-Profile([string]$Name, [string]$Revision) {
    $confPath = Join-Path (Join-Path $Policy.WorkDir 'conf') "${Name}_$Revision.conf"
    if (-not (Test-Path $confPath)) {
        Stop-WithError 'CFG' "no profile settings: $Name (save them with ZCHE_IMAP_CONFIG)"
    }
    $c = Read-KeyValueFile $confPath
    if ($c['PROFILE'] -cne $Name -or $c['REVISION'] -cne $Revision) {
        Stop-WithError 'CFG' 'profile snapshot identity or revision mismatch'
    }
    $p = @{ Name = $Name; Revision = $Revision }

    $p.Host = ([string]$c['HOST']).Trim().ToLowerInvariant()
    if ($p.Host -cnotmatch '^[a-z0-9.-]{1,253}$') { Stop-WithError 'CFG' 'invalid server name' }
    if ($Policy.AllowedHosts -notcontains $p.Host) {
        Stop-WithError 'POLICY' "server not allowed: $($p.Host) (policy.psd1 AllowedHosts)"
    }

    $p.Security = ([string]$c['SECURITY']).Trim().ToUpperInvariant()
    if (@('IMAPS', 'STARTTLS', 'NONE') -cnotcontains $p.Security) { Stop-WithError 'CFG' 'invalid security type' }
    if ($p.Security -ceq 'NONE' -and -not $Policy.AllowPlainImap) {
        Stop-WithError 'POLICY' 'unencrypted IMAP is disabled (policy.psd1 AllowPlainImap)'
    }
    $defPort = 993
    if ($p.Security -cne 'IMAPS') { $defPort = 143 }
    $p.Port = Get-Int $c['PORT'] $defPort
    if ($p.Port -lt 1 -or $p.Port -gt 65535) { Stop-WithError 'CFG' 'invalid port' }

    $p.Verify = (([string]$c['VERIFY']).Trim() -ceq 'X')
    if (-not $p.Verify -and -not $Policy.AllowInsecure) {
        Stop-WithError 'POLICY' 'certificate check cannot be disabled (policy.psd1 AllowInsecure)'
    }

    foreach ($k in 'MAILBOX', 'DONEBOX') {
        $v = ([string]$c[$k]).Trim()
        if ($v -cnotmatch '^[A-Za-z0-9._/-]{1,100}$') { Stop-WithError 'CFG' "invalid folder name: $k" }
        $p[$k] = $v
    }
    # Case-only names can alias one mailbox on case-insensitive servers.
    if ([string]::Equals($p.MAILBOX, $p.DONEBOX, [StringComparison]::OrdinalIgnoreCase)) {
        Stop-WithError 'CFG' 'read and processed folders must be different'
    }
    $p.MoveMode = ([string]$c['MOVEMODE']).Trim().ToUpperInvariant()
    if ($p.MoveMode -cne 'MOVE') { Stop-WithError 'CFG' 'COPY mode is disabled; a server with UID MOVE is required' }

    $p.MaxBytes = (Get-Int $c['MAXMB'] 20) * 1048576
    if ($p.MaxBytes -le 0 -or $p.MaxBytes -gt $Policy.MaxMailBytes) { $p.MaxBytes = $Policy.MaxMailBytes }
    $p.Timeout = Get-Int $c['TIMEOUT'] 120
    if ($p.Timeout -lt 10) { $p.Timeout = 10 }
    if ($p.Timeout -gt $Policy.TimeoutSecMax) { $p.Timeout = $Policy.TimeoutSecMax }
    $p.Retention = Get-Int $c['RETENTION'] 0
    if ($p.Retention -gt $Policy.RetentionDaysMax) { $p.Retention = $Policy.RetentionDaysMax }
    $p.Codepage = Get-Int $c['CODEPAGE'] 1254

    # Credentials: user from conf, password from secret (USER may be there too)
    $p.User = ([string]$c['USER']).Trim()
    $credName = "$Name.cred"
    if ($c['CREDSRC'] -ceq 'S') {
        $credRev = [string]$c['CREDREV']
        Assert-Revision $credRev
        $credName = "${Name}_$credRev.cred"
    } elseif ($c['CREDSRC'] -cne 'O') { Stop-WithError 'CFG' 'invalid credential source' }
    $credPath = Join-Path (Join-Path $Policy.WorkDir 'secret') $credName
    if (-not (Test-Path $credPath)) { Stop-WithError 'CFG' 'password not set (ZCHE_IMAP_CONFIG > Password)' }
    $credentialCodepage = if ($c['CREDSRC'] -ceq 'S') { $p.Codepage } else { 65001 }
    $cr = Read-KeyValueFile $credPath $credentialCodepage
    if ($cr.ContainsKey('USER') -and ([string]$cr['USER']).Trim() -cne $p.User) {
        Stop-WithError 'CFG' 'credential user differs from the profile user'
    }
    $p.Password = [string]$cr['PASSWORD']
    if (-not $p.User) { Stop-WithError 'CFG' 'user name not set' }
    if (-not $p.Password) { Stop-WithError 'CFG' 'password not set (ZCHE_IMAP_CONFIG > Password)' }
    if (($p.User + $p.Password) -cmatch '[\x00-\x1F]') { Stop-WithError 'CFG' 'credentials contain a control character' }
    $p
}

# --- curl ------------------------------------------------------------------

function Get-BaseUrl {
    $scheme = 'imap'
    if ($Prof.Security -ceq 'IMAPS') { $scheme = 'imaps' }
    '{0}://{1}:{2}/' -f $scheme, $Prof.Host, $Prof.Port
}

# Hierarchical folder names (INBOX/Invoices) are encoded part by part
function Get-MailboxUrl([string]$Mailbox, [string]$Uidv = '') {
    $parts = @($Mailbox -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) })
    $url = (Get-BaseUrl) + ($parts -join '/')
    if ($Uidv) { $url += ";UIDVALIDITY=$Uidv" }
    $url
}

function Get-ErrorCode([int]$Code) {
    switch ($Code) {
        { $_ -in 6, 7, 28 } { return 'CONNECT' }
        { $_ -in 35, 51, 58, 60, 77, 83, 90, 91 } { return 'TLS' }
        67 { return 'AUTH' }
        # 9: SELECT rejected, 21: IMAP command (STATUS, MOVE) rejected;
        # in practice both are caused by a missing folder
        { $_ -in 9, 21 } { return 'MAILBOX' }
        78 { return 'NOMAIL' }
        63 { return 'SIZE' }
    }
    'CURL' + $Code
}

# Runs curl. User and password are not put on the command line; they are
# given to curl on standard input with "--config -" (not visible in the
# process list). On failure, exits with an error line unless -NoExit is set.
function Invoke-Curl([string[]]$CurlArgs, [switch]$NoExit) {
    $all = @('--disable', '--proto', '=imap,imaps', '--config', '-', '--silent', '--show-error', '--max-time', [string]$Prof.Timeout)
    if ($Prof.Security -ceq 'STARTTLS') { $all += '--ssl-reqd' }
    if (-not $Prof.Verify) { $all += '--insecure' }
    if ($OnWindows -and -not $Policy.CheckRevoke) { $all += '--ssl-no-revoke' }
    if ($Policy.CaCert) { $all += @('--cacert', $Policy.CaCert) }
    $all += $CurlArgs

    $cred = ($Prof.User + ':' + $Prof.Password).Replace('\', '\\').Replace('"', '\"')
    $stdin = 'user = "' + $cred + '"'

    # In Stop mode, Windows PowerShell 5.1 treats curl's stderr output
    # as an error; this block uses Continue.
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = @($stdin | & $Policy.CurlPath @all 2>&1 | ForEach-Object { "$_" })
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old

    if ($code -ne 0) {
        if ($NoExit) { return , @("ERR $(Get-ErrorCode $code) $($out -join ' ')") }
        Stop-WithError (Get-ErrorCode $code) ($out -join ' ')
    }
    return , $out
}

# The parser is a fixed, read-only installed module.
. (Join-Path $PSScriptRoot 'mime.ps1')

# --- actions ---------------------------------------------------------------

function Assert-Revision([string]$Value) {
    if ($Value -cnotmatch '^[0-9]{10}$' -or $Value -ceq '0000000000') {
        Stop-WithError 'ARG' 'invalid profile revision'
    }
}

function Assert-ManagedPath([string]$Path) {
    $base = [IO.Path]::GetFullPath($Policy.WorkDir).TrimEnd('\', '/')
    $full = [IO.Path]::GetFullPath($Path)
    $comparison = [StringComparison]::Ordinal
    if ($OnWindows) { $comparison = [StringComparison]::OrdinalIgnoreCase }
    if (-not $full.StartsWith($base + [IO.Path]::DirectorySeparatorChar, $comparison)) {
        throw 'CFG: path is outside the managed work directory'
    }
    $current = $full
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            if (([IO.File]::GetAttributes($current) -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'CFG: symbolic links and reparse points are not allowed'
            }
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ($parent -eq $current) { break }
        $current = $parent
    }
    $full
}

function Get-WorkPath([string]$Kind) {
    $dir = Assert-ManagedPath (Join-Path (Join-Path $Policy.WorkDir $Kind) $Prof.Name)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $dir
}

function Get-MailPath([string]$Kind, [string]$Uid, [string]$Uidv) {
    Assert-ManagedPath (Join-Path (Get-WorkPath $Kind) "$Uidv-$Uid")
}

function Get-MailIdentity([string]$Uid, [string]$Uidv) {
    # A test-mode fetch has no SAP log yet. Bind its cache to the actual
    # mailbox as well, so rebinding a profile cannot reuse unrelated content.
    @($Prof.Name, $Uidv, $Uid, $Prof.Host, [string]$Prof.Port,
        $Prof.Security, $Prof.User, $Prof.MAILBOX, $Prof.DONEBOX,
        $Prof.MoveMode)
}

function Assert-MailFolder([string]$Path, [string]$Uid, [string]$Uidv) {
    $null = Assert-ManagedPath $Path
    foreach ($file in 'ready.flg', 'identity.txt') {
        $name = Assert-ManagedPath (Join-Path $Path $file)
        if (-not (Test-Path -LiteralPath $name)) { throw 'CFG: mail folder is incomplete' }
    }
    $identity = [IO.File]::ReadAllLines((Join-Path $Path 'identity.txt'))
    $expected = @(Get-MailIdentity $Uid $Uidv)
    if ($identity.Count -ne $expected.Count) { throw 'CFG: cached mail identity format mismatch' }
    for ($index = 0; $index -lt $expected.Count; $index++) {
        if ($identity[$index] -cne $expected[$index]) { throw 'CFG: cached mail belongs to a different mailbox; use a new profile' }
    }
}

function Get-SearchUids([string]$Uidv, [string]$Query) {
    $found = $false
    $uids = New-Object System.Collections.Generic.List[string]
    foreach ($line in (Invoke-Curl @((Get-MailboxUrl $Prof.MAILBOX $Uidv), '-X', $Query))) {
        $match = [regex]::Match($line, '^\*\s+SEARCH(?:\s+(.*))?$')
        if (-not $match.Success) { continue }
        $found = $true
        foreach ($uid in ($match.Groups[1].Value.Trim() -split '\s+')) {
            if (-not $uid) { continue }
            Assert-Digits $uid 'uid'
            $uids.Add($uid)
        }
    }
    if (-not $found) { Stop-WithError 'MAILBOX' 'server returned no SEARCH result' }
    return , $uids
}

# Only completed archives containing the known generated files are expired.
# Unknown files, nested directories and links are never removed.
function Remove-OldDone {
    if ($Prof.Retention -le 0) { return }
    $doneDir = Get-WorkPath 'done'
    $limit = [DateTime]::UtcNow.AddDays(-$Prof.Retention)
    foreach ($candidate in (Get-ChildItem -LiteralPath $doneDir -Directory)) {
        if ($candidate.Name -cnotmatch '^[0-9]{1,10}-[0-9]{1,10}$') { continue }
        $path = Assert-ManagedPath $candidate.FullName
        $stamp = Assert-ManagedPath (Join-Path $path 'completed.utc')
        if (-not (Test-Path -LiteralPath $stamp)) { continue }
        $completed = [DateTime]::Parse([IO.File]::ReadAllText($stamp), [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
        if ($completed -ge $limit) { continue }
        $files = @(); $safe = $true
        foreach ($entry in (Get-ChildItem -LiteralPath $path -Force)) {
            $null = Assert-ManagedPath $entry.FullName
            if ($entry.PSIsContainer) {
                if ($entry.Name -cne 'att') { $safe = $false; break }
                foreach ($attachment in (Get-ChildItem -LiteralPath $entry.FullName -Force)) {
                    $null = Assert-ManagedPath $attachment.FullName
                    if ($attachment.PSIsContainer) { $safe = $false; break }
                    $files += $attachment.FullName
                }
            } elseif ($entry.Name -cin @('header.txt','body.txt','attach.txt','mail.eml','ready.flg','identity.txt','remote.done','completed.utc')) {
                $files += $entry.FullName
            } else { $safe = $false; break }
        }
        if (-not $safe) { Write-Log 'retention skipped unknown archive contents'; continue }
        foreach ($file in $files) { [IO.File]::Delete($file) }
        $att = Join-Path $path 'att'
        if (Test-Path -LiteralPath $att) { [IO.Directory]::Delete($att) }
        [IO.Directory]::Delete($path)
    }
}

# Explicit local cache retention; never removes a pending committed move.
function Remove-OldInboxCache {
    $days = Get-Int $Policy.InCacheRetentionDays 30
    if ($days -lt 1) { return }
    $limit = [DateTime]::UtcNow.AddDays(-$days)
    foreach ($candidate in (Get-ChildItem -LiteralPath (Get-WorkPath 'in') -Directory)) {
        if ($candidate.Name -cnotmatch '^[0-9]{1,10}-[0-9]{1,10}$') { continue }
        $path = Assert-ManagedPath $candidate.FullName
        # Operators mark only E caches; H requires its payload for move recovery.
        $marker = Assert-ManagedPath (Join-Path $path 'failed.utc')
        if (-not (Test-Path -LiteralPath $marker)) { continue }
        if ((Get-Item -LiteralPath $marker).LastWriteTimeUtc -ge $limit) { continue }
        if (Test-Path -LiteralPath (Join-Path $path 'remote.done')) { continue }
        Remove-FailedCache $path
    }
}

function Remove-FailedCache([string]$Path) {
    $path = Assert-ManagedPath $Path
    $parent = [IO.Path]::GetFullPath((Get-WorkPath 'in')).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if ([IO.Path]::GetDirectoryName($path) -cne $parent) { throw 'CFG: invalid failed cache path' }
    $files = @()
    foreach ($entry in (Get-ChildItem -LiteralPath $path -Force)) {
        $null = Assert-ManagedPath $entry.FullName
        if ($entry.PSIsContainer) {
            if ($entry.Name -cne 'att') { throw 'CFG: unknown cache directory' }
            foreach ($att in (Get-ChildItem -LiteralPath $entry.FullName -Force)) {
                $null = Assert-ManagedPath $att.FullName
                if ($att.PSIsContainer) { throw 'CFG: nested cache directory' }
                $files += $att.FullName
            }
        } elseif ($entry.Name -cin @('header.txt','body.txt','attach.txt','mail.eml','ready.flg','identity.txt','failed.utc')) {
            $files += $entry.FullName
        } else { throw 'CFG: unknown cache file' }
    }
    foreach ($file in $files) { [IO.File]::Delete($file) }
    $attDir = Join-Path $path 'att'
    if (Test-Path -LiteralPath $attDir) { [IO.Directory]::Delete($attDir) }
    [IO.Directory]::Delete($path)
}

function Invoke-List {
    $uidv = $null
    foreach ($l in (Invoke-Curl @((Get-BaseUrl), '-X', "STATUS $($Prof.MAILBOX) (UIDVALIDITY)"))) {
        $m = [regex]::Match($l, 'UIDVALIDITY\s+(\d+)')
        if ($m.Success) { $uidv = $m.Groups[1].Value }
    }
    if (-not $uidv) { Stop-WithError 'MAILBOX' "cannot read folder: $($Prof.MAILBOX)" }

    Assert-Digits $uidv 'uidvalidity'
    $uids = Get-SearchUids $uidv 'UID SEARCH ALL'
    Write-Out "UIDVALIDITY $uidv"
    foreach ($u in $uids) { Write-Out "UID $u" }
    Write-Log ('{0} mails' -f $uids.Count)
    Stop-Ok
}

function Remove-FetchStage([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $path = Assert-ManagedPath $Path
    $expectedParent = [IO.Path]::GetFullPath((Join-Path $Policy.WorkDir 'tmp'))
    $comparison = [StringComparison]::Ordinal
    if ($OnWindows) { $comparison = [StringComparison]::OrdinalIgnoreCase }
    if ([IO.Path]::GetFileName($path) -cnotmatch '^[0-9a-f]{32}\.parsed$' -or
        -not [string]::Equals([IO.Path]::GetDirectoryName($path), $expectedParent, $comparison)) {
        throw 'CFG: refusing cleanup outside the fetch staging directory'
    }
    $files = @(); $att = $null
    # Validate every entry before deleting anything. Do not follow links.
    foreach ($entry in (Get-ChildItem -LiteralPath $path -Force)) {
        $null = Assert-ManagedPath $entry.FullName
        if ($entry.PSIsContainer) {
            if ($entry.Name -cne 'att') { throw 'CFG: unexpected staging directory' }
            $att = $entry.FullName
            foreach ($attachment in (Get-ChildItem -LiteralPath $att -Force)) {
                $null = Assert-ManagedPath $attachment.FullName
                if ($attachment.PSIsContainer) { throw 'CFG: unexpected nested staging directory' }
                $files += $attachment.FullName
            }
        } elseif ($entry.Name -cin @('header.txt','body.txt','attach.txt','mail.eml','ready.flg','identity.txt')) {
            $files += $entry.FullName
        } else { throw 'CFG: unexpected staging file' }
    }
    foreach ($file in $files) { [IO.File]::Delete($file) }
    if ($att) { [IO.Directory]::Delete($att) }
    [IO.Directory]::Delete($path)
}

function Move-ManagedDirectory([string]$Source, [string]$Destination) {
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        $null = Assert-ManagedPath $Source
        $null = Assert-ManagedPath $Destination
        try { [IO.Directory]::Move($Source, $Destination); return }
        catch {
            $cause = $_.Exception
            while ($cause.InnerException) { $cause = $cause.InnerException }
            # Windows scanners may temporarily deny a just-written rename.
            # Never overwrite a target or change permissions to force it.
            if (-not $OnWindows -or $attempt -ge 4 -or
                (Test-Path -LiteralPath $Destination) -or
                ($cause -isnot [IO.IOException] -and $cause -isnot [UnauthorizedAccessException])) { throw }
            Write-Log 'retrying temporary directory rename failure'
            Start-Sleep -Milliseconds (100 * ($attempt + 1))
        }
    }
}

function Invoke-Fetch([string]$Uid, [string]$Uidv) {
    $dest = Get-MailPath 'in' $Uid $Uidv
    $present = Get-SearchUids $Uidv "UID SEARCH UID $Uid"
    if (Test-Path -LiteralPath $dest) {
        Assert-MailFolder $dest $Uid $Uidv
        $failureMarker = Assert-ManagedPath (Join-Path $dest 'failed.utc')
        if (Test-Path -LiteralPath $failureMarker) { [IO.File]::Delete($failureMarker) }
        Stop-Ok
    }
    if ($present -notcontains $Uid) { Stop-WithError 'NOMAIL' 'mail no longer exists' }
    # RFC822.SIZE is immutable for a UID. Reject oversized messages before
    # transfer; older curl releases do not enforce max-filesize for IMAP.
    $declaredSize = $null
    foreach ($line in (Invoke-Curl @((Get-MailboxUrl $Prof.MAILBOX $Uidv), '-X', "UID FETCH $Uid (UID RFC822.SIZE)"))) {
        $sizeMatch = [regex]::Match($line, '\bRFC822\.SIZE\s+([0-9]+)\b', $RxIgnoreCase)
        if ($sizeMatch.Success) { $declaredSize = [long]$sizeMatch.Groups[1].Value }
    }
    if ($null -eq $declaredSize) { Stop-WithError 'NOMAIL' 'server returned no message size' }
    if ($declaredSize -gt $Prof.MaxBytes) { Stop-WithError 'SIZE' 'mail exceeds the size limit' }
    $tmp = Assert-ManagedPath (Join-Path $Policy.WorkDir 'tmp')
    if (-not (Test-Path -LiteralPath $tmp)) { New-Item -ItemType Directory -Path $tmp | Out-Null }
    $token = [Guid]::NewGuid().ToString('N')
    $eml = Assert-ManagedPath (Join-Path $tmp "$token.eml")
    # UID download is checked against the server-declared byte count. BODY[] may
    # set Seen; SAP test mode only lists UIDs and never invokes this action.
    $url = (Get-MailboxUrl $Prof.MAILBOX $Uidv) + "/;UID=$Uid"
    $stage = Assert-ManagedPath (Join-Path $tmp "$token.parsed")
    try {
        Invoke-Curl @($url, '--max-filesize', [string]$Prof.MaxBytes, '-o', $eml) | Out-Null
        if (-not (Test-Path -LiteralPath $eml) -or (Get-Item -LiteralPath $eml).Length -eq 0) { throw 'NOMAIL: mail not found' }
        if ((Get-Item -LiteralPath $eml).Length -gt $Prof.MaxBytes) { throw 'SIZE: mail exceeds the size limit' }
        if ((Get-Item -LiteralPath $eml).Length -ne $declaredSize) { throw ('SIZE: downloaded {0} bytes, expected {1}; UID transfer rejected' -f (Get-Item -LiteralPath $eml).Length, $declaredSize) }
        $MimeLimits.MaxBytes = $Prof.MaxBytes
        Expand-Mail $eml $stage
        [IO.File]::WriteAllLines((Join-Path $stage 'identity.txt'), [string[]](Get-MailIdentity $Uid $Uidv), $Utf8NoBom)
        Move-ManagedDirectory $stage $dest
    } finally {
        # Only this operation's GUID paths; never published in/done data.
        try { if (Test-Path -LiteralPath $eml) { [IO.File]::Delete((Assert-ManagedPath $eml)) } }
        catch { Write-Log ('temporary download cleanup: ' + $_.Exception.Message) }
        try { Remove-FetchStage $stage }
        catch { Write-Log ('temporary parse cleanup: ' + $_.Exception.Message) }
    }
    Stop-Ok
}

function Invoke-Done([string]$Uid, [string]$Uidv) {
    $src = Get-MailPath 'in' $Uid $Uidv
    $dst = Get-MailPath 'done' $Uid $Uidv
    if (Test-Path -LiteralPath $dst) {
        Assert-MailFolder $dst $Uid $Uidv
        if (-not (Test-Path -LiteralPath (Join-Path $dst 'remote.done'))) { Stop-WithError 'CFG' 'archive has no remote completion record' }
        Stop-Ok
    }
    Assert-MailFolder $src $Uid $Uidv
    $marker = Assert-ManagedPath (Join-Path $src 'remote.done')
    if (-not (Test-Path -LiteralPath $marker)) {
        $present = Get-SearchUids $Uidv "UID SEARCH UID $Uid"
        if ($present -contains $Uid) {
            Invoke-Curl @((Get-MailboxUrl $Prof.MAILBOX $Uidv), '-X', "UID MOVE $Uid $($Prof.DONEBOX)") | Out-Null
        }
        # An absent source after an interrupted MOVE only needs local recovery.
        [IO.File]::WriteAllText($marker, 'OK', $Utf8NoBom)
    }
    [IO.File]::WriteAllText((Join-Path $src 'completed.utc'), [DateTime]::UtcNow.ToString('o'), $Utf8NoBom)
    Move-ManagedDirectory $src $dst
    try { Remove-OldDone; Remove-OldInboxCache } catch { Write-Log ('retention: ' + $_.Exception.Message) }
    Stop-Ok
}

# Connection test: one line per step; stops at the first error.
function Invoke-Test {
    Write-Out "VERSION $Version"
    Write-Out "STEP PROFILE OK $($Prof.Host):$($Prof.Port) $($Prof.Security) user $($Prof.User)"

    try { $ips = [System.Net.Dns]::GetHostAddresses($Prof.Host) }
    catch { Stop-WithError 'CONNECT' "DNS: cannot resolve $($Prof.Host)" }
    Write-Out "STEP DNS OK $($ips[0])"

    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $tcp.BeginConnect($Prof.Host, $Prof.Port, $null, $null)
        if (-not $ar.AsyncWaitHandle.WaitOne(10000) -or -not $tcp.Connected) {
            Stop-WithError 'CONNECT' "port $($Prof.Port) unreachable (firewall?)"
        }
    } catch { Stop-WithError 'CONNECT' "port $($Prof.Port) unreachable: $($_.Exception.Message)" }
    finally { $tcp.Close() }
    Write-Out "STEP PORT OK $($Prof.Port)"

    $cap = (Invoke-Curl @((Get-BaseUrl), '-X', 'CAPABILITY')) -join ' '
    if ($cap -cnotmatch '\bMOVE\b') { Stop-WithError 'CFG' 'mail server does not support UID MOVE' }
    $count = $null
    foreach ($l in (Invoke-Curl @((Get-BaseUrl), '-X', "STATUS $($Prof.MAILBOX) (MESSAGES)"))) {
        $m = [regex]::Match($l, 'MESSAGES\s+(\d+)')
        if ($m.Success) { $count = $m.Groups[1].Value }
    }
    if ($null -eq $count) { Stop-WithError 'MAILBOX' "cannot read folder: $($Prof.MAILBOX)" }
    Write-Out "STEP LOGIN OK"
    $word = if ($count -eq 1) { 'mail' } else { 'mails' }
    Write-Out "STEP INBOX OK $($Prof.MAILBOX): $count $word"

    $r = Invoke-Curl @((Get-BaseUrl), '-X', "STATUS $($Prof.DONEBOX) (MESSAGES)") -NoExit
    if (($r -join ' ') -cmatch '^ERR ') {
        Stop-WithError 'MAILBOX' "processed folder missing: $($Prof.DONEBOX)"
    }
    Write-Out "STEP PROCESSED OK $($Prof.DONEBOX)"
    Stop-Ok
}

# Installation test: no profile needed.
function Invoke-SelfTest {
    Write-Out "VERSION $Version"
    Write-Out "ROOT $($Policy.WorkDir)"
    Write-Out "STEP POLICY OK allowed: $($Policy.AllowedHosts -join ',')"
    if (-not (Test-Path $Policy.CurlPath)) { Stop-WithError 'CFG' "curl not found: $($Policy.CurlPath)" }
    $v = @(& $Policy.CurlPath --version 2>&1 | ForEach-Object { "$_" })
    if (($v -join ' ') -cnotmatch '\bimaps\b') { Stop-WithError 'CFG' 'curl does not support IMAPS' }
    Write-Out "STEP CURL OK $(($v[0] -split ' ')[0..1] -join ' ')"
    foreach ($d in 'conf', 'secret', 'in', 'done', 'tmp', 'log') {
        $path = Assert-ManagedPath (Join-Path $Policy.WorkDir $d)
        if (-not (Test-Path $path)) { Stop-WithError 'CFG' "folder missing: $path (setup-server)" }
        $probe = Assert-ManagedPath (Join-Path $path ('.write-test-' + [Guid]::NewGuid().ToString('N')))
        try {
            # CreateNew cannot overwrite or follow a pre-existing file entry.
            $stream = New-Object IO.FileStream -ArgumentList $probe, ([IO.FileMode]::CreateNew), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
            try { $stream.WriteByte(120) } finally { $stream.Dispose() }
            [IO.File]::Delete($probe)
        }
        catch { Stop-WithError 'CFG' "cannot write to folder: $path" }
    }
    Write-Out 'STEP FOLDERS OK'
    Stop-Ok
}

# --- entry point -----------------------------------------------------------

try {
    foreach ($value in $RequestArgs) {
        if ([string]$value -cmatch '^-' -or [string]$value -cmatch '[\x00-\x20]') {
            Stop-WithError 'ARG' 'only positional protocol arguments are accepted'
        }
    }
    switch -CaseSensitive ($Action) {
        'list' {
            if ($RequestArgs.Count -ne 3 -and $RequestArgs.Count -ne 4) { Stop-WithError 'ARG' 'usage: list KEY REVISION [PURGE]' }
            if ($RequestArgs.Count -eq 4 -and $Arg3 -cne 'PURGE') { Stop-WithError 'ARG' 'invalid list mode' }
            Assert-Profile $Arg1; Assert-Revision $Arg2; $revision = $Arg2
        }
        'fetch' {
            if ($RequestArgs.Count -ne 5) { Stop-WithError 'ARG' 'usage: fetch KEY UID UIDVALIDITY REVISION' }
            Assert-Profile $Arg1; Assert-Digits $Arg2 'uid'; Assert-Digits $Arg3 'uidvalidity'; Assert-Revision $Arg4; $revision = $Arg4
        }
        'done' {
            if ($RequestArgs.Count -ne 5) { Stop-WithError 'ARG' 'usage: done KEY UID UIDVALIDITY REVISION' }
            Assert-Profile $Arg1; Assert-Digits $Arg2 'uid'; Assert-Digits $Arg3 'uidvalidity'; Assert-Revision $Arg4; $revision = $Arg4
        }
        'test' {
            if ($RequestArgs.Count -ne 1 -and $RequestArgs.Count -ne 3) { Stop-WithError 'ARG' 'usage: test [KEY REVISION]' }
            if ($Arg1) { Assert-Profile $Arg1; Assert-Revision $Arg2; $revision = $Arg2 }
        }
        default { Stop-WithError 'ARG' 'usage: list | fetch | done | test' }
    }
    Write-Out 'PROTOCOL 2'
    $Policy = Read-Policy
    if ($Action -ceq 'test' -and -not $Arg1) { Invoke-SelfTest }
    $Prof = Read-Profile $Arg1 $revision
    $OutCodepage = $Prof.Codepage
    switch ($Action) {
        'list' {
            if ($Arg3 -ceq 'PURGE') {
                try { Remove-OldDone; Remove-OldInboxCache } catch { Write-Log ('retention: ' + $_.Exception.Message) }
            }
            Invoke-List
        }
        'fetch' { Invoke-Fetch $Arg2 $Arg3 }
        'done' { Invoke-Done $Arg2 $Arg3 }
        'test' { Invoke-Test }
    }
} catch {
    $message = $_.Exception.Message
    if ($message -cmatch '^(PARSE|CFG|SIZE|NOMAIL): (.*)$') { Stop-WithError $Matches[1] $Matches[2] }
    Stop-WithError 'EXC' $message
}
