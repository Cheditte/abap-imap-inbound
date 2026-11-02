# Offline source/build checks plus pinned abaplint grammar parsing.
# abaplint v700 uses limited stand-ins; SAP runtime is not exercised.
param([switch]$SkipAbaplint)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path (Join-Path $repo 'work') ('check-source-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
Write-Host "Source-check workspace: $scratch"
$failures = New-Object System.Collections.Generic.List[string]

if ($env:OS -eq 'Windows_NT') {
    # Compile only the native declarations, never execute elevated setup.
    $setupAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'server/setup-server.ps1'), [ref]$null, [ref]$null)
    $native = $setupAst.Find({ param($node)
        $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Add-Type'
    }, $true)
    if (-not $native) { $failures.Add('Windows native setup declarations not found') }
    else {
        $code = @($native.CommandElements | Where-Object {
            $_ -is [Management.Automation.Language.StringConstantExpressionAst] -and $_.Value.StartsWith('using System;')
        })
        if ($code.Count -ne 1) { $failures.Add('Windows native setup declarations are not a constant string') }
        else {
            $checkName = 'SapImapNativeCheck' + [Guid]::NewGuid().ToString('N')
            Add-Type -TypeDefinition ($code[0].Value.Replace('SapImapSetupNative', $checkName))
        }
    }
}

foreach ($directory in 'script', 'server', 'installer', 'test') {
    foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $repo $directory) -Filter *.ps1 -Recurse)) {
        $parseErrors = $null
        $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$parseErrors)
        foreach ($parseError in $parseErrors) { $failures.Add($file.Name + ': ' + $parseError.Message) }
    }
}
foreach ($directory in 'server') {
    foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $repo $directory) -Filter *.sh -Recurse)) {
        if ([IO.File]::ReadAllBytes($file.FullName) -contains 13) {
            $failures.Add($file.Name + ': shell sources must use LF line endings')
        }
    }
}
$abapFiles = @(Get-ChildItem -LiteralPath (Join-Path $repo 'abap') -Filter *.abap)
$abapFiles += Get-Item -LiteralPath (Join-Path $repo 'installer/head.abap')
$abapFiles += Get-Item -LiteralPath (Join-Path $repo 'ZCHE_IMAP_INSTALL.abap')
foreach ($file in $abapFiles) {
    $lines = [IO.File]::ReadAllLines($file.FullName)
    for ($lineNumber = 0; $lineNumber -lt $lines.Length; $lineNumber++) {
        if ($lines[$lineNumber].Length -gt 255) { $failures.Add($file.Name + ':' + ($lineNumber + 1) + ': over 255 columns') }
        if ($lines[$lineNumber] -cmatch '[^\x09\x20-\x7E]') { $failures.Add($file.Name + ':' + ($lineNumber + 1) + ': non-ASCII source') }
    }
}
$releaseVersion = (Get-Content -LiteralPath (Join-Path $repo 'package.json') -Raw | ConvertFrom-Json).version
foreach ($path in 'abap/ZCHE_IMAP_COMMON.abap', 'installer/head.abap') {
    $text = [IO.File]::ReadAllText((Join-Path $repo $path))
    $match = [regex]::Match($text, "gc_version[^\r\n]*VALUE\s+'([^']+)'")
    if (-not $match.Success -or $match.Groups[1].Value -cne $releaseVersion) {
        $failures.Add($path + ': release version differs from package.json')
    }
}
$transportText = [IO.File]::ReadAllText((Join-Path $repo 'script/imap.ps1'))
$transportVersion = [regex]::Match($transportText, '(?m)^\$Version\s*=\s*''([^'']+)''')
if (-not $transportVersion.Success -or $transportVersion.Groups[1].Value -cne $releaseVersion) {
    $failures.Add('script/imap.ps1: release version differs from package.json')
}

# Build in a copy. Validation never rewrites the tracked installer.
$buildRoot = Join-Path $scratch 'build'
New-Item -ItemType Directory -Path (Join-Path $buildRoot 'installer') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'abap') -Destination $buildRoot -Recurse
foreach ($name in 'build.ps1', 'head.abap') {
    Copy-Item -LiteralPath (Join-Path $repo "installer/$name") -Destination (Join-Path $buildRoot 'installer')
}
& (Join-Path $buildRoot 'installer/build.ps1')
if (-not $?) { throw 'Installer build failed' }
$expected = [IO.File]::ReadAllLines((Join-Path $repo 'ZCHE_IMAP_INSTALL.abap')) -join "`n"
$actual = [IO.File]::ReadAllLines((Join-Path $buildRoot 'ZCHE_IMAP_INSTALL.abap')) -join "`n"
if (-not [string]::Equals($expected, $actual, [StringComparison]::Ordinal)) {
    $failures.Add('ZCHE_IMAP_INSTALL.abap is stale; regenerate with installer/build.ps1')
}

if (-not $SkipAbaplint) {
    $cli = Join-Path $repo 'node_modules/@abaplint/cli/abaplint'
    if (-not (Test-Path -LiteralPath $cli)) { throw 'Run npm ci before source checks, or explicitly use -SkipAbaplint' }
    $lintRoot = Join-Path $scratch 'lint'
    $lintSources = Join-Path $lintRoot 'src'
    New-Item -ItemType Directory -Path $lintSources -Force | Out-Null
    foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $repo 'abap') -Filter *.abap)) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $lintSources ($file.BaseName.ToLowerInvariant() + '.prog.abap'))
    }
    Copy-Item -LiteralPath (Join-Path $repo 'ZCHE_IMAP_INSTALL.abap') -Destination (Join-Path $lintSources 'zche_imap_install.prog.abap')
    Copy-Item -LiteralPath (Join-Path $repo 'abaplint.json') -Destination $lintRoot
    Copy-Item -LiteralPath (Join-Path $repo '.abaplint-deps') -Destination (Join-Path $lintRoot 'deps') -Recurse
    Push-Location $lintRoot
    try {
        & node $cli -f standard
        if ($LASTEXITCODE -ne 0) { $failures.Add('ABAP grammar parser reported errors') }
    } finally { Pop-Location }
}
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Host $failure -ForegroundColor Red }
    throw ($failures.Count.ToString() + ' source check(s) failed')
}
Write-Host 'SOURCE CHECKS PASSED (grammar/build only; SAP runtime not exercised)' -ForegroundColor Green
