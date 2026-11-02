# Builds ZCHE_IMAP_INSTALL.abap: installer\head.abap plus the sources in
# abap\ embedded into the program. Run it again whenever a source
# changes:
#   powershell -NoProfile -ExecutionPolicy Bypass -File installer\build.ps1
# Source lines fit ABAPSOURCE (255); embedded literal chunks fit 72.

param([switch]$Check)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$abap = Join-Path $root 'abap'
$out = Join-Path $root 'ZCHE_IMAP_INSTALL.abap'
$Max = 63   # "  src '" + 63 + "'." = 72

# Splits escaped text into pieces that fit in 72 columns. A piece never
# ends in the middle of a '' pair or with a space (CONCATENATE drops
# trailing spaces).
function Split-Literal([string]$s) {
    $parts = New-Object System.Collections.Generic.List[string]
    while ($s.Length -gt $Max) {
        $cut = $Max
        while ($cut -gt 1) {
            $q = 0
            for ($i = $cut - 1; $i -ge 0 -and $s[$i] -eq "'"; $i--) { $q++ }
            if (($q % 2) -eq 0 -and $s[$cut - 1] -ne ' ') { break }
            $cut--
        }
        $parts.Add($s.Substring(0, $cut))
        $s = $s.Substring($cut)
    }
    $parts.Add($s)
    return , $parts
}

function Get-Form([string]$form, [string]$file) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('*---------------------------------------------------------------')
    $lines.Add("* Source: abap/$file")
    $lines.Add("FORM $form.")
    foreach ($l in [IO.File]::ReadAllLines((Join-Path $abap $file))) {
        if ($l.Length -gt 255) { throw "$file contains a line wider than ABAPSOURCE (255)." }
        $esc = $l.TrimEnd().Replace("'", "''")
        $parts = Split-Literal $esc
        $lines.Add("  src '" + $parts[0] + "'.")
        for ($i = 1; $i -lt $parts.Count; $i++) { $lines.Add("  cnt '" + $parts[$i] + "'.") }
    }
    $lines.Add('ENDFORM.')
    $lines.Add('')
    return , $lines
}

$all = New-Object System.Collections.Generic.List[string]
$all.AddRange([IO.File]::ReadAllLines((Join-Path $PSScriptRoot 'head.abap')))
foreach ($p in @(
        @('fill_common', 'ZCHE_IMAP_COMMON.abap'),
        @('fill_io', 'ZCHE_IMAP_IO.abap'),
        @('fill_handler', 'ZCHE_IMAP_HANDLER_DEMO.abap'),
        @('fill_inbound', 'ZCHE_IMAP_INBOUND.abap'),
        @('fill_config', 'ZCHE_IMAP_CONFIG.abap'),
        @('fill_monitor', 'ZCHE_IMAP_MONITOR.abap'))) {
    $all.AddRange((Get-Form $p[0] $p[1]))
}

# Checks: ABAPSOURCE width and ASCII only
$bad = @()
for ($i = 0; $i -lt $all.Count; $i++) {
    if ($all[$i].Length -gt 255) { $bad += "line $($i + 1): $($all[$i].Length) characters" }
    # -cmatch: case-insensitive matching misreads I/i on a Turkish locale
    if ($all[$i] -cmatch '[^\x09\x20-\x7E]') { $bad += "line $($i + 1): non-ASCII character" }
}
if ($bad.Count -gt 0) { $bad | ForEach-Object { Write-Host $_ }; throw 'ZCHE_IMAP_INSTALL.abap was not built' }

if ($Check) {
    if (-not [IO.File]::Exists($out)) { throw 'Generated installer is missing.' }
    $existing = [IO.File]::ReadAllLines($out)
    if ($existing.Count -ne $all.Count) { throw 'Generated installer is stale; run installer/build.ps1.' }
    for ($i = 0; $i -lt $all.Count; $i++) {
        if ($existing[$i] -cne $all[$i]) { throw "Generated installer is stale at line $($i + 1)." }
    }
} else {
    [IO.File]::WriteAllLines($out, $all.ToArray(), [Text.Encoding]::ASCII)
}
Write-Host ("ZCHE_IMAP_INSTALL.abap: {0} lines" -f $all.Count)

$gitOut = Join-Path $root 'abapgit/zche_imap_install.prog.abap'
if ($Check) {
    if (-not [IO.File]::Exists($gitOut) -or [IO.File]::ReadAllText($gitOut) -cne [IO.File]::ReadAllText($out)) { throw 'abapGit installer copy is stale' }
} else {
    [IO.Directory]::CreateDirectory((Split-Path $gitOut -Parent)) | Out-Null
    [IO.File]::WriteAllText($gitOut, [IO.File]::ReadAllText($out), [Text.Encoding]::ASCII)
}
