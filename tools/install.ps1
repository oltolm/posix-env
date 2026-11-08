# Bootstraps posix-env from a public conda channel.  The channel URL must
# contain the platform subdirectories (win-64 and noarch).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
#
# POSIX_ENV_HOME changes the default installation directory.  -InstallDir
# takes precedence.
[CmdletBinding()]
param(
  [string]$Channel = 'https://oltolm.github.io/posix-env/channel',

  [string]$InstallDir = $(
    if ($env:POSIX_ENV_HOME) { $env:POSIX_ENV_HOME }
    else { Join-Path $env:USERPROFILE 'posix-env' }
  ),

  # Primarily for offline installation and testing.  The file must have the
  # same pinned SHA-256 as the normal download.
  [string]$MicromambaPath,

  # Install the packages, but do not add PATH, Start menu or Windows Terminal
  # entries.  Existing entries are left alone.
  [switch]$NoUserIntegration
)

$ErrorActionPreference = 'Stop'

$micromambaUrl = 'https://github.com/mamba-org/micromamba-releases/releases/download/2.10.0-0/micromamba-win-64.exe'
$micromambaSha256 = 'f8b4284bd4eb1134122eaf93b3ea6c7be567e596de5829e1a6f478e34e41974a'
$defaultPackages = @(
  'posix-env', 'autoconf', 'automake', 'libtool', 'gettext-tools', 'pkgconf',
  'diffutils', 'patch', 'file', 'gzip', 'libarchive', 'xz', 'zstd', 'less'
)

function Invoke-Micromamba([string[]]$Arguments) {
  & $script:micromamba --no-rc @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "micromamba failed with exit code $LASTEXITCODE"
  }
}

if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
  throw 'posix-env can only be installed on Windows.'
}
if (-not [Environment]::Is64BitOperatingSystem) {
  throw 'posix-env requires 64-bit Windows.'
}

$channelUri = $null
if (-not [Uri]::TryCreate($Channel, [UriKind]::Absolute, [ref]$channelUri) -or
    $channelUri.Scheme -notin @('https', 'file')) {
  throw 'Channel must be an absolute HTTPS or file URL.'
}
$Channel = $Channel.TrimEnd('/')

