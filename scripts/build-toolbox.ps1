[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$package = Get-Content -LiteralPath (Join-Path $projectRoot 'package.json') -Raw | ConvertFrom-Json
$version = $package.version
$distPath = Join-Path $projectRoot 'dist'
$unpackedPath = Join-Path $distPath 'win-unpacked'
$stagingPath = Join-Path $distPath 'scapp-staging'
$zipPath = Join-Path $distPath "Tech-Browser-$version-x64.zip"
$scappPath = Join-Path $distPath "Tech-Browser-$version-x64.scapp"
$launcherPath = Join-Path $projectRoot 'toolbox\0-Tech-Browser.cmd'
$builderPath = Join-Path $projectRoot 'node_modules\electron-builder\cli.js'

$distFullPath = [System.IO.Path]::GetFullPath($distPath).TrimEnd('\')
$stagingFullPath = [System.IO.Path]::GetFullPath($stagingPath)
if (-not $stagingFullPath.StartsWith("$distFullPath\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean staging path outside dist: $stagingFullPath"
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
Copy-Item -Path (Join-Path $unpackedPath '*') -Destination $stagingPath -Recurse -Force
Copy-Item -LiteralPath $launcherPath -Destination $stagingPath -Force

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
