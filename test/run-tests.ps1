# Parser tests: generates sample mails and uses the test-only parser entry.
# and checks the results. No mail server needed.
# Run (with the same version as on the server):
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File run-tests.ps1
#   pwsh -File run-tests.ps1 -Shell pwsh      (Linux)
# This file contains ASCII only; Turkish letters are written as {XXXX} codes.

param(
    [string]$Shell = $(if ($env:OS -eq 'Windows_NT') { 'powershell.exe' } else { 'pwsh' }),
    [string]$WorkDir
)

$ErrorActionPreference = 'Stop'
$imap = Join-Path $PSScriptRoot (Join-Path '..' (Join-Path 'script' 'imap.ps1'))
$parser = Join-Path $PSScriptRoot 'parse-mail.ps1'
if (-not $WorkDir) {
    $WorkDir = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'work') ('test-parser-' + [Guid]::NewGuid().ToString('N'))
}
$work = [IO.Path]::GetFullPath($WorkDir)
if (Test-Path -LiteralPath $work) { throw 'WorkDir must be a new directory' }
New-Item -ItemType Directory -Path $work | Out-Null
Write-Host "Parser fixtures: $work"

$L1 = [Text.Encoding]::GetEncoding(28591)
$Cp = [Text.Encoding]::GetEncoding(1254)
$Utf8 = New-Object Text.UTF8Encoding -ArgumentList $false

function U([string]$s) {
    $s = $s.Replace('{crlf}', "`r`n")
    [regex]::Replace($s, '\{([0-9a-fA-F]{4})\}', { param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) })
}
function B64([string]$s, [string]$cs) { [Convert]::ToBase64String([Text.Encoding]::GetEncoding($cs).GetBytes($s)) }
# Converts the text to bytes in the given code page and returns them as Latin-1 text
function Raw([string]$s, [string]$cs) { $L1.GetString([Text.Encoding]::GetEncoding($cs).GetBytes($s)) }
function Save-Eml([string]$name, [string[]]$lines) {
    [IO.File]::WriteAllBytes((Join-Path $work $name), $L1.GetBytes(($lines -join "`r`n")))
}

$script:fail = 0
function Check([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { Write-Host "  ok    $name" }
    else { Write-Host "  FAIL  $name  $detail" -ForegroundColor Red; $script:fail++ }
}

function Parse([string]$eml, [int]$Codepage = 1254) {
    $out = Join-Path $work ($eml -replace '\.eml$', '')
    $sourcePath = Join-Path $work $eml
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    $res = & $Shell -NoProfile -ExecutionPolicy Bypass -File $parser -Eml $sourcePath -Out $out -Codepage $Codepage
    $exitCode = $LASTEXITCODE
    Check 'input source preserved' ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -eq $sourceHash) $eml
    Check 'exit status agrees with protocol' (($exitCode -eq 0) -eq (@($res)[-1] -eq 'OK')) (@($res)[-1])
    $outputEncoding = [Text.Encoding]::GetEncoding($Codepage)
    $r = @{
        Last   = @($res)[-1]
        Exit   = $exitCode
        Header = @{}
        Body   = ''
        Att    = @()
        Dir    = $out
    }
    if ($exitCode -eq 0 -and (Test-Path (Join-Path $out 'ready.flg'))) {
        foreach ($l in [IO.File]::ReadAllLines((Join-Path $out 'header.txt'), $outputEncoding)) {
            $i = $l.IndexOf('='); $r.Header[$l.Substring(0, $i)] = $l.Substring($i + 1)
        }
        $r.Body = [IO.File]::ReadAllText((Join-Path $out 'body.txt'), $outputEncoding)
        $r.Att = @([IO.File]::ReadAllLines((Join-Path $out 'attach.txt'), $outputEncoding))
    }
    $r
}

