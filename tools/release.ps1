# Updates the cumulative GitHub Release used as the rolling package channel.
# Package assets are immutable and append-only. Only packages not already in
# the release are uploaded; repodata, checksums and the installer are replaced.
#
# InputRoot may be a normal rattler-build output directory or a directory of
# downloaded CI artifacts. Every usable index must be directly inside a
# win-64 or noarch directory, beside the packages it describes.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\release.ps1 `
#     [-InputRoot output] [-PrepareOnly | -Publish]
[CmdletBinding()]
param(
  [string]$InputRoot,
  [switch]$PrepareOnly,
  [switch]$Publish,
  [switch]$NoDeploy
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
if (-not $InputRoot) { $InputRoot = Join-Path $root 'output' }
$InputRoot = [IO.Path]::GetFullPath($InputRoot)
$repository = 'oltolm/posix-env'
$channelTag = 'channel'
$releaseBaseUrl = "https://github.com/$repository/releases/download/$channelTag"
$stage = Join-Path $env:TEMP 'posix-env-rolling-channel'
$assets = Join-Path $stage 'assets'
$previous = Join-Path $stage 'previous'
$utf8 = New-Object Text.UTF8Encoding $false

if ($PrepareOnly -and $Publish) {
  throw 'Use either -PrepareOnly or -Publish, not both.'
}
if (-not $PrepareOnly -and -not $Publish) {
  throw 'Specify -PrepareOnly to validate or -Publish to update the rolling channel.'
}

function Invoke-Native([string]$Exe, [string[]]$Arguments) {
  $output = & $Exe @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Exe failed with exit code $LASTEXITCODE"
  }
  return $output
}

function New-Repodata([string]$Subdir) {
  return [pscustomobject][ordered]@{
    info = [pscustomobject][ordered]@{ subdir = $Subdir; base_url = $releaseBaseUrl }
    packages = [pscustomobject]@{}
    'packages.conda' = [pscustomobject]@{}
    removed = @()
    repodata_version = 1
  }
}

function Merge-Repodata($Target, $Source, [string]$Description) {
  $subdir = $Source.info.subdir
  if ($subdir -ne $Target.info.subdir) {
    throw "$Description has subdir '$subdir', expected '$($Target.info.subdir)'."
  }
  foreach ($sectionName in 'packages', 'packages.conda') {
    $sourceSection = $Source.PSObject.Properties[$sectionName].Value
    if (-not $sourceSection) { continue }
    $targetSection = $Target.PSObject.Properties[$sectionName].Value
    foreach ($property in $sourceSection.PSObject.Properties) {
      $existing = $targetSection.PSObject.Properties[$property.Name]
      if ($existing) {
        $oldHash = $existing.Value.sha256
        $newHash = $property.Value.sha256
        if ($oldHash -ne $newHash -or $existing.Value.size -ne $property.Value.size) {
          throw "Conflicting repodata for $($property.Name) in $Description. Raise the recipe build number."
        }
      } else {
        $targetSection | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
      }
    }
  }
  $Target.removed = @($Target.removed + $Source.removed | Sort-Object -Unique)
  if ($Source.repodata_version -gt $Target.repodata_version) {
    $Target.repodata_version = $Source.repodata_version
  }
}

if (-not (Test-Path -LiteralPath $InputRoot)) {
  throw "Input directory does not exist: $InputRoot"
}

$tempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$stage = [IO.Path]::GetFullPath($stage)
if ([IO.Path]::GetDirectoryName($stage) -ne $tempRoot) {
  throw "Refusing to use staging directory outside $tempRoot"
}
if (Test-Path $stage) { Remove-Item -Recurse -Force -LiteralPath $stage }
New-Item -ItemType Directory -Path $assets, $previous | Out-Null

$indexes = @{'win-64' = New-Repodata 'win-64'; 'noarch' = New-Repodata 'noarch'}
$incomingIndexes = @(
  Get-ChildItem -LiteralPath $InputRoot -Recurse -File -Filter 'repodata.json' |
    Where-Object { $_.Directory.Name -in @('win-64', 'noarch') }
)
if (-not $incomingIndexes.Count) {
  throw "No win-64 or noarch repodata.json was found below $InputRoot."
}

$releaseExists = $false
$assetByName = @{}
if (Get-Command gh -ErrorAction SilentlyContinue) {
  $savedErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $releaseOutput = & gh release view $channelTag --repo $repository --json assets,isDraft,url 2>&1
    $releaseExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $savedErrorActionPreference
  }
  if ($releaseExitCode -eq 0) {
    $releaseExists = $true
    $release = ($releaseOutput -join "`n") | ConvertFrom-Json
    foreach ($asset in $release.assets) { $assetByName[$asset.name] = $asset }
    Invoke-Native gh @('release', 'download', $channelTag, '--repo', $repository,
      '--pattern', 'repodata-*.json', '--dir', $previous) | Out-Null
    foreach ($subdir in 'win-64', 'noarch') {
      $path = Join-Path $previous "repodata-$subdir.json"
      if (-not (Test-Path $path)) { throw "The rolling release is missing repodata-$subdir.json." }
      $data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
      Merge-Repodata $indexes[$subdir] $data $path
    }
  } elseif ($Publish) {
    $releaseError = ($releaseOutput -join "`n")
    if ($releaseError -notmatch 'release not found') {
      throw "Could not inspect the rolling release: $releaseError"
    }
  }
} elseif ($Publish) {
  throw 'GitHub CLI (gh) is required to publish the channel.'
}

