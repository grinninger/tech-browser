[CmdletBinding()]
param(
    [string]$Artifact = 'dist\Tech-Browser-0.1.1-x64.scapp'
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$distPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot 'dist')).TrimEnd('\')
$artifactPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Artifact))
$verifyPath = [System.IO.Path]::GetFullPath((Join-Path $distPath 'verify-scapp'))

if (-not $artifactPath.StartsWith("$distPath\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Artifact is outside dist: $artifactPath"
}
if (-not $verifyPath.StartsWith("$distPath\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Verification directory is outside dist: $verifyPath"
}

if (Test-Path -LiteralPath $verifyPath) {
    Remove-Item -LiteralPath $verifyPath -Recurse -Force
}
New-Item -ItemType Directory -Path $verifyPath | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($artifactPath)
try {
    $entryCount = $zip.Entries.Count
    $firstNames = $zip.Entries | Sort-Object FullName | Select-Object -First 5 -ExpandProperty FullName
}
finally {
    $zip.Dispose()
}

[System.IO.Compression.ZipFile]::ExtractToDirectory($artifactPath, $verifyPath)
$executablePath = Join-Path $verifyPath 'Tech Browser.exe'
$launcherPath = Join-Path $verifyPath '0-Tech-Browser.cmd'
$compactLauncherPath = Join-Path $verifyPath '0-Tech-Browser-compact.cmd'

if ((Test-Path -LiteralPath $executablePath) -and (Test-Path -LiteralPath $launcherPath)) {
    $process = Start-Process -FilePath $executablePath -ArgumentList '--smoke-test' -WorkingDirectory $verifyPath -WindowStyle Hidden -Wait -PassThru
}
elseif ((Test-Path -LiteralPath $compactLauncherPath) -and (Test-Path -LiteralPath (Join-Path $verifyPath 'payload.7z'))) {
    $process = Start-Process -FilePath $compactLauncherPath -ArgumentList '--smoke-test' -WorkingDirectory $verifyPath -WindowStyle Hidden -Wait -PassThru
}
else {
    throw 'Toolbox package does not contain a recognized launcher and browser payload.'
}
$hash = Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256

[pscustomobject]@{
    SmokeExit = $process.ExitCode
    Entries = $entryCount
    FirstAlphabetical = $firstNames -join ', '
    SizeMiB = [math]::Round((Get-Item -LiteralPath $artifactPath).Length / 1MB, 1)
    SHA256 = $hash.Hash
} | Format-List

Remove-Item -LiteralPath $verifyPath -Recurse -Force
exit $process.ExitCode