# --- 1. plain text, UTF-8 8bit body, RFC 2047 B headers ---------------------
$subj1 = U 'Sipari{015f} onay{0131}'
$from1 = U 'Ali {00d6}zt{00fc}rk'
$body1 = U 'Merhaba,{crlf}Sipari{015f} numaras{0131} 4500012345 i{00e7}in onay bekliyoruz.{crlf}{0130}yi {00e7}al{0131}{015f}malar.'
Save-Eml 'plain-utf8.eml' @(
    "From: =?utf-8?B?$(B64 $from1 'utf-8')?= <ali@ornek.local>",
    'To: sap@ornek.local',
    "Subject: =?utf-8?B?$(B64 $subj1 'utf-8')?=",
    'Date: Mon, 2 Nov 2026 09:00:00 +0300',
    'Message-ID: <plain-1@ornek.local>',
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=utf-8',
    'Content-Transfer-Encoding: 8bit',
    '',
    (Raw $body1 'utf-8'))

# --- 2. quoted-printable, iso-8859-9, folded header -------------------------
Save-Eml 'qp-8859-9.eml' @(
    'From: muhasebe@ornek.local',
    'Subject: =?iso-8859-9?Q?=DEubat_faturas=FD?=',
    '  =?iso-8859-9?Q?_haz=FDr?=',
    'Content-Type: text/plain; charset="iso-8859-9"',
    'Content-Transfer-Encoding: quoted-printable',
    '',
    'G=FCnayd=FDn,',
    'Tutar 1.250,00 TL =',
    'KDV dahil.',
    'Formul: a=3Db')