$inputPackages = @{}
foreach ($indexFile in $incomingIndexes) {
  $subdir = $indexFile.Directory.Name
  $data = Get-Content -LiteralPath $indexFile.FullName -Raw | ConvertFrom-Json
  Merge-Repodata $indexes[$subdir] $data $indexFile.FullName
  foreach ($package in Get-ChildItem -LiteralPath $indexFile.Directory.FullName -File -Filter '*.conda') {
    if ($inputPackages.ContainsKey($package.Name) -and
        $inputPackages[$package.Name].FullName -ne $package.FullName) {
      throw "Package appears in more than one input directory: $($package.Name)"
    }
    $inputPackages[$package.Name] = $package
  }
}
if (-not $inputPackages.Count) { throw 'The input contains no .conda packages.' }

$indexedNames = @{}
foreach ($subdir in 'win-64', 'noarch') {
  foreach ($sectionName in 'packages', 'packages.conda') {
    $section = $indexes[$subdir].PSObject.Properties[$sectionName].Value
    foreach ($property in $section.PSObject.Properties) {
      if ($indexedNames.ContainsKey($property.Name)) {
        throw "Package name occurs more than once in channel repodata: $($property.Name)"
      }
      $indexedNames[$property.Name] = $subdir
    }
  }
}

$newPackages = @()
$packageHashes = @{}
foreach ($entry in $inputPackages.GetEnumerator() | Sort-Object Key) {
  $name = $entry.Key
  $file = $entry.Value
  if (-not $indexedNames.ContainsKey($name)) {
    throw "$name is not present in its adjacent repodata.json."
  }
  $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($assetByName.ContainsKey($name)) {
    $remoteHash = $assetByName[$name].digest -replace '^sha256:', ''
    if ($remoteHash -ne $hash) {
      throw "$name already exists with different bytes. Raise the recipe build number."
    }
  } else {
    Copy-Item -LiteralPath $file.FullName -Destination $assets
    $newPackages += Get-Item -LiteralPath (Join-Path $assets $name)
  }
  $packageHashes[$name] = $hash
}

foreach ($name in $indexedNames.Keys) {
  if (-not $packageHashes.ContainsKey($name)) {
    if (-not $assetByName.ContainsKey($name)) {
      throw "Channel repodata names $name, but no package asset is available."
    }
    $packageHashes[$name] = $assetByName[$name].digest -replace '^sha256:', ''
  }
}

foreach ($subdir in 'win-64', 'noarch') {
  $indexes[$subdir].info.base_url = $releaseBaseUrl
  $destination = Join-Path $assets "repodata-$subdir.json"
  [IO.File]::WriteAllText($destination,
    ($indexes[$subdir] | ConvertTo-Json -Depth 100 -Compress), $utf8)
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'install.ps1') -Destination $assets

$checksumLines = @()
foreach ($name in $packageHashes.Keys | Sort-Object) {
  $checksumLines += "$($packageHashes[$name])  $name"
}
foreach ($name in 'install.ps1', 'repodata-noarch.json', 'repodata-win-64.json') {
  $path = Join-Path $assets $name
  $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
  $checksumLines += "$hash  $name"
}
[IO.File]::WriteAllLines((Join-Path $assets 'SHA256SUMS'), $checksumLines, $utf8)

$notes = @"
# posix-env rolling package channel

This release is the append-only asset store for the public posix-env package
channel. Package filenames are immutable. Updates add only new package builds
and replace the channel indexes, checksums and installer.

Install from https://oltolm.github.io/posix-env/channel. Source recipes and
patches are in the repository; every package also contains its rendered recipe.
"@
[IO.File]::WriteAllText((Join-Path $stage 'notes.md'), $notes, $utf8)

Write-Host "Prepared a cumulative index with $($indexedNames.Count) packages."
Write-Host "New package assets: $($newPackages.Count)"
Write-Host "Package base URL: $releaseBaseUrl"
if ($PrepareOnly) { return }

& git -C $root diff --quiet
if ($LASTEXITCODE -ne 0) { throw 'Tracked files have uncommitted changes.' }
& git -C $root diff --cached --quiet
if ($LASTEXITCODE -ne 0) { throw 'The Git index has uncommitted changes.' }
Invoke-Native gh @('auth', 'status') | Out-Null

$metadata = @(
  (Join-Path $assets 'install.ps1'),
  (Join-Path $assets 'repodata-win-64.json'),
  (Join-Path $assets 'repodata-noarch.json'),
  (Join-Path $assets 'SHA256SUMS')
)
if (-not $releaseExists) {
  $allAssets = @($newPackages | ForEach-Object FullName) + $metadata
  Invoke-Native gh (@('release', 'create', $channelTag, '--repo', $repository,
    '--target', 'master', '--title', 'posix-env rolling package channel',
    '--notes-file', (Join-Path $stage 'notes.md'), '--latest=false') + $allAssets) | Out-Null
  Write-Host "Created the rolling release with $($newPackages.Count) packages."
} else {
  if ($newPackages.Count) {
    Invoke-Native gh (@('release', 'upload', $channelTag, '--repo', $repository) +
      @($newPackages | ForEach-Object FullName)) | Out-Null
  }
  Invoke-Native gh (@('release', 'upload', $channelTag, '--repo', $repository,
    '--clobber') + $metadata) | Out-Null
  Invoke-Native gh @('release', 'edit', $channelTag, '--repo', $repository,
    '--notes-file', (Join-Path $stage 'notes.md'), '--latest=false') | Out-Null
  Write-Host "Uploaded $($newPackages.Count) new packages and refreshed channel metadata."
}

if (-not $NoDeploy) {
  Invoke-Native gh @('workflow', 'run', 'channel.yml', '--repo', $repository, '--ref', 'master') | Out-Null
  Write-Host 'Triggered the GitHub Pages channel deployment.'
}
