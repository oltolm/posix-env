# Creates the user's entries for posix-shell.cmd: a Start menu shortcut and
# a Windows Terminal profile.  posix-shell.cmd runs this when an entry is
# missing; -Remove deletes both.
#   powershell -NoProfile -ExecutionPolicy Bypass -File posix-shell-entries.ps1 [-Remove]
param([switch]$Remove)
$ErrorActionPreference = 'Stop'

$name = 'POSIX Shell'
$launcher = Join-Path $PSScriptRoot 'posix-shell.cmd'
$shortcut = Join-Path ([Environment]::GetFolderPath('Programs')) "$name.lnk"
# Windows Terminal reads profile fragments from this directory (per user,
# for both the Store and the unpackaged installation).
$fragmentDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\posix-env'
$fragment = Join-Path $fragmentDir 'posix-shell.json'

if ($Remove) {
  Remove-Item -Force -ErrorAction SilentlyContinue $shortcut, $fragment
  if (Test-Path $fragmentDir) { Remove-Item -Force -Recurse $fragmentDir }
  return
}

if (-not (Test-Path $shortcut)) {
  $shell = New-Object -ComObject WScript.Shell
  $lnk = $shell.CreateShortcut($shortcut)
  $lnk.TargetPath = $launcher
  $lnk.WorkingDirectory = $env:USERPROFILE
  $lnk.Description = 'POSIX shell (brush) with the posix-env tools'
  $lnk.IconLocation = "$env:SystemRoot\System32\cmd.exe,0"
  $lnk.Save()
}

if (-not (Test-Path $fragment)) {
  New-Item -ItemType Directory -Force $fragmentDir | Out-Null
  $profile = [ordered]@{
    profiles = @(
      [ordered]@{
        name = $name
        commandline = $launcher
        startingDirectory = '%USERPROFILE%'
        icon = "$env:SystemRoot\System32\cmd.exe"
      }
    )
  }
  # UTF-8 without a BOM, as Windows Terminal expects.
  [IO.File]::WriteAllText($fragment, ($profile | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
}
