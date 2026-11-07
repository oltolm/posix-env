# Publishes the already-built output\ channel as a GitHub Release.  The
# .conda packages are immutable release assets; GitHub Pages serves only the
# two repodata.json files, whose base_url points back to those assets.
#
# Create and push TAG first.  A draft release is the default; publishing it
# triggers .github/workflows/channel.yml.  -Publish skips the draft step.
# -PrepareOnly builds and validates the assets without contacting GitHub.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\release.ps1 `
#     -Tag v0.1.0 [-PrepareOnly | -Publish]
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^v[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$')]
  [string]$Tag,
  [switch]$PrepareOnly,
  [switch]$Publish
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$channel = Join-Path $root 'output'
$repository = 'oltolm/posix-env'
$releaseBaseUrl = "https://github.com/$repository/releases/download/$Tag"
$stage = Join-Path $env:TEMP "posix-env-release-$Tag"
$assets = Join-Path $stage 'assets'
$utf8 = New-Object Text.UTF8Encoding $false

function Invoke-Native {
  $exe, $arguments = $args
  & $exe @arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$exe failed with exit code $LASTEXITCODE"
  }
}

function Write-Repodata([string]$Subdir) {
  $source = Join-Path $channel "$Subdir\repodata.json"
  if (-not (Test-Path $source)) { throw "Missing $source" }
  $repodata = Get-Content -LiteralPath $source -Raw | ConvertFrom-Json
  if (-not $repodata.info) {
    $repodata | Add-Member -MemberType NoteProperty -Name info -Value ([pscustomobject]@{})
  }
  $repodata.info | Add-Member -MemberType NoteProperty -Name base_url `
    -Value $releaseBaseUrl -Force
  $destination = Join-Path $assets "repodata-$Subdir.json"
  [IO.File]::WriteAllText($destination,
    ($repodata | ConvertTo-Json -Depth 100 -Compress), $utf8)
}

if (-not (Test-Path (Join-Path $channel 'win-64\repodata.json'))) {
  throw 'No built channel was found in output\. Build the packages first.'
}

# TAG is constrained above, and the resolved staging path must remain directly
# below TEMP before an earlier staging directory is removed.
$tempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$stage = [IO.Path]::GetFullPath($stage)
if ([IO.Path]::GetDirectoryName($stage) -ne $tempRoot) {
  throw "Refusing to use staging directory outside $tempRoot"
}
if (Test-Path $stage) { Remove-Item -Recurse -Force -LiteralPath $stage }
New-Item -ItemType Directory -Path $assets | Out-Null

$names = @{}
foreach ($subdir in 'win-64', 'noarch') {
  foreach ($package in Get-ChildItem (Join-Path $channel $subdir) -File -Filter '*.conda') {
    if ($names.ContainsKey($package.Name)) {
      throw "Package name occurs in more than one subdirectory: $($package.Name)"
    }
    $names[$package.Name] = $true
    Copy-Item -LiteralPath $package.FullName -Destination $assets
  }
  Write-Repodata $subdir
}
if (-not $names.Count) { throw 'The channel contains no .conda packages.' }

Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'install.ps1') -Destination $assets

$checksumLines = foreach ($file in Get-ChildItem $assets -File | Sort-Object Name) {
  $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  "$hash  $($file.Name)"
}
[IO.File]::WriteAllLines((Join-Path $assets 'SHA256SUMS'), $checksumLines, $utf8)

$notes = @"
# posix-env $($Tag.TrimStart('v'))

Install on 64-bit Windows:

``````powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
``````

The package recipes and patches used for this release are in tag ``$Tag``.
The stable channel URL is https://oltolm.github.io/posix-env/channel.
"@
[IO.File]::WriteAllText((Join-Path $stage 'notes.md'), $notes, $utf8)

Write-Host "Prepared $($names.Count) packages in $assets"
Write-Host "Package base URL: $releaseBaseUrl"
if ($PrepareOnly) { return }

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw 'GitHub CLI (gh) is required to publish the release.'
}
if (git -C $root status --porcelain) {
  throw 'The Git working tree is not clean.'
}
$head = Invoke-Native git @('-C', $root, 'rev-parse', 'HEAD')
$tagCommit = Invoke-Native git @('-C', $root, 'rev-parse', "$Tag^{commit}")
if ($head -ne $tagCommit) { throw "$Tag does not point to HEAD." }
Invoke-Native git @('-C', $root, 'ls-remote', '--exit-code', '--tags', 'origin', "refs/tags/$Tag")
Invoke-Native gh @('auth', 'status')

$releaseArguments = @('release', 'create', $Tag, '--repo', $repository,
  '--verify-tag', '--title', "posix-env $($Tag.TrimStart('v'))",
  '--notes-file', (Join-Path $stage 'notes.md'))
if (-not $Publish) { $releaseArguments += '--draft' }
$releaseArguments += @(Get-ChildItem $assets -File | Sort-Object Name | ForEach-Object FullName)
Invoke-Native gh $releaseArguments

if ($Publish) {
  Write-Host 'Published the release; the package-channel workflow will deploy GitHub Pages.'
} else {
  Write-Host 'Created a draft release. Review and publish it to deploy the package channel.'
}
