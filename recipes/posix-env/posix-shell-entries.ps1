# Creates the user's entries for the environment's posix-shell.cmd: a Start
# menu shortcut and a Windows Terminal profile, both running
# "posix-shell.cmd run".  posix-shell.cmd runs this when an entry is missing
# or starts another launcher; existing entries are rewritten.  -Remove
# deletes both.  Installed as <prefix>\share\posix-env\posix-shell-entries.ps1.
#   powershell -NoProfile -ExecutionPolicy Bypass -File posix-shell-entries.ps1 [-Remove]
param([switch]$Remove)
$ErrorActionPreference = 'Stop'

$name = 'POSIX Shell'
$launcher = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\posix-shell.cmd'))
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

& {
  $shell = New-Object -ComObject WScript.Shell
  $lnk = $shell.CreateShortcut($shortcut)
  $lnk.TargetPath = $launcher
  $lnk.Arguments = 'run'
  $lnk.WorkingDirectory = $env:USERPROFILE
  $lnk.Description = 'POSIX shell (brush) with the posix-env tools'
  $lnk.IconLocation = "$env:SystemRoot\System32\cmd.exe,0"
  $lnk.Save()
}

& {
  New-Item -ItemType Directory -Force $fragmentDir | Out-Null
  $profile = [ordered]@{
    profiles = @(
      [ordered]@{
        name = $name
        commandline = "`"$launcher`" run"
        startingDirectory = '%USERPROFILE%'
        icon = "$env:SystemRoot\System32\cmd.exe"
      }
    )
  }
  # UTF-8 without a BOM, as Windows Terminal expects.
  [IO.File]::WriteAllText($fragment, ($profile | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
}
