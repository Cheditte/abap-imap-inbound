# MIME parser shared by the production transport and local tests.
# No command dispatch or filesystem cleanup is performed on import.
# --- MIME parsing ------------------------------------------------------------
# The mail is read as Latin-1: each byte maps to exactly one character,
# so the bytes can be recovered losslessly after text operations.
if (-not $MimeLimits) { $MimeLimits = @{ MaxParts = 1000; MaxDepth = 20; MaxBytes = 52428800 } }

function Get-OutEncoding {
    if ($OutCodepage -eq 65001) { return $Utf8NoBom }
    [Text.Encoding]::GetEncoding($OutCodepage, [Text.EncoderFallback]::ExceptionFallback, [Text.DecoderFallback]::ExceptionFallback)
}

function Get-Encoding([string]$Charset) {
    if ($Charset) {
        $name = ($Charset.Trim().Trim('"') -split '\*')[0]
        try { return [System.Text.Encoding]::GetEncoding($name, [Text.EncoderFallback]::ExceptionFallback, [Text.DecoderFallback]::ExceptionFallback) }
        catch { throw 'PARSE: unsupported character set' }
    }
    $Latin1
}

# 8-bit text without a charset: UTF-8 first, otherwise Windows-1254.
function Repair-8bit([string]$Text) {
    if ($Text -notmatch '[\x80-\xFF]') { return $Text }
    $bytes = $Latin1.GetBytes($Text)
    try { return $Utf8Strict.GetString($bytes) } catch { }
    [System.Text.Encoding]::GetEncoding(1254).GetString($bytes)
}

function ConvertFrom-Base64Loose([string]$Text) {
    try { return , [Convert]::FromBase64String($Text) }
    catch { throw 'PARSE: invalid base64 data' }
}

function ConvertFrom-QuotedPrintable([string]$Text, [bool]$Header) {
    if ($Text -cmatch '=(?![0-9A-Fa-f]{2}|[ \t]*\r?\n)') { throw 'PARSE: invalid quoted-printable data' }
    if ($Header) { $Text = $Text.Replace('_', ' ') }
    else { $Text = [regex]::Replace($Text, '=[ \t]*\r?\n', '') }
    $s = [regex]::Replace($Text, '=([0-9A-Fa-f]{2})', {
            param($m) [string][char][Convert]::ToByte($m.Groups[1].Value, 16) })
    return , $Latin1.GetBytes($s)
}

# Decodes %XX codes and returns the result as Latin-1 text (raw bytes).
function ConvertFrom-Percent([string]$Text) {
    [regex]::Replace($Text, '%([0-9A-Fa-f]{2})', {
            param($m) [string][char][Convert]::ToByte($m.Groups[1].Value, 16) })
}

# RFC 2047: =?charset?B?...?= and =?charset?Q?...?=
function ConvertFrom-EncodedWords([string]$Text) {
    if (-not $Text) { return '' }
    $Text = [regex]::Replace($Text, '(\?=)\s+(=\?)', '$1$2')
    [regex]::Replace($Text, '=\?([^?]+)\?([BbQq])\?([^?]*)\?=', {
            param($m)
            try {
                if ($m.Groups[2].Value -ieq 'B') { $bytes = ConvertFrom-Base64Loose $m.Groups[3].Value }
                else { $bytes = ConvertFrom-QuotedPrintable $m.Groups[3].Value $true }
                (Get-Encoding $m.Groups[1].Value).GetString($bytes)
            } catch { $m.Value }
        })
}

function Split-HeaderBody([string]$Raw) {
    if ($Raw.StartsWith("`r`n")) { return @{ Head = ''; Body = $Raw.Substring(2) } }
    if ($Raw.StartsWith("`n")) { return @{ Head = ''; Body = $Raw.Substring(1) } }
    $m = [regex]::Match($Raw, '\r?\n\r?\n')
    if (-not $m.Success) { return @{ Head = $Raw; Body = '' } }
    @{ Head = $Raw.Substring(0, $m.Index); Body = $Raw.Substring($m.Index + $m.Length) }
}

