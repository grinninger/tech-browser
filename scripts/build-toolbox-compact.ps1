[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$package = Get-Content -LiteralPath (Join-Path $projectRoot 'package.json') -Raw | ConvertFrom-Json
$version = $package.version
$distPath = Join-Path $projectRoot 'dist'
$unpackedPath = Join-Path $distPath 'win-unpacked'
$unpackedTempPath = Join-Path $distPath 'win-unpacked.tmp'
$stagingPath = Join-Path $distPath 'scapp-compact-staging'
$payloadPath = Join-Path $stagingPath 'payload.7z'
$zipPath = Join-Path $distPath "Tech-Browser-$version-x64-compact.zip"
$scappPath = Join-Path $distPath "Tech-Browser-$version-x64-compact.scapp"
$launcherPath = Join-Path $projectRoot 'toolbox\0-Tech-Browser-compact.cmd'
$builderPath = Join-Path $projectRoot 'node_modules\electron-builder\cli.js'
$sevenZipPath = Join-Path $projectRoot 'node_modules\7zip-bin\win\x64\7za.exe'
$sevenZipLicensePath = Join-Path $projectRoot 'node_modules\7zip-bin\LICENSE.txt'

$distFullPath = [System.IO.Path]::GetFullPath($distPath).TrimEnd('\')
$stagingFullPath = [System.IO.Path]::GetFullPath($stagingPath)
$unpackedTempFullPath = [System.IO.Path]::GetFullPath($unpackedTempPath)
if (-not $stagingFullPath.StartsWith("$distFullPath\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean staging path outside dist: $stagingFullPath"
}
if (-not $unpackedTempFullPath.StartsWith("$distFullPath\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean build temp path outside dist: $unpackedTempFullPath"
}
if (Test-Path -LiteralPath $unpackedTempPath) {
    Remove-Item -LiteralPath $unpackedTempPath -Recurse -Force
}

& node $builderPath --win dir --x64
if ($LASTEXITCODE -ne 0) {
    throw "electron-builder failed with exit code $LASTEXITCODE."
}
if (-not (Test-Path -LiteralPath (Join-Path $unpackedPath 'Tech Browser.exe'))) {
    throw 'The unpacked Tech Browser executable was not created.'
}

if (Test-Path -LiteralPath $stagingPath) {
    Remove-Item -LiteralPath $stagingPath -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingPath | Out-Null
Copy-Item -LiteralPath $launcherPath -Destination $stagingPath -Force
Copy-Item -LiteralPath $sevenZipPath -Destination (Join-Path $stagingPath '7za.exe') -Force
Copy-Item -LiteralPath $sevenZipLicensePath -Destination (Join-Path $stagingPath '7zip-license.txt') -Force

Push-Location $unpackedPath
try {
    & $sevenZipPath a -t7z $payloadPath '.\*' -mx=9 -m0=lzma2 -mmt=on -ms=on
    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

foreach ($artifact in @($zipPath, $scappPath)) {
    if (Test-Path -LiteralPath $artifact) {
        Remove-Item -LiteralPath $artifact -Force
    }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $stagingPath,
    $zipPath,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false
)
Move-Item -LiteralPath $zipPath -Destination $scappPath
Remove-Item -LiteralPath $stagingPath -Recurse -Force

$artifact = Get-Item -LiteralPath $scappPath
Write-Output "Created $($artifact.FullName) ($([math]::Round($artifact.Length / 1MB, 1)) MiB)"
