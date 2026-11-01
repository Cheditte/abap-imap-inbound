# Builds ZIMAP_INSTALL.abap: installer\head.abap plus the sources in
# abap\ embedded into the program. Run it again whenever a source
# changes:
#   powershell -NoProfile -ExecutionPolicy Bypass -File installer\build.ps1
# Every line of the output is at most 72 characters (4.6C editor).

param([switch]$Check)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$abap = Join-Path $root 'abap'
$out = Join-Path $root 'ZIMAP_INSTALL.abap'
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
        @('fill_common', 'ZIMAP_COMMON.abap'),
        @('fill_io_legacy', 'ZIMAP_IO_LEGACY.abap'),
        @('fill_io_unicode', 'ZIMAP_IO_UNICODE.abap'),
        @('fill_handler', 'ZIMAP_HANDLER_DEMO.abap'),
        @('fill_inbound', 'ZIMAP_INBOUND.abap'),
        @('fill_config', 'ZIMAP_CONFIG.abap'),
        @('fill_monitor', 'ZIMAP_MONITOR.abap'))) {
    $all.AddRange((Get-Form $p[0] $p[1]))
}

# Checks: 72 columns and ASCII only
$bad = @()
for ($i = 0; $i -lt $all.Count; $i++) {
    if ($all[$i].Length -gt 72) { $bad += "line $($i + 1): $($all[$i].Length) characters" }
    # -cmatch: case-insensitive matching misreads I/i on a Turkish locale
    if ($all[$i] -cmatch '[^\x09\x20-\x7E]') { $bad += "line $($i + 1): non-ASCII character" }
}
if ($bad.Count -gt 0) { $bad | ForEach-Object { Write-Host $_ }; throw 'ZIMAP_INSTALL.abap was not built' }

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
Write-Host ("ZIMAP_INSTALL.abap: {0} lines" -f $all.Count)