# Returns the headers as lowercase name -> first value.
function Read-Headers([string]$Head) {
    $h = @{}
    $unfolded = [regex]::Replace($Head, '\r?\n[ \t]+', ' ')
    foreach ($line in ($unfolded -split '\r?\n')) {
        $i = $line.IndexOf(':')
        if ($i -le 0) { continue }
        $name = $line.Substring(0, $i).Trim().ToLowerInvariant()
        if (-not $h.ContainsKey($name)) { $h[$name] = $line.Substring($i + 1).Trim() }
    }
    $h
}

# Header parameter: boundary, charset, name, filename.
# Also decodes the RFC 2231 forms (filename*= and filename*0*=).
function Get-HeaderParam([string]$Value, [string]$Name) {
    if (-not $Value) { return $null }
    $n = [regex]::Escape($Name)

    $segs = [regex]::Matches($Value, '(?:^|;)\s*' + $n + '\*(\d+)(\*?)=\s*(?:"([^"]*)"|([^;\s]+))', $RxIgnoreCase)
    if ($segs.Count -gt 0) {
        $charset = $null
        $sb = New-Object System.Text.StringBuilder
        foreach ($s in ($segs | Sort-Object { [int]$_.Groups[1].Value })) {
            if ($s.Groups[3].Success) { $v = $s.Groups[3].Value } else { $v = $s.Groups[4].Value }
            if ($s.Groups[2].Value -eq '*') {
                if ($null -eq $charset -and $v -match "^([^']*)'[^']*'(.*)$") {
                    $charset = $Matches[1]
                    $v = $Matches[2]
                }
                $v = ConvertFrom-Percent $v
            }
            [void]$sb.Append($v)
        }
        return (Get-Encoding $charset).GetString($Latin1.GetBytes($sb.ToString()))
    }

    $m = [regex]::Match($Value, '(?:^|;)\s*' + $n + '\*=\s*"?([^'']*)''[^'']*''([^;"]*)', $RxIgnoreCase)
    if ($m.Success) {
        $raw = ConvertFrom-Percent $m.Groups[2].Value
        return (Get-Encoding $m.Groups[1].Value).GetString($Latin1.GetBytes($raw))
    }

    $m = [regex]::Match($Value, '(?:^|;)\s*' + $n + '\s*=\s*(?:"((?:[^"\\]|\\.)*)"|([^;\s]+))', $RxIgnoreCase)
    if ($m.Success) {
        if ($m.Groups[1].Success) { $raw = $m.Groups[1].Value -replace '\\(.)', '$1' }
        else { $raw = $m.Groups[2].Value }
        return (ConvertFrom-EncodedWords (Repair-8bit $raw))
    }
    $null
}

function Split-Multipart([string]$Body, [string]$Boundary) {
    $result = New-Object System.Collections.Generic.List[string]
    $pattern = '(?m)^' + [regex]::Escape('--' + $Boundary) + '(--)?[ \t]*(?:\r?\n|\z)'
    $start = -1; $closed = $false
    foreach ($delimiter in [regex]::Matches($Body, $pattern)) {
        if ($start -ge 0) {
            $end = $delimiter.Index
            # The newline immediately before a delimiter belongs to MIME,
            # not to the preceding part. Preserve every other byte verbatim.
            if ($end -ge 2 -and $Body.Substring($end - 2, 2) -ceq "`r`n") { $end -= 2 }
            elseif ($end -ge 1 -and $Body[$end - 1] -ceq "`n") { $end-- }
            if ($end -lt $start) { $end = $start }
            $result.Add($Body.Substring($start, $end - $start))
        }
        if ($delimiter.Groups[1].Success) { $closed = $true; break }
        $start = $delimiter.Index + $delimiter.Length
    }
    if (-not $closed -or $result.Count -eq 0) { throw 'PARSE: incomplete multipart boundary' }
    return , $result
}

function ConvertFrom-TransferEncoding([string]$Body, [string]$Cte) {
    if ($Cte -eq 'base64') {
        return , (ConvertFrom-Base64Loose $Body)
    }
    if ($Cte -eq 'quoted-printable') { return , (ConvertFrom-QuotedPrintable $Body $false) }
    if ($Cte -and $Cte -cnotin @('7bit', '8bit', 'binary')) { throw 'PARSE: unsupported content transfer encoding' }
    return , $Latin1.GetBytes($Body)
}

