<#
  setup-server.ps1 - abap-imap-inbound server setup (Windows).
  Run as administrator, from the root folder of the package:

    powershell -ExecutionPolicy Bypass -File server\setup-server.ps1 -AllowedHosts mail.example.com

  What it does:
    - checks that curl supports IMAPS
    - creates the folders <Root>\bin, conf, secret, in, done, tmp, log
    - copies imap.ps1 and mime.ps1; keeps policy.psd1 unless -Force
    - Permissions: bin read-only; secret only for the SAP account and administrators
    - At the end, prints the values to enter in SAP

  If Basis keeps the password (profile has "Password source = O"):
    powershell -File server\setup-server.ps1 -SetPassword A4H_001_INVOICE

  Older Windows Server releases do not include curl.exe: install curl
  and pass its path with -CurlPath C:\tools\curl\bin\curl.exe

  This file intentionally contains ASCII characters only.
#>
param(
    [string]$Root = 'C:\sapimap',
    [string[]]$AllowedHosts,
    [string]$SapAccount,
    [string]$CurlPath = (Join-Path $env:SystemRoot 'System32\curl.exe'),
    [switch]$AllowInsecure,
    [switch]$AllowPlainImap,
    [switch]$Force,
    [string]$SetPassword
)

$ErrorActionPreference = 'Stop'
$pkg = Split-Path $PSScriptRoot -Parent
# With -File, "a.example.com,b.example.com" arrives as one string: split it
$AllowedHosts = @($AllowedHosts | ForEach-Object { $_ -split ',' } |
    ForEach-Object { $_.Trim() } | Where-Object { $_ })

function Step([string]$t) { Write-Host "== $t" -ForegroundColor Cyan }
function Fail([string]$t) { Write-Host "ERROR: $t" -ForegroundColor Red; exit 1 }

