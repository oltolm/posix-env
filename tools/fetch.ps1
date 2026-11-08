# Downloads the pinned rattler-build and micromamba binaries into tools\ and
# checks them against the published SHA-256 sums.
#   powershell -ExecutionPolicy Bypass -File tools\fetch.ps1
$ErrorActionPreference = 'Stop'
$tools = @(
  @{ Name = 'rattler-build.exe'
     Url = 'https://github.com/prefix-dev/rattler-build/releases/download/v0.76.1/rattler-build-x86_64-pc-windows-msvc.exe'
     Sha256 = '131e3d9e6d67e7b5e873627567e74708e1722a40e78bcd3619dc4b20906fbb64' },
  @{ Name = 'micromamba.exe'
     Url = 'https://github.com/mamba-org/micromamba-releases/releases/download/2.10.0-0/micromamba-win-64.exe'
     Sha256 = 'f8b4284bd4eb1134122eaf93b3ea6c7be567e596de5829e1a6f478e34e41974a' }
)
foreach ($t in $tools) {
  $dest = Join-Path $PSScriptRoot $t.Name
  if ((Test-Path $dest) -and (Get-FileHash $dest -Algorithm SHA256).Hash -eq $t.Sha256) { continue }
  Invoke-WebRequest -Uri $t.Url -OutFile "$dest.tmp" -UseBasicParsing
  $hash = (Get-FileHash "$dest.tmp" -Algorithm SHA256).Hash
  if ($hash -ne $t.Sha256) { Remove-Item "$dest.tmp"; throw "$($t.Name): SHA-256 $hash, expected $($t.Sha256)" }
  Move-Item -Force "$dest.tmp" $dest
}
