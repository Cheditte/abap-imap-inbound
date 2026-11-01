# Test-only parser entry point. This file is never installed in bin/.
param(
    [Parameter(Mandatory = $true)][string]$Eml,
    [Parameter(Mandatory = $true)][string]$Out,
    [int]$Codepage = 1254
)

$ErrorActionPreference = 'Stop'
$Latin1 = [Text.Encoding]::GetEncoding(28591)
$Utf8Strict = New-Object Text.UTF8Encoding -ArgumentList $false, $true
$Utf8NoBom = New-Object Text.UTF8Encoding -ArgumentList $false
$OutCodepage = $Codepage
$MimeLimits = @{ MaxParts = 1000; MaxDepth = 20; MaxBytes = 52428800 }
$RxIgnoreCase = [Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant'
$RxIgnoreCaseDotAll = [Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant, Singleline'

function Get-OutEncoding {
    if ($OutCodepage -eq 65001) { return $Utf8NoBom }
    [Text.Encoding]::GetEncoding($OutCodepage)
}

function Stop-WithError([string]$Code, [string]$Text) {
    [Console]::Out.WriteLine(('ERR {0} {1}' -f $Code, ($Text -replace '[\r\n]+', ' ')))
    exit 1
}

try {
    if (-not (Test-Path -LiteralPath $Eml -PathType Leaf)) { throw 'Input mail does not exist' }
    # A fresh output is required. Parser tests never replace or delete files.
    if (Test-Path -LiteralPath $Out) { throw 'Test output directory already exists' }
    . (Join-Path (Split-Path $PSScriptRoot -Parent) 'script/mime.ps1')
    Expand-Mail $Eml $Out
    [Console]::Out.WriteLine('OK')
    exit 0
} catch {
    Stop-WithError 'PARSE' $_.Exception.Message
}
