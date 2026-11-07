# Checks recipe versions against their upstream release listings.
#
#   powershell -NoProfile -File tools\check-updates.ps1
#   powershell -NoProfile -File tools\check-updates.ps1 zlib make
#   powershell -NoProfile -File tools\check-updates.ps1 -FailOnUpdate
param(
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [string[]] $Recipe,

  [switch] $FailOnUpdate
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Recipes made from this repository, and the one deliberately pinned to an
# unreleased snapshot, have no upstream release version to compare.
$skip = @{
  brush = 'development snapshot'
  expect = 'posix-env implementation'
  libsystre = 'local compatibility library'
  'posix-env' = 'this repository'
  scriptexe = 'this repository'
}

# Non-GNU, non-GitHub release directories.  The named capture must contain
# only the upstream version, so signatures and similarly named files do not
# create duplicate candidates.
$listings = @{
  bzip2 = @('https://sourceware.org/pub/bzip2/', 'bzip2-(?<version>\d+(?:\.\d+)+)\.tar\.gz')
  file = @('https://astron.com/pub/file/', 'file-(?<version>\d+(?:\.\d+)+)\.tar\.gz')
  less = @('https://www.greenwoodsoftware.com/less/download.html', 'less-(?<version>\d+)\.tar\.gz')
  pkgconf = @('https://distfiles.ariadne.space/pkgconf/', 'pkgconf-(?<version>\d+(?:\.\d+)+)\.tar\.xz')
  tcl = @('https://sourceforge.net/projects/tcl/rss?path=/Tcl', 'tcl(?<version>\d+(?:\.\d+)+)-src\.tar\.gz')
}

$webCache = @{}

function Get-WebText([string] $Url, [hashtable] $Headers = @{}) {
  if (!$webCache.ContainsKey($Url)) {
    $requestHeaders = @{ 'User-Agent' = 'posix-env-update-checker' }
    foreach ($key in $Headers.Keys) { $requestHeaders[$key] = $Headers[$key] }
    $webCache[$Url] = (Invoke-WebRequest -Uri $Url -UseBasicParsing -Headers $requestHeaders -TimeoutSec 30).Content
  }
  return $webCache[$Url]
}

function Get-VersionParts([string] $Value) {
  return @($Value.Split('.') | ForEach-Object { [uint64]::Parse($_) })
}

function Compare-UpstreamVersion([string] $Left, [string] $Right) {
  $a = @(Get-VersionParts $Left)
  $b = @(Get-VersionParts $Right)
  $count = [Math]::Max($a.Count, $b.Count)
  for ($i = 0; $i -lt $count; $i++) {
    $av = if ($i -lt $a.Count) { $a[$i] } else { 0 }
    $bv = if ($i -lt $b.Count) { $b[$i] } else { 0 }
    if ($av -lt $bv) { return -1 }
    if ($av -gt $bv) { return 1 }
  }
  return 0
}

function Select-LatestVersion([string[]] $Versions) {
  $latest = $null
  foreach ($version in $Versions) {
    if (!$latest -or (Compare-UpstreamVersion $version $latest) -gt 0) {
      $latest = $version
    }
  }
  return $latest
}

function Get-ListedVersion([string] $Url, [string] $Pattern) {
  $text = Get-WebText $Url
  $versions = @([regex]::Matches($text, $Pattern, 'IgnoreCase') | ForEach-Object {
    $_.Groups['version'].Value
  } | Sort-Object -Unique)
  return Select-LatestVersion $versions
}

function ConvertFrom-GitTag([string] $Tag) {
  # Covers v1.2.3, pcre2-10.49, openssl-3.6.0 and Expat's R_2_7_3.
  $match = [regex]::Match($Tag, '\d+(?:[._]\d+)+')
  if ($match.Success) { return $match.Value.Replace('_', '.') }
  return $null
}

function Get-GitHubVersion([string] $Owner, [string] $Repository) {
  $headers = @{}
  if ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $($env:GITHUB_TOKEN)" }
  $api = "https://api.github.com/repos/$Owner/$Repository"
  try {
    $release = Get-WebText "$api/releases/latest" $headers | ConvertFrom-Json
    return ConvertFrom-GitTag $release.tag_name
  } catch {
    # Some projects create tags but do not use GitHub Releases.
    $tags = Get-WebText "$api/tags?per_page=100" $headers | ConvertFrom-Json
    $versions = @($tags | ForEach-Object { ConvertFrom-GitTag $_.name } | Where-Object { $_ })
    return Select-LatestVersion $versions
  }
}

function Get-ReadlineVersion {
  $root = 'https://ftpmirror.gnu.org/gnu/readline/'
  $base = Get-ListedVersion $root 'readline-(?<version>\d+(?:\.\d+)+)\.tar\.gz'
  if (!$base) { return $null }
  $compact = $base.Replace('.', '')
  $patchPage = "$root/readline-$base-patches/"
  try {
    $text = Get-WebText $patchPage
    $patches = @([regex]::Matches($text, "readline$compact-(?<version>\d{3})(?!\d)") |
      ForEach-Object { $_.Groups['version'].Value })
    if ($patches.Count) {
      $patch = ($patches | Sort-Object | Select-Object -Last 1)
      return "$base.$patch"
    }
  } catch {
    # A newly released base version may not have a patches directory yet.
  }
  return $base
}

function Get-PerlVersion {
  $text = Get-WebText 'https://www.cpan.org/src/5.0/'
  $versions = @([regex]::Matches($text, 'perl-(?<version>\d+\.\d+\.\d+)\.tar\.xz', 'IgnoreCase') |
    ForEach-Object { $_.Groups['version'].Value } |
    Where-Object { ([uint64]$_.Split('.')[1] % 2) -eq 0 } |
    Sort-Object -Unique)
  return Select-LatestVersion $versions
}

$recipeRoot = Join-Path (Split-Path $PSScriptRoot) 'recipes'
$available = @(Get-ChildItem $recipeRoot -Directory | Sort-Object Name)
if ($Recipe) {
  $unknown = @($Recipe | Where-Object { $_ -notin $available.Name })
  if ($unknown.Count) { throw "Unknown recipe: $($unknown -join ', ')" }
  $selected = @($available | Where-Object { $_.Name -in $Recipe })
} else {
  $selected = $available
}

$results = @()
$errors = @()
foreach ($directory in $selected) {
  $name = $directory.Name
  $path = Join-Path $directory.FullName 'recipe.yaml'
  $text = Get-Content $path -Raw

  $contextVersion = [regex]::Match($text, '(?m)^\s{2}version:\s*["'']?(?<v>\d+(?:\.\d+)*)')
  $packageVersion = [regex]::Match($text, '(?m)^package:\s*\r?\n\s{2}name:.+\r?\n\s{2}version:\s*["'']?(?<v>\d+(?:\.\d+)*)')
  $current = if ($contextVersion.Success) { $contextVersion.Groups['v'].Value } elseif ($packageVersion.Success) { $packageVersion.Groups['v'].Value } else { $null }

  if ($skip.ContainsKey($name)) {
    $results += [pscustomobject]@{ Recipe = $name; Current = $current; Latest = '-'; Status = "skipped: $($skip[$name])" }
    continue
  }

  $urlMatch = [regex]::Match($text, '(?m)^\s*(?:-\s*)?url:\s*(?<url>\S+)')
  if (!$current -or !$urlMatch.Success) {
    $results += [pscustomobject]@{ Recipe = $name; Current = $current; Latest = '-'; Status = 'skipped: no upstream source' }
    continue
  }

  try {
    $sourceUrl = $urlMatch.Groups['url'].Value
    if ($name -eq 'readline') {
      $latest = Get-ReadlineVersion
    } elseif ($name -eq 'perl') {
      $latest = Get-PerlVersion
    } elseif ($listings.ContainsKey($name)) {
      $latest = Get-ListedVersion $listings[$name][0] $listings[$name][1]
    } elseif ($sourceUrl -match '^https://github\.com/(?<owner>[^/]+)/(?<repo>[^/]+)/') {
      $latest = Get-GitHubVersion $Matches.owner $Matches.repo
    } elseif ($sourceUrl -match '^https://ftpmirror\.gnu\.org/gnu/(?<project>[^/]+)/') {
      $project = $Matches.project
      $escaped = [regex]::Escape($project)
      $latest = Get-ListedVersion "https://ftpmirror.gnu.org/gnu/$project/" "$escaped-(?<version>\d+(?:\.\d+)+)\.tar\.(?:gz|xz|bz2)"
    } else {
      throw 'no checker for this upstream'
    }

    if (!$latest) { throw 'the upstream listing contained no release versions' }
    $comparison = Compare-UpstreamVersion $current $latest
    $status = if ($comparison -lt 0) { 'UPDATE' } elseif ($comparison -eq 0) { 'current' } else { 'newer than upstream' }
    $results += [pscustomobject]@{ Recipe = $name; Current = $current; Latest = $latest; Status = $status }
  } catch {
    $errors += "$name`: $($_.Exception.Message)"
    $results += [pscustomobject]@{ Recipe = $name; Current = $current; Latest = '?'; Status = 'ERROR' }
  }
}

$results | Format-Table -AutoSize
if ($errors.Count) {
  Write-Error ($errors -join [Environment]::NewLine) -ErrorAction Continue
  exit 2
}
if ($FailOnUpdate -and ($results.Status -contains 'UPDATE')) { exit 1 }
