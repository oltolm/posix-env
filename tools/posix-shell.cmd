@echo off
rem Opens a POSIX shell (brush) in the posix-env environment, creating the
rem environment on first use.  Double-click it, or run it from cmd; any
rem arguments go to sh (posix-shell -c "make").
rem
rem   posix-shell update   updates every package to the newest build in the
rem                        local channel and adds default packages that are
rem                        missing, then exits
rem
rem   POSIX_ENV_HOME       the environment (default %USERPROFILE%\posix-env)
rem   POSIX_ENV_TOOLCHAIN  the compiler's bin directory, put on PATH
rem                        (default C:\msys64\ucrt64\bin)
rem   POSIX_ENV_GIT        a directory with git.exe and nothing else of note
rem                        (default %ProgramFiles%\Git\cmd)
rem   POSIX_ENV_EXTRA_PATH more directories for PATH
rem
rem The shell's PATH is the environment, the toolchain, System32 and
rem Windows, git, and POSIX_ENV_EXTRA_PATH: not the Windows PATH, whose
rem programs (Git's or MSYS2's tools, text-mode ports) would be found by
rem build scripts.
setlocal
set "TOOLS=%~dp0"
if not defined POSIX_ENV_HOME set "POSIX_ENV_HOME=%USERPROFILE%\posix-env"
if not defined POSIX_ENV_TOOLCHAIN set "POSIX_ENV_TOOLCHAIN=C:\msys64\ucrt64\bin"
set "CHANNEL=%TOOLS%..\output"
for %%i in ("%CHANNEL%") do set "CHANNEL=file:///%%~fi"
set "CHANNEL=%CHANNEL:\=/%"
set PACKAGES=posix-env autoconf automake libtool gettext-tools pkgconf ^
  diffutils patch gzip libarchive xz zstd

if not exist "%POSIX_ENV_HOME%\conda-meta" (
  echo Creating the environment in %POSIX_ENV_HOME% ...
  "%TOOLS%micromamba.exe" create -y -q -p "%POSIX_ENV_HOME%" -c "%CHANNEL%" --override-channels ^
    %PACKAGES% || (pause & exit /b 1)
)

if /i "%~1"=="update" (
  echo Updating the environment in %POSIX_ENV_HOME% ...
  "%TOOLS%micromamba.exe" install -y -q -p "%POSIX_ENV_HOME%" -c "%CHANNEL%" --override-channels ^
    %PACKAGES% || exit /b 1
  "%TOOLS%micromamba.exe" update --all -y -q -p "%POSIX_ENV_HOME%" -c "%CHANNEL%" --override-channels || exit /b 1
  echo Restart open POSIX shells to use the updated packages.
  exit /b 0
)

rem A Start menu entry and a Windows Terminal profile, both "POSIX Shell",
rem start this script; posix-shell-entries.ps1 -Remove deletes them.
set "ENTRY=%APPDATA%\Microsoft\Windows\Start Menu\Programs\POSIX Shell.lnk"
set "FRAGMENT=%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\posix-env\posix-shell.json"
set "ENTRIES=1"
if not exist "%ENTRY%" set "ENTRIES="
if not exist "%FRAGMENT%" set "ENTRIES="
if not defined ENTRIES "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%posix-shell-entries.ps1"

if not exist "%POSIX_ENV_TOOLCHAIN%\gcc.exe" echo Warning: no gcc in %POSIX_ENV_TOOLCHAIN% (set POSIX_ENV_TOOLCHAIN).
if not defined POSIX_ENV_GIT set "POSIX_ENV_GIT=%ProgramFiles%\Git\cmd"
set "PATH=%POSIX_ENV_TOOLCHAIN%;%SystemRoot%\System32;%SystemRoot%"
if exist "%POSIX_ENV_GIT%\git.exe" set "PATH=%PATH%;%POSIX_ENV_GIT%"
if defined POSIX_ENV_EXTRA_PATH set "PATH=%PATH%;%POSIX_ENV_EXTRA_PATH%"
rem Started by double-click: begin in the home directory, not in tools\.
if /i "%CD%\"=="%TOOLS%" cd /d "%USERPROFILE%"

rem Activate the environment here and start sh directly.  micromamba run
rem switches the console to VT processing without wrapping at the end of
rem the line for the program it runs (restored only when it exits): make's
rem long command lines ran off the right edge.
set "CONDA_PREFIX=%POSIX_ENV_HOME%"
set "PATH=%POSIX_ENV_HOME%\bin;%PATH%"
for %%f in ("%POSIX_ENV_HOME%\etc\conda\activate.d\*.bat") do call "%%~f"
"%POSIX_ENV_HOME%\bin\sh.exe" %*