# --- 3. complex multipart --------------------------------------------------
$pdf = [byte[]](0x25, 0x50, 0x44, 0x46, 0x2D, 0x00, 0xFF, 0x10, 0x80, 0x0A)
$png = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
$plain3 = U 'D{00fc}z metin g{00f6}vde: {015f}e{011f}faf'
$logoName = U 'logo {015f}irket.png'
Save-Eml 'multipart.eml' @(
    'From: "Tedarikci A.S." <tedarik@ornek.local>',
    'Subject: Fatura',
    'MIME-Version: 1.0',
    'Content-Type: multipart/mixed; boundary="OUTER"',
    '',
    'This is a multi-part message in MIME format.',
    '--OUTER',
    'Content-Type: multipart/alternative; boundary=INNER',
    '',
    '--INNER',
    'Content-Type: text/plain; charset=utf-8',
    'Content-Transfer-Encoding: base64',
    '',
    (B64 $plain3 'utf-8'),
    '--INNER',
    'Content-Type: text/html; charset=utf-8',
    '',
    '<p>HTML body, must not be used</p>',
    '--INNER--',
    '--OUTER',
    'Content-Type: application/pdf',
    'Content-Disposition: attachment;',
    " filename*0*=utf-8''Fatura%20%C3%96rnek%20;",
    ' filename*1*=2026.pdf',
    'Content-Transfer-Encoding: base64',
    '',
    [Convert]::ToBase64String($pdf),
    '--OUTER',
    "Content-Type: image/png; name=`"=?utf-8?B?$(B64 $logoName 'utf-8')?=`"",
    'Content-Disposition: inline',
    'Content-Transfer-Encoding: base64',
    '',
    [Convert]::ToBase64String($png),
    '--OUTER',
    'Content-Type: message/rfc822',
    '',
    'Subject: inner mail',
    '',
    'inner body',
    '--OUTER--',
    'epilogue')

# --- 4. HTML only, windows-1254, base64 ------------------------------------
$html4 = U '<html><head><style>p{}</style></head><body><p>Sat{0131}{015f} &amp; da{011f}{0131}t{0131}m</p><br>ikinci sat{0131}r</body></html>'
Save-Eml 'html-1254.eml' @(
    'Subject: HTML',
    'Content-Type: text/html; charset=windows-1254',
    'Content-Transfer-Encoding: base64',
    '',
    (B64 $html4 'windows-1254'))

# --- 5. unterminated multipart must fail without publishing readiness -----
Save-Eml 'broken.eml' @(
    'Subject: broken',
    'Content-Type: multipart/mixed; boundary=B',
    '',
    '--B',
    '',
    (Raw (U 'Ba{015f}l{0131}ks{0131}z par{00e7}a') 'utf-8'),
    '--B',
    'Content-Type: application/octet-stream; name="../../x|y.bin"',
    'Content-Transfer-Encoding: base64',
    '',
    'QUJD')

# --- 6. long line -----------------------------------------------------------
Save-Eml 'long-line.eml' @(
    'Subject: long',
    'Content-Type: text/plain; charset=us-ascii',
    '',
    ('x' * 600))

# Valid headerless text and attachment file-name normalization.
Save-Eml 'headerless.eml' @(
    'Content-Type: multipart/mixed; boundary=B', '', '--B', '',
    (Raw (U 'Ba{015f}l{0131}ks{0131}z par{00e7}a') 'utf-8'),
    '--B', 'Content-Type: application/octet-stream; name="../../x|y.bin"',
    'Content-Transfer-Encoding: base64', '', 'QUJD', '--B--')
Save-Eml 'invalid-base64.eml' @(
    'Content-Type: application/octet-stream; name="bad.bin"',
    'Content-Transfer-Encoding: base64', '', 'A%%%')
Save-Eml 'invalid-quoted-printable.eml' @(
    'Content-Type: text/plain; charset=us-ascii',
    'Content-Transfer-Encoding: quoted-printable', '', 'invalid=QZ')
Save-Eml 'unsupported-transfer.eml' @(
    'Content-Type: application/octet-stream; name="unknown.bin"',
    'Content-Transfer-Encoding: x-unsupported', '', 'unchanged bytes')
Save-Eml 'encoded-multipart.eml' @(
    'Content-Type: multipart/mixed; boundary=BADCTE',
    'Content-Transfer-Encoding: base64', '', '--BADCTE',
    'Content-Type: text/plain', '', 'body', '--BADCTE--')
$rawBinary = [byte[]](0x00, 0xFF, 0x0A, 0x41, 0x0D, 0x0A, 0x42, 0x0A, 0x43)
Save-Eml 'raw-binary.eml' @(
    'Content-Type: multipart/mixed; boundary=RAWBOUND', '', '--RAWBOUND',
    'Content-Type: application/octet-stream; name="binary.bin"',
    'Content-Transfer-Encoding: binary', '', $L1.GetString($rawBinary), '--RAWBOUND',
    'Content-Type: application/octet-stream; name="eight-bit.bin"',
    'Content-Transfer-Encoding: 8bit', '', $L1.GetString($rawBinary), '--RAWBOUND--')
Save-Eml 'missing-boundary.eml' @('Content-Type: multipart/mixed', '', 'body')
$manyParts = New-Object System.Collections.Generic.List[string]
$manyParts.Add('Content-Type: multipart/mixed; boundary=PARTLIMIT')
$manyParts.Add('')
for ($part = 0; $part -lt 1001; $part++) {
    $manyParts.Add('--PARTLIMIT')
    $manyParts.Add('Content-Type: text/plain')
    $manyParts.Add('')
    $manyParts.Add('bounded test part')
}
$manyParts.Add('--PARTLIMIT--')
Save-Eml 'too-many-parts.eml' $manyParts.ToArray()
$nested = "Content-Type: text/plain`r`n`r`ndeep body"
for ($depth = 0; $depth -lt 22; $depth++) {
    $nested = "Content-Type: multipart/mixed; boundary=B$depth`r`n`r`n--B$depth`r`n$nested`r`n--B$depth--"
}
[IO.File]::WriteAllBytes((Join-Path $work 'too-deep.eml'), $L1.GetBytes($nested))
$unicodeName = U '{00d6}{011f}renci {015f}irket.pdf'
Save-Eml 'unicode-name.eml' @(
    'Content-Type: application/pdf',
    ("Content-Disposition: attachment; filename*=utf-8''" + [Uri]::EscapeDataString($unicodeName)),
    'Content-Transfer-Encoding: base64', '', [Convert]::ToBase64String($pdf))
Save-Eml 'long-header.eml' @(('Subject: ' + ('x' * 300)), '', 'body')
Save-Eml 'long-attachment.eml' @(
    ('Content-Type: application/pdf; name="' + ('x' * 140) + '.pdf"'),
    'Content-Transfer-Encoding: base64', '', [Convert]::ToBase64String($pdf))
$unicodeBody = ('x' * 249) + [char]::ConvertFromUtf32(0x1F600) + (U '{03b1}')
Save-Eml 'unicode-width.eml' @('Content-Type: text/plain; charset=utf-8', '', (Raw $unicodeBody 'utf-8'))
Save-Eml 'html-sections.eml' @(
    'Content-Type: text/html; charset=utf-8', '',
    '<!-- hidden > <script>comment</script> --><head><style>hidden</style></head>',
    '<p>Visible &amp; correct</p><script>hidden</script><style>hidden</style><div>Second<br>line</div>')
Save-Eml 'html-unclosed.eml' @('Content-Type: text/html; charset=utf-8', '', ('<script>' * 10000))
Save-Eml 'html-comments.eml' @('Content-Type: text/html; charset=utf-8', '', ('<!--' * 20000))
Save-Eml 'html-tag-limit.eml' @('Content-Type: text/html; charset=utf-8', '', ('<br>' * 20001))
Save-Eml 'html-size-limit.eml' @('Content-Type: text/html; charset=utf-8', '', ('x' * 2097153))
$longPlain = 'x' * 1048576
Save-Eml 'long-plain.eml' @('Content-Type: text/plain; charset=us-ascii', '', $longPlain)

# --- checks ------------------------------------------------------------------
Write-Host 'plain-utf8'
$r = Parse 'plain-utf8.eml'
Check 'result OK' ($r.Last -eq 'OK') $r.Last
Check 'subject' ($r.Header.SUBJECT -eq $subj1) $r.Header.SUBJECT
Check 'sender' ($r.Header.FROM -eq "$from1 <ali@ornek.local>") $r.Header.FROM
Check 'message-id' ($r.Header.MESSAGEID -eq '<plain-1@ornek.local>') $r.Header.MESSAGEID
Check 'body' ($r.Body.Contains((U 'numaras{0131} 4500012345 i{00e7}in'))) $r.Body
Check 'no attachments' ($r.Header.ATTCOUNT -eq '0') $r.Header.ATTCOUNT
Check 'ready.flg' (Test-Path (Join-Path $r.Dir 'ready.flg')) ''
Check 'mail.eml' (Test-Path (Join-Path $r.Dir 'mail.eml')) ''

Write-Host 'qp-8859-9'
$r = Parse 'qp-8859-9.eml'
Check 'result OK' ($r.Last -eq 'OK') $r.Last
Check 'folded Q subject' ($r.Header.SUBJECT -eq (U '{015e}ubat faturas{0131} haz{0131}r')) $r.Header.SUBJECT
Check 'QP body' ($r.Body.Contains((U 'G{00fc}nayd{0131}n'))) $r.Body
Check 'soft line break' ($r.Body.Contains('1.250,00 TL KDV dahil.')) $r.Body
Check '=3D' ($r.Body.Contains('a=b')) $r.Body

Write-Host 'multipart'
$r = Parse 'multipart.eml'
Check 'result OK' ($r.Last -eq 'OK') $r.Last
Check 'plain text chosen' ($r.Body.Trim() -eq $plain3) $r.Body
Check 'attachment count 3' ($r.Header.ATTCOUNT -eq '3') $r.Header.ATTCOUNT
Check 'RFC 2231 file name' ($r.Att[0] -like '01_Fatura Ornek 2026.pdf|10|application/pdf|attachment|*') $r.Att[0]
Check 'original name' ($r.Att[0].EndsWith((U 'Fatura {00d6}rnek 2026.pdf'))) $r.Att[0]
$pdfOut = [IO.File]::ReadAllBytes((Join-Path (Join-Path $r.Dir 'att') '01_Fatura Ornek 2026.pdf'))
Check 'PDF bytes identical' ((Compare-Object $pdf $pdfOut -SyncWindow 0).Count -eq 0) ''
Check 'inline image' ($r.Att[1] -like '02_logo sirket.png|8|image/png|inline|*') $r.Att[1]
Check 'attached mail' ($r.Att[2] -like '03_attachment3.eml|*|message/rfc822|attachment|*') $r.Att[2]

Write-Host 'html-1254'
$r = Parse 'html-1254.eml'
Check 'result OK' ($r.Last -eq 'OK') $r.Last
Check 'HTML converted to text' ($r.Body.Contains((U 'Sat{0131}{015f} & da{011f}{0131}t{0131}m'))) $r.Body
Check 'no tags' (-not $r.Body.Contains('<')) $r.Body
Check 'style removed' (-not $r.Body.Contains('p{}')) $r.Body

Write-Host 'broken'
$r = Parse 'broken.eml'
Check 'unterminated multipart rejected' ($r.Exit -ne 0 -and $r.Last -like 'ERR PARSE *') $r.Last
Check 'failed parse has no ready flag' (-not (Test-Path (Join-Path $r.Dir 'ready.flg'))) ''

Write-Host 'headerless'
$r = Parse 'headerless.eml'
Check 'result OK' ($r.Exit -eq 0 -and $r.Last -eq 'OK') $r.Last
Check 'part without headers is body' ($r.Body.Contains((U 'Ba{015f}l{0131}ks{0131}z'))) $r.Body
Check 'path cleaned' ($r.Att[0] -like '01_x_y.bin|3|*') $r.Att[0]

Write-Host 'long-line'
$r = Parse 'long-line.eml'
$lines = [IO.File]::ReadAllLines((Join-Path $r.Dir 'body.txt'), $Cp)
Check 'lines 250' ($lines.Count -eq 3 -and $lines[0].Length -eq 250 -and $lines[2].Length -eq 100) ($lines | ForEach-Object Length)

foreach ($invalid in 'invalid-base64.eml', 'invalid-quoted-printable.eml', 'unsupported-transfer.eml', 'encoded-multipart.eml', 'missing-boundary.eml', 'too-deep.eml', 'too-many-parts.eml') {
    Write-Host $invalid
    $r = Parse $invalid
    Check 'malformed MIME rejected' ($r.Exit -ne 0 -and $r.Last -like 'ERR PARSE *') $r.Last
    Check 'no partial success marker' (-not (Test-Path (Join-Path $r.Dir 'ready.flg'))) ''
}
Write-Host 'raw binary multipart'
$r = Parse 'raw-binary.eml'
Check 'raw binary result OK' ($r.Exit -eq 0 -and $r.Last -eq 'OK') $r.Last
Check 'raw binary attachment count' ($r.Header.ATTCOUNT -eq '2') $r.Header.ATTCOUNT
foreach ($name in '01_binary.bin', '02_eight-bit.bin') {
    $bytes = [IO.File]::ReadAllBytes((Join-Path (Join-Path $r.Dir 'att') $name))
    Check "$name preserves every original byte" ([Convert]::ToBase64String($bytes) -ceq [Convert]::ToBase64String($rawBinary)) ''
}
Write-Host 'unicode-name'
$r = Parse 'unicode-name.eml'
Check 'result OK' ($r.Exit -eq 0 -and $r.Last -eq 'OK') $r.Last
Check 'Unicode original name preserved' ($r.Att.Count -eq 1 -and $r.Att[0].EndsWith($unicodeName)) ($r.Att -join ';')
Check 'Unicode file name normalized' ($r.Att[0] -like '01_Ogrenci sirket.pdf|*') ($r.Att -join ';')
foreach ($mail in 'plain-utf8', 'multipart', 'unicode-name') {
    foreach ($file in 'header.txt', 'body.txt', 'attach.txt') {
        $metadata = [IO.File]::ReadAllLines((Join-Path (Join-Path $work $mail) $file), $Cp)
        Check "$mail/$file within SAP line width" (@($metadata | Where-Object { $_.Length -gt 255 }).Count -eq 0) ''
    }
}
Write-Host 'long-header'
$r = Parse 'long-header.eml'
Check 'oversize header fails explicitly' ($r.Exit -ne 0 -and $r.Last -like 'ERR PARSE *') $r.Last
Check 'oversize header has no ready flag' (-not (Test-Path (Join-Path $r.Dir 'ready.flg'))) ''
$r = Parse 'long-attachment.eml'
Check 'oversize metadata fails explicitly' ($r.Exit -ne 0 -and $r.Last -like 'ERR PARSE *') $r.Last
Check 'oversize metadata has no ready flag' (-not (Test-Path (Join-Path $r.Dir 'ready.flg'))) ''
Write-Host 'unicode-width'
$r = Parse 'unicode-width.eml' 65001
Check 'UTF-8 result OK' ($r.Exit -eq 0 -and $r.Last -eq 'OK') $r.Last
Check 'line wrapping preserves Unicode scalar values' (($r.Body -replace '\r?\n', '') -ceq $unicodeBody) $r.Body

Write-Host 'bounded HTML conversion'
$r = Parse 'html-sections.eml'
Check 'HTML sections parse successfully' ($r.Exit -eq 0) $r.Last
Check 'HTML visible text preserved' ($r.Body.Contains('Visible & correct') -and $r.Body.Contains('Second')) $r.Body
Check 'HTML comments and script/style/head removed' (-not $r.Body.Contains('hidden') -and -not $r.Body.Contains('comment')) $r.Body
foreach ($mail in 'html-unclosed.eml', 'html-comments.eml', 'html-tag-limit.eml', 'html-size-limit.eml') {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $r = Parse $mail
    $clock.Stop()
    Check 'hostile HTML rejected as PARSE' ($r.Exit -ne 0 -and $r.Last -like 'ERR PARSE *') $r.Last
    Check 'hostile HTML has no readiness marker' (-not (Test-Path (Join-Path $r.Dir 'ready.flg'))) $mail
    Check 'hostile HTML finishes within test budget' ($clock.Elapsed.TotalSeconds -lt 15) $clock.Elapsed.TotalSeconds
}
$clock = [Diagnostics.Stopwatch]::StartNew()
$r = Parse 'long-plain.eml'
$clock.Stop()
Check 'large unwrapped text preserves content' ($r.Exit -eq 0 -and ($r.Body -replace '\r?\n','') -ceq $longPlain) $r.Last
Check 'large text wrapping finishes within test budget' ($clock.Elapsed.TotalSeconds -lt 15) $clock.Elapsed.TotalSeconds

Write-Host 'fetch failure cleanup'
& $Shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'test-fetch-cleanup.ps1')
Check 'fetch failure cleanup tests' ($LASTEXITCODE -eq 0) 'isolated production-function tests'

Write-Host 'existing output preservation'
$existingOutput = Join-Path $work 'existing-output'
New-Item -ItemType Directory -Path $existingOutput | Out-Null
$sentinel = Join-Path $existingOutput 'sentinel.txt'
[IO.File]::WriteAllText($sentinel, 'preserve this fixture', $Utf8)
$sentinelHash = (Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash
$res = & $Shell -NoProfile -ExecutionPolicy Bypass -File $parser -Eml (Join-Path $work 'plain-utf8.eml') -Out $existingOutput
Check 'existing output rejected' ($LASTEXITCODE -ne 0 -and @($res)[-1] -like 'ERR PARSE *') (@($res)[-1])
Check 'existing file retained unchanged' ((Test-Path -LiteralPath $sentinel) -and (Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash -eq $sentinelHash) ''
Check 'existing directory receives no parser output' (@(Get-ChildItem -LiteralPath $existingOutput).Count -eq 1) ''

Write-Host 'arguments'
$res = & $Shell -NoProfile -ExecutionPolicy Bypass -File $imap fetch 'TST_001_DEMO' 'abc' '1' '0000000001'
Check 'invalid uid rejected' (@($res)[-1] -like 'ERR ARG *') (@($res)[-1])
$res = & $Shell -NoProfile -ExecutionPolicy Bypass -File $imap delete
Check 'unknown action rejected' (@($res)[-1] -like 'ERR ARG *') (@($res)[-1])
foreach ($bad in @(
    @('list', '-Action', 'test'),
    @('list', 'DEMO'),
    @('list', 'TST_001_DEMO', '0000000001', 'INVALID'),
    @('fetch', 'TST_001_DEMO', '1'),
    @('done', 'TST_001_DEMO', '1', '1', '0000000001', 'extra'),
    @('parse')
)) {
    $res = & $Shell -NoProfile -ExecutionPolicy Bypass -File $imap @bad
    Check ('invalid command rejected: ' + ($bad -join ' ')) ($LASTEXITCODE -ne 0 -and @($res)[-1] -like 'ERR ARG *') (@($res)[-1])
}

Write-Host ''
if ($script:fail -eq 0) { Write-Host 'ALL TESTS PASSED' -ForegroundColor Green; exit 0 }
Write-Host "$($script:fail) tests failed" -ForegroundColor Red
exit 1
