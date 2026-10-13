# Sets up the user's access to the environment's posix-env.cmd: a Start
# menu shortcut and a Windows Terminal profile, both running
# "posix-env.cmd run", and with -AddPath the environment's top directory on
# the user's PATH, so "posix-env" works in cmd.  That directory holds no
# program but posix-env.cmd; the tools in bin stay off the Windows PATH.
# Setting up an environment runs this with -AddPath, once; posix-env.cmd run
# runs it without when an entry is missing or starts another launcher, and
# never changes PATH.  Existing entries are rewritten.  -Remove undoes all
# three.  Installed as <prefix>\share\posix-env\posix-env-entries.ps1.
#   powershell -NoProfile -ExecutionPolicy Bypass -File posix-env-entries.ps1 [-AddPath | -Remove]
param([switch]$AddPath, [switch]$Remove)
$ErrorActionPreference = 'Stop'

$name = 'POSIX Shell'
$launcher = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\posix-env.cmd'))
$shortcut = Join-Path ([Environment]::GetFolderPath('Programs')) "$name.lnk"
# Windows Terminal reads profile fragments from this directory (per user,
# for both the Store and the unpackaged installation).
$fragmentDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\posix-env'
$fragment = Join-Path $fragmentDir 'posix-shell.json'
$home_ = Split-Path $launcher

# The user's PATH, as stored: REG_EXPAND_SZ, its %VARIABLES% unexpanded
# ([Environment]::SetEnvironmentVariable would store REG_SZ and break them).
function Set-UserPath([scriptblock]$change) {
  $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
  try {
    $old = [string]$key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    $dirs = @($old -split ';' | Where-Object { $_ -ne '' })
    $new = (& $change $dirs) -join ';'
    if ($new -eq $old) { return }
    $key.SetValue('Path', $new, 'ExpandString')
  } finally { $key.Close() }
  if ($Remove) { Write-Host "Removed $home_ from your PATH." }
  else { Write-Host "Added $home_ to your PATH: posix-env works in new cmd windows." }
  # Tell Explorer, so that programs started from now on see the new PATH.
  Add-Type -Namespace PosixEnv -Name Native -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
  $result = [UIntPtr]::Zero
  [void][PosixEnv.Native]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
}
function Test-Home([string]$dir) {
  [Environment]::ExpandEnvironmentVariables($dir).TrimEnd('\') -eq $home_
}

if ($Remove) {
  Remove-Item -Force -ErrorAction SilentlyContinue $shortcut, $fragment
  if (Test-Path $fragmentDir) { Remove-Item -Force -Recurse $fragmentDir }
  Set-UserPath { param($dirs) $dirs | Where-Object { -not (Test-Home $_) } }
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

if ($AddPath) {
  Set-UserPath { param($dirs) if ($dirs | Where-Object { Test-Home $_ }) { $dirs } else { $dirs + $home_ } }
}