function ConvertFrom-Html([string]$Html) {
    # Tokenize once instead of repeatedly scanning for closing script tags.
    # Limits are independent of the network timeout and work on PS 5.1.
    if ($Html.Length -gt 2097152) { throw 'PARSE: HTML body exceeds the character limit (2097152)' }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $matchTimeout = [TimeSpan]::FromMilliseconds(250)
    $text = New-Object Text.StringBuilder
    $offset = 0; $blocked = ''; $tokens = 0
    try {
        $tags = [regex]::Matches($Html, '<!--[\s\S]*?-->|<[^<>]*>', $RxIgnoreCase, $matchTimeout)
        foreach ($tag in $tags) {
            $tokens++
            if ($tokens -gt 20000 -or $clock.ElapsedMilliseconds -gt 2000) {
                throw 'PARSE: HTML conversion work limit exceeded'
            }
            if (-not $blocked) { [void]$text.Append($Html, $offset, $tag.Index - $offset) }
            $offset = $tag.Index + $tag.Length
            if ($tag.Value.StartsWith('<!--')) { continue }
            if ($tag.Length -gt 16384) { throw 'PARSE: HTML tag limit exceeded' }
            $name = [regex]::Match($tag.Value, '^<\s*(/?)\s*([A-Za-z][A-Za-z0-9]*)', $RxIgnoreCase, $matchTimeout)
            if (-not $name.Success) { continue }
            $closing = $name.Groups[1].Value -ceq '/'
            $kind = $name.Groups[2].Value.ToLowerInvariant()
            if ($blocked) {
                if ($closing -and $kind -ceq $blocked) { $blocked = '' }
                continue
            }
            if (-not $closing -and $kind -cin @('script','style','head') -and -not $tag.Value.EndsWith('/>')) {
                $blocked = $kind
            } elseif ($kind -ceq 'br' -or ($closing -and $kind -cin @('p','div','tr','li','h1','h2','h3','h4','h5','h6'))) {
                [void]$text.Append("`n")
            }
        }
        if ($blocked) { throw 'PARSE: unclosed HTML script, style or head section' }
        [void]$text.Append($Html, $offset, $Html.Length - $offset)
        $decoded = [System.Net.WebUtility]::HtmlDecode($text.ToString())
        $result = [regex]::Replace($decoded, '(\r?\n[ \t]*){3,}', "`n`n", $RxIgnoreCase, $matchTimeout)
        if ($clock.ElapsedMilliseconds -gt 2000) { throw 'PARSE: HTML conversion work limit exceeded' }
        return $result
    } catch [Text.RegularExpressions.RegexMatchTimeoutException] {
        throw 'PARSE: HTML conversion time limit exceeded'
    } finally { $clock.Stop() }
}

# File names are ASCII only, so that an old non-Unicode SAP system can
# open the file on Windows. Turkish letters are mapped to their equivalents.
$TurkishAscii = @{
    0x00E7 = 'c'; 0x00C7 = 'C'; 0x011F = 'g'; 0x011E = 'G'; 0x0131 = 'i'; 0x0130 = 'I'
    0x00F6 = 'o'; 0x00D6 = 'O'; 0x015F = 's'; 0x015E = 'S'; 0x00FC = 'u'; 0x00DC = 'U'
}

function ConvertTo-AsciiName([string]$Text) {
    $t = $Text
    foreach ($code in $TurkishAscii.Keys) { $t = $t.Replace([string][char]$code, $TurkishAscii[$code]) }
    # Other accented letters: Normalize may be unsupported on Linux without ICU
    try { $t = $t.Normalize([System.Text.NormalizationForm]::FormD) } catch { }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $t.ToCharArray()) {
        $cat = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
        if ($cat -eq [System.Globalization.UnicodeCategory]::NonSpacingMark) { continue }
        if ([int]$ch -ge 32 -and [int]$ch -le 126) { [void]$sb.Append($ch) } else { [void]$sb.Append('_') }
    }
    $sb.ToString()
}