$InstallDir = [Environment]::ExpandEnvironmentVariables($InstallDir)
$InstallDir = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
if ($InstallDir -eq [IO.Path]::GetPathRoot($InstallDir).TrimEnd('\')) {
  throw 'The installation directory cannot be the root of a drive.'
}

# Keep the resume marker beside the prefix: conda refuses to create an
# environment in a nonempty directory, even when the only file is a marker.
$installMarker = "$InstallDir.posix-env-installing"
$existingEnvironment = Test-Path (Join-Path $InstallDir 'conda-meta')
$incompleteInstallation = Test-Path $installMarker
if (Test-Path $InstallDir) {
  $entries = @(Get-ChildItem -Force -LiteralPath $InstallDir)
  if ($existingEnvironment) {
    $posixMetadata = @(Get-ChildItem -LiteralPath (Join-Path $InstallDir 'conda-meta') `
      -Filter 'posix-env-*.json' -ErrorAction SilentlyContinue)
    if (-not $posixMetadata -and -not $incompleteInstallation) {
      throw "$InstallDir is a conda environment, but it is not a posix-env environment."
    }
  } elseif ($entries -and -not $incompleteInstallation) {
    throw "$InstallDir exists and is not empty. Choose another installation directory."
  }
}

if (-not $existingEnvironment) {
  [IO.File]::WriteAllText($installMarker, 'An interrupted posix-env installation may be resumed.',
    (New-Object Text.UTF8Encoding $false))
}

$temporaryRoot = Join-Path $env:TEMP ("posix-env-install-" + [Guid]::NewGuid().ToString('N'))
$script:micromamba = Join-Path $temporaryRoot 'micromamba.exe'
$oldMambaRootPrefix = $env:MAMBA_ROOT_PREFIX
$hadMambaRootPrefix = Test-Path Env:MAMBA_ROOT_PREFIX
$oldCondaPkgsDirs = $env:CONDA_PKGS_DIRS
$hadCondaPkgsDirs = Test-Path Env:CONDA_PKGS_DIRS

try {
  New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
  $env:MAMBA_ROOT_PREFIX = Join-Path $temporaryRoot 'mamba'
  $env:CONDA_PKGS_DIRS = Join-Path $env:MAMBA_ROOT_PREFIX 'pkgs'
  New-Item -ItemType Directory -Path $env:MAMBA_ROOT_PREFIX,
    (Join-Path $env:MAMBA_ROOT_PREFIX 'pkgs'),
    (Join-Path $env:MAMBA_ROOT_PREFIX 'envs') | Out-Null
  if ($MicromambaPath) {
    Write-Host 'Using the supplied micromamba ...'
    Copy-Item -LiteralPath $MicromambaPath -Destination $script:micromamba
  } else {
    Write-Host 'Downloading micromamba ...'
    $oldProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
      Invoke-WebRequest -Uri $micromambaUrl -OutFile $script:micromamba -UseBasicParsing
    } finally {
      $ProgressPreference = $oldProgressPreference
    }
  }

  $actualHash = (Get-FileHash -LiteralPath $script:micromamba -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualHash -ne $micromambaSha256) {
    throw "micromamba has SHA-256 $actualHash; expected $micromambaSha256"
  }

  if ($existingEnvironment) {
    Write-Host "Updating the bootstrap package in $InstallDir ..."
    Invoke-Micromamba @('install', '-y', '--log-level', 'error', '-p', $InstallDir,
      '-c', $Channel, '--override-channels', 'posix-env')
  } else {
    Write-Host "Creating the environment in $InstallDir ..."
    Invoke-Micromamba @('create', '-y', '--log-level', 'error', '-p', $InstallDir,
      '-c', $Channel, '--override-channels', 'posix-env')
  }

  # The installed launcher reads this channel for search, install and update.
  # Replace the tiny environment-specific file atomically.
  $condarc = Join-Path $InstallDir '.condarc'
  $condarcTemporary = "$condarc.tmp-$PID"
  [IO.File]::WriteAllLines($condarcTemporary, @('channels:', "  - $Channel"),
    (New-Object Text.UTF8Encoding $false))
  Move-Item -Force -LiteralPath $condarcTemporary -Destination $condarc

  # Keep the whole package transaction on the downloaded, hash-checked
  # micromamba with its isolated configuration and cache.  Handing this to
  # the installed launcher used a second copied process with different I/O
  # and configuration; a native failure there left no useful diagnostics.
  Write-Host 'Installing the default packages ...'
  Invoke-Micromamba (@('install', '-y', '--log-level', 'error', '-p', $InstallDir,
    '-c', $Channel, '--override-channels') + $defaultPackages)

  if (-not $NoUserIntegration) {
    Write-Host 'Adding the Start menu, Windows Terminal and PATH entries ...'
    $integration = Join-Path $InstallDir 'share\posix-env\posix-env-entries.ps1'
    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $integration
    if ($LASTEXITCODE -ne 0) {
      throw "User integration failed with exit code $LASTEXITCODE"
    }
  }

  $toolchain = if ($env:POSIX_ENV_TOOLCHAIN) {
    $env:POSIX_ENV_TOOLCHAIN
  } else {
    'C:\msys64\ucrt64\bin'
  }
  if (-not (Test-Path (Join-Path $toolchain 'gcc.exe'))) {
    Write-Warning "No gcc.exe was found in $toolchain. Set POSIX_ENV_TOOLCHAIN to a MinGW-w64 UCRT toolchain's bin directory."
  }

  Write-Host ''
  Write-Host 'posix-env is installed.'
  Write-Host "Run: `"$InstallDir\posix-env.cmd`" run"
  Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $installMarker
} finally {
  if ($hadMambaRootPrefix) { $env:MAMBA_ROOT_PREFIX = $oldMambaRootPrefix }
  else { Remove-Item Env:MAMBA_ROOT_PREFIX -ErrorAction SilentlyContinue }
  if ($hadCondaPkgsDirs) { $env:CONDA_PKGS_DIRS = $oldCondaPkgsDirs }
  else { Remove-Item Env:CONDA_PKGS_DIRS -ErrorAction SilentlyContinue }
  if (Test-Path $temporaryRoot) {
    Remove-Item -Recurse -Force -LiteralPath $temporaryRoot
  }
}