function Assert-NoReparse([string]$Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $entry = Get-Item -LiteralPath $current -Force
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                Fail "Reparse points are not allowed in the setup path: $current"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($current.TrimEnd('\'))
        if (-not $parent -or $parent -eq $current) { break }
        $current = $parent
    }
}

function Set-ExactAccess([string]$Path, [Security.AccessControl.FileSystemRights]$SapRights,
    [bool]$IncludeSap = $true) {
    Assert-NoReparse $Path
    $entry = Get-Item -LiteralPath $Path -Force
    if ($entry.PSIsContainer) {
        $acl = New-Object Security.AccessControl.DirectorySecurity
        $inherit = [Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
    } else {
        $handle = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
            [IO.FileShare]'ReadWrite,Delete')
        try {
            $info = New-Object SapImapSetupNative+FileInfo
            if (-not [SapImapSetupNative]::GetFileInformationByHandle($handle.SafeFileHandle, [ref]$info)) {
                throw 'Cannot inspect hard-link count.'
            }
            if ($info.NumberOfLinks -ne 1) { Fail "Hard-linked setup file requires manual review: $Path" }
        } finally { $handle.Dispose() }
        $acl = New-Object Security.AccessControl.FileSecurity
        $inherit = [Security.AccessControl.InheritanceFlags]::None
    }
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner($script:AdminSid)
    foreach ($sid in @($script:AdminSid, $script:SystemSid)) {
        $rule = New-Object Security.AccessControl.FileSystemAccessRule -ArgumentList @(
            $sid, [Security.AccessControl.FileSystemRights]::FullControl, $inherit,
            [Security.AccessControl.PropagationFlags]::None,
            [Security.AccessControl.AccessControlType]::Allow)
        $acl.AddAccessRule($rule)
    }
    if ($IncludeSap) {
        $rule = New-Object Security.AccessControl.FileSystemAccessRule -ArgumentList @(
            $script:SapSid, $SapRights, $inherit,
            [Security.AccessControl.PropagationFlags]::None,
            [Security.AccessControl.AccessControlType]::Allow)
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function Protect-Tree([string]$Path, [Security.AccessControl.FileSystemRights]$SapRights) {
    Set-ExactAccess $Path $SapRights $false
    foreach ($entry in @(Get-ChildItem -LiteralPath $Path -Force)) {
        Assert-NoReparse $entry.FullName
        if ($entry.PSIsContainer) { Protect-Tree $entry.FullName $SapRights }
        else { Set-ExactAccess $entry.FullName $SapRights }
    }
    Set-ExactAccess $Path $SapRights
}

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Fail 'Run as administrator.' }
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class SapImapSetupNative {
    [StructLayout(LayoutKind.Sequential)]
    public struct FileInfo {
        public uint Attributes;
        public System.Runtime.InteropServices.ComTypes.FILETIME CreationTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME AccessTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME WriteTime;
        public uint VolumeSerialNumber, SizeHigh, SizeLow, NumberOfLinks;
        public uint FileIndexHigh, FileIndexLow;
    }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool MoveFileEx(string source, string target, uint flags);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GetFileInformationByHandle(SafeFileHandle file, out FileInfo info);
}
'@

if ($Root -cnotmatch '^[A-Za-z]:[\\/][A-Za-z0-9_ .:\\/-]+$' -or
    $Root -match '(^|[\\/])\.\.([\\/]|$)') { Fail 'Use a normalized local absolute -Root path.' }
$Root = [IO.Path]::GetFullPath($Root).TrimEnd('\')
if ($Root.Length -le 3) { Fail 'The drive root cannot be the work folder.' }
Assert-NoReparse $Root
$script:AdminSid = New-Object Security.Principal.SecurityIdentifier 'S-1-5-32-544'
$script:SystemSid = New-Object Security.Principal.SecurityIdentifier 'S-1-5-18'
$trusted = @($script:AdminSid.Value, $script:SystemSid.Value,
    'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464')
$parent = [IO.Path]::GetDirectoryName($Root)
$unsafeRights = [Security.AccessControl.FileSystemRights]'Delete,DeleteSubdirectoriesAndFiles,ChangePermissions,TakeOwnership'
while ($parent) {
    if (Test-Path -LiteralPath $parent) {
        $acl = Get-Acl -LiteralPath $parent
        $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
        if ($trusted -notcontains $owner) { Fail "Parent must be owned by administrators/SYSTEM: $parent" }
        foreach ($ace in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
            if ($ace.AccessControlType -eq 'Allow' -and
                -not ($ace.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly) -and
                $trusted -notcontains $ace.IdentityReference.Value -and
                ($ace.FileSystemRights -band $unsafeRights)) {
                Fail "Untrusted account can replace a parent directory: $parent"
            }
        }
    }
    $next = [IO.Path]::GetDirectoryName($parent.TrimEnd('\'))
    if (-not $next -or $next -eq $parent) { break }
    $parent = $next
}

# Which account the SAP work processes run as: the account of the SAP<SID>_<NN> service
if (-not $SapAccount) {
    $svc = @(Get-CimInstance Win32_Service | Where-Object { $_.Name -cmatch '^SAP[A-Z0-9]{3}_\d{2}$' })
    if ($svc.Count -gt 1) { Fail 'Multiple SAP services found; pass the target -SapAccount explicitly.' }
    if ($svc.Count -eq 1) {
        $SapAccount = $svc[0].StartName
        Write-Host "SAP service $($svc[0].Name) runs as $SapAccount"
    }
}
if (-not $SapAccount) { Fail 'SAP service account not found; pass -SapAccount DOMAIN\SAPServiceSID.' }
# ".\user" (local account) is not understood by icacls
if ($SapAccount.StartsWith('.\')) { $SapAccount = $env:COMPUTERNAME + $SapAccount.Substring(1) }
$script:SapSid = (New-Object Security.Principal.NTAccount $SapAccount).Translate(
    [Security.Principal.SecurityIdentifier])

# Lock down every existing entry, including explicit ACEs on individual files.
if (Test-Path -LiteralPath $Root) { Set-ExactAccess $Root 'ReadAndExecute' }
foreach ($d in 'bin', 'conf', 'secret', 'in', 'done', 'tmp', 'log') {
    $path = Join-Path $Root $d
    if (Test-Path -LiteralPath $path) {
        if ($d -eq 'bin') { Protect-Tree $path 'ReadAndExecute' }
        else { Protect-Tree $path 'Modify' }
    }
}

# --- write the password only ------------------------------------------------
if ($SetPassword) {
    if ($SetPassword -cnotmatch '^[A-Z0-9]{3}_[0-9]{3}_[A-Z0-9_]{1,20}$') {
        Fail 'Use SID_CLIENT_PROFILE (example A4H_001_INVOICE).'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Root 'secret') -PathType Container)) {
        Fail 'Run server setup first.'
    }
    $user = Read-Host 'Mail user name (empty: the one in ZCHE_IMAP_CONFIG is used)'
    $sec = Read-Host 'Password' -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { $pw = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    $lines = @()
    if ($user) { $lines += "USER=$user" }
    $lines += "PASSWORD=$pw"
    $path = Join-Path $Root "secret\$SetPassword.cred"
    if (-not $pw -or $pw -match '[\r\n]' -or $user -match '[\r\n]') {
        Fail 'Password must be nonempty and single-line.'
    }
    Assert-NoReparse $path
    $stage = Join-Path $Root ('.credential-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    Set-ExactAccess $stage 'ReadAndExecute' $false
    $temp = Join-Path $stage 'credential'
    try {
        [IO.File]::WriteAllLines($temp, $lines, (New-Object Text.UTF8Encoding $false))
        Set-ExactAccess $temp 'Modify'
        Assert-NoReparse $path
        # Rename the file entry; never write through an existing hard link.
        if (-not [SapImapSetupNative]::MoveFileEx($temp, $path, 9)) {
            throw (New-Object ComponentModel.Win32Exception ([Runtime.InteropServices.Marshal]::GetLastWin32Error()))
        }
    } finally {
        Remove-Variable pw -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
        Remove-Item -LiteralPath $stage -Force
    }
    Write-Host "Written: $path" -ForegroundColor Green
    exit 0
}

# --- setup -------------------------------------------------------------------
Step 'curl check'
if (-not (Test-Path $CurlPath)) { Fail "curl not found: $CurlPath (install curl and pass -CurlPath)" }
$v = (& $CurlPath --version) -join ' '
if ($v -cnotmatch '\bimaps\b') { Fail 'This curl does not support IMAPS.' }
if ($v -notmatch '^curl ([0-9]+)\.([0-9]+)\.' -or [version]"$($Matches[1]).$($Matches[2])" -lt [version]'7.66') { Fail "curl 7.66.0 or newer is required: $((($v -split ' ')[0..1]) -join ' ') (install a newer curl and pass -CurlPath)" }
Write-Host ((($v -split ' ')[0..1]) -join ' ')

Step "Folders: $Root"
foreach ($module in 'imap.ps1', 'mime.ps1') {
    if (-not (Test-Path -LiteralPath (Join-Path $pkg "script\$module"))) { Fail "Package module missing: $module" }
}
New-Item -ItemType Directory -Path $Root -Force | Out-Null
Set-ExactAccess $Root 'ReadAndExecute'
foreach ($d in 'bin', 'conf', 'secret', 'in', 'done', 'tmp', 'log') {
    New-Item -ItemType Directory -Path (Join-Path $Root $d) -Force | Out-Null
    if ($d -eq 'bin') { Set-ExactAccess (Join-Path $Root $d) 'ReadAndExecute' }
    else { Set-ExactAccess (Join-Path $Root $d) 'Modify' }
}
foreach ($module in 'imap.ps1', 'mime.ps1') {
    Copy-Item -LiteralPath (Join-Path $pkg "script\$module") -Destination (Join-Path $Root "bin\$module") -Force
    Set-ExactAccess (Join-Path $Root "bin\$module") 'ReadAndExecute'
}

$policy = Join-Path $Root 'bin\policy.psd1'
if ((Test-Path $policy) -and -not $Force) {
    Write-Host 'policy.psd1 already exists, kept (use -Force to replace it).'
} else {
    if (-not $AllowedHosts) { Fail 'Give the allowed mail servers: -AllowedHosts mail.example.com' }
    foreach ($hostName in $AllowedHosts) {
        if ($hostName -cnotmatch '^[A-Za-z0-9._-]+$') { Fail "Invalid allowed host: $hostName" }
    }
    $hosts = ($AllowedHosts | ForEach-Object { "'" + $_.Trim().ToLowerInvariant() + "'" }) -join ', '
    $text = @"
# policy.psd1 - limits set by Basis (generated by setup-server.ps1).
@{
    WorkDir          = '$Root'
    AllowedHosts     = @($hosts)
    AllowInsecure    = `$$([bool]$AllowInsecure)
    AllowPlainImap   = `$$([bool]$AllowPlainImap)
    CheckRevoke      = `$false
    CaCert           = ''
    CurlPath         = '$CurlPath'
    MaxMailBytes     = 52428800
    RetentionDaysMax = 365
    TimeoutSecMax    = 600
}
"@
    [IO.File]::WriteAllText($policy, $text, (New-Object Text.UTF8Encoding $false))
    Write-Host "policy.psd1 written: allowed servers $hosts"
}

Set-ExactAccess $policy 'ReadAndExecute'
Write-Host "Protected ACLs applied (SAP account: $SapAccount)."

Step 'Installation test'
$out = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'bin\imap.ps1') test)
$out | ForEach-Object { Write-Host "  $_" }
if ($out.Count -eq 0 -or $out[-1] -cne 'OK') { Fail 'Installation test failed.' }

Write-Host ''
Write-Host 'Server ready. On the SAP side:' -ForegroundColor Green
Write-Host "  SE38 > ZCHE_IMAP_INSTALL > Server folder: $Root\"
Write-Host '  Then define the mailbox profile with ZCHE_IMAP_CONFIG.'