function Get-SafeFileName([string]$Name, [int]$Index) {
    if ($Name) { $Name = ($Name -split '[\\/]')[-1] }
    if ($Name) {
        $Name = ConvertTo-AsciiName $Name
        # Characters invalid on Windows; the same rule applies on Linux
        # ('|' is also the attach.txt separator)
        $Name = [regex]::Replace($Name, '[<>:"/\\|?*\x00-\x1F]', '_')
        $Name = $Name.Trim(' ', '.')
    }
    if (-not $Name) { $Name = "attachment$Index.bin" }
    if ($Name.Length -gt 120) {
        $ext = [System.IO.Path]::GetExtension($Name)
        if ($ext.Length -gt 10) { $ext = '' }
        $Name = $Name.Substring(0, 120 - $ext.Length) + $ext
    }
    '{0:D2}_{1}' -f $Index, $Name
}

function Save-Attachment([hashtable]$Ctx, [string]$Name, [string]$Mime, [string]$Disp, [byte[]]$Bytes) {
    if (-not (Test-Path $Ctx.AttDir)) { New-Item -ItemType Directory -Path $Ctx.AttDir | Out-Null }
    $i = $Ctx.Att.Count + 1
    if ($Name) { $Name = ConvertFrom-EncodedWords $Name }
    if (-not $Name -and $Mime -eq 'message/rfc822') { $Name = "attachment$i.eml" }
    $safe = Get-SafeFileName $Name $i
    [System.IO.File]::WriteAllBytes((Join-Path $Ctx.AttDir $safe), $Bytes)
    $kind = 'attachment'
    if ($Disp.Trim().ToLowerInvariant().StartsWith('inline')) { $kind = 'inline' }
    $orig = ''
    if ($Name) { $orig = ($Name -replace '[\x00-\x1F|]', ' ') }
    $Ctx.Att.Add(@{ Name = $safe; Size = $Bytes.Length; Mime = $Mime; Disp = $kind; Orig = $orig })
}

function Read-Part([string]$Raw, [hashtable]$Ctx, [int]$Depth) {
    if ($Depth -gt $MimeLimits.MaxDepth) { throw 'PARSE: MIME nesting limit exceeded' }
    $Ctx.PartCount++
    if ($Ctx.PartCount -gt $MimeLimits.MaxParts) { throw 'PARSE: MIME part limit exceeded' }
    $p = Split-HeaderBody $Raw
    $h = Read-Headers $p.Head
    $ct = [string]$h['content-type']
    if (-not $ct) { $ct = 'text/plain' }
    $mime = ($ct -split ';')[0].Trim().ToLowerInvariant()
    if ($mime -cnotmatch '^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$') { throw 'PARSE: invalid MIME type' }
    $cte = ([string]$h['content-transfer-encoding']).Trim().ToLowerInvariant()
    $cd = [string]$h['content-disposition']

    if ($mime.StartsWith('multipart/')) {
        if ($cte -and $cte -cnotin @('7bit', '8bit', 'binary')) { throw 'PARSE: encoded multipart containers are unsupported' }
        $b = Get-HeaderParam $ct 'boundary'
        if (-not $b -or $b.Length -gt 70) { throw 'PARSE: missing or invalid multipart boundary' }
        foreach ($part in (Split-Multipart $p.Body $b)) { Read-Part $part $Ctx ($Depth + 1) }
        return
    }

    $bytes = ConvertFrom-TransferEncoding $p.Body $cte
    $name = Get-HeaderParam $cd 'filename'
    if (-not $name) { $name = Get-HeaderParam $ct 'name' }
    $isAttachment = $cd.Trim().ToLowerInvariant().StartsWith('attachment') -or [bool]$name
    $isText = ($mime -eq 'text/plain' -or $mime -eq 'text/html')

    if ($isText -and -not $isAttachment) {
        $charset = Get-HeaderParam $ct 'charset'
        if ($charset) { $text = (Get-Encoding $charset).GetString($bytes) }
        else { $text = Repair-8bit ($Latin1.GetString($bytes)) }
        if ($mime -eq 'text/html') {
            if ($null -eq $Ctx.Html) { $Ctx.Html = $text }
        } elseif ($null -eq $Ctx.Plain) {
            $Ctx.Plain = $text
        }
        return
    }
    Save-Attachment $Ctx $name $mime $cd $bytes
}

function Get-HeaderText([hashtable]$Headers, [string]$Name) {
    $v = [string]$Headers[$Name]
    if (-not $v) { return '' }
    $v = ConvertFrom-EncodedWords (Repair-8bit $v)
    $v = ($v -replace '[\x00-\x1F]+', ' ').Trim()
    $v
}

function Split-Long([string]$Text, [int]$Width) {
    $out = New-Object System.Collections.Generic.List[string]
    $Text = $Text.Replace("`t", ' ')
    foreach ($l in ($Text -split '\r?\n|\r')) {
        $l = ($l -replace '[\x00-\x1F]', ' ').TrimEnd()
        $offset = 0
        while ($l.Length - $offset -gt $Width) {
            $cut = $Width
            if ([char]::IsHighSurrogate($l[$offset + $cut - 1])) { $cut-- }
            $out.Add($l.Substring($offset, $cut))
            $offset += $cut
        }
        $out.Add($l.Substring($offset))
    }
    while ($out.Count -gt 0 -and $out[$out.Count - 1] -eq '') { $out.RemoveAt($out.Count - 1) }
    return , $out.ToArray()
}

function Write-TextFile([string]$Path, [string[]]$Lines) {
    if ($null -eq $Lines) { $Lines = @() }
    foreach ($line in $Lines) {
        if ($line.Length -gt 255 -or $line -cmatch '[\r\n]') { throw 'PARSE: metadata exceeds the SAP line format' }
    }
    [System.IO.File]::WriteAllLines($Path, $Lines, (Get-OutEncoding))
}

function Expand-Mail([string]$EmlPath, [string]$OutDir) {
    if (Test-Path -LiteralPath $OutDir) { throw 'PARSE: output directory already exists' }
    if ((Get-Item -LiteralPath $EmlPath).Length -gt $MimeLimits.MaxBytes) { throw 'SIZE: mail exceeds the parsing limit' }
    New-Item -ItemType Directory -Path $OutDir | Out-Null

    $raw = $Latin1.GetString([System.IO.File]::ReadAllBytes($EmlPath))
    $ctx = @{
        Plain  = $null
        PartCount = 0
        Html   = $null
        Att    = New-Object System.Collections.Generic.List[object]
        AttDir = (Join-Path $OutDir 'att')
    }
    $h = Read-Headers (Split-HeaderBody $raw).Head
    Read-Part $raw $ctx 0

    $body = $ctx.Plain
    if ($null -eq $body -and $null -ne $ctx.Html) { $body = ConvertFrom-Html $ctx.Html }
    if ($null -eq $body) { $body = '' }

    $head = @(
        ('FROM=' + (Get-HeaderText $h 'from')),
        ('TO=' + (Get-HeaderText $h 'to')),
        ('CC=' + (Get-HeaderText $h 'cc')),
        ('SUBJECT=' + (Get-HeaderText $h 'subject')),
        ('DATE=' + (Get-HeaderText $h 'date')),
        ('MESSAGEID=' + (Get-HeaderText $h 'message-id')),
        ('ATTCOUNT=' + $ctx.Att.Count)
    )
    $att = @()
    foreach ($a in $ctx.Att) { $att += ('{0}|{1}|{2}|{3}|{4}' -f $a.Name, $a.Size, $a.Mime, $a.Disp, $a.Orig) }

    Write-TextFile (Join-Path $OutDir 'header.txt') $head
    Write-TextFile (Join-Path $OutDir 'body.txt') (Split-Long $body 250)
    Write-TextFile (Join-Path $OutDir 'attach.txt') $att
    Copy-Item -Path $EmlPath -Destination (Join-Path $OutDir 'mail.eml')
    Write-TextFile (Join-Path $OutDir 'ready.flg') @('OK')
}

