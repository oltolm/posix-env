@echo off
rem The posix-env launcher: opens a POSIX shell (brush) in the posix-env
rem environment, runs commands in it and manages its packages.  The
rem environment is created on first use.  "posix-shell help" lists the
rem commands; double-clicked (no arguments, started in tools\) it opens the
rem shell.  In the shell, the posix-env command forwards to this script.
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
rem The posix-env command in the shell calls this script (before shift).
set "LAUNCHER=%~f0"
set "VERB=%~1"
rem Double-clicked: open the shell.
if "%VERB%"=="" if /i "%CD%\"=="%TOOLS%" set "VERB=run"
if "%VERB%"=="" goto help
if /i "%VERB%"=="help" goto help
if "%VERB%"=="-h" goto help
if "%VERB%"=="--help" goto help
if "%VERB%"=="/?" goto help
set "KNOWN="
for %%v in (run install remove list update) do if /i "%VERB%"=="%%v" set "KNOWN=1"
if not defined KNOWN (
  1>&2 echo posix-shell: unknown command "%VERB%"
  1>&2 echo Run "posix-shell help" for the commands.
  exit /b 2
)

rem The arguments after the verb, quotes kept.
set "ARGS="
:args
shift
if [%1]==[] goto have_args
set ARGS=%ARGS% %1
goto args
:have_args

if not defined POSIX_ENV_HOME set "POSIX_ENV_HOME=%USERPROFILE%\posix-env"
if not defined POSIX_ENV_TOOLCHAIN set "POSIX_ENV_TOOLCHAIN=C:\msys64\ucrt64\bin"
set "CHANNEL=%TOOLS%..\output"
for %%i in ("%CHANNEL%") do set "CHANNEL=file:///%%~fi"
set "CHANNEL=%CHANNEL:\=/%"
set "MAMBA=%TOOLS%micromamba.exe"
set PACKAGES=posix-env autoconf automake libtool gettext-tools pkgconf ^
  diffutils patch file gzip libarchive xz zstd

if not exist "%POSIX_ENV_HOME%\conda-meta" (
  echo Creating the environment in %POSIX_ENV_HOME% ...
  "%MAMBA%" create -y -q -p "%POSIX_ENV_HOME%" -c "%CHANNEL%" --override-channels ^
    %PACKAGES% || (pause & exit /b 1)
)

if /i "%VERB%"=="run" goto run
if /i "%VERB%"=="list" (
  "%MAMBA%" list -p "%POSIX_ENV_HOME%"
  exit /b
)
if /i "%VERB%"=="update" (
  echo Updating the environment in %POSIX_ENV_HOME% ...
  "%MAMBA%" install -y -q -p "%POSIX_ENV_HOME%" -c "%CHANNEL%" --override-channels ^
    %PACKAGES% || exit /b 1
  "%MAMBA%" update --all -y -q -p "%POSIX_ENV_HOME%" -c "%CHANNEL%" --override-channels || exit /b 1
  echo Restart open POSIX shells to use the updated packages.
  exit /b 0
)
if not defined ARGS (1>&2 echo usage: posix-shell %VERB% NAME...& exit /b 2)
if /i "%VERB%"=="remove" goto remove
"%MAMBA%" install -y -q -p "%POSIX_ENV_HOME%" -c "%CHANNEL%" --override-channels %ARGS%
exit /b
:remove
"%MAMBA%" remove -y -q -p "%POSIX_ENV_HOME%" %ARGS%
exit /b

:help
echo usage: posix-shell COMMAND [ARGUMENTS]
echo.
echo   run               open a POSIX shell in the posix-env environment
echo   run COMMAND...    run a command in it (posix-shell run make -j8)
echo   install NAME...   add packages (posix-shell install dejagnu)
echo   remove NAME...    remove packages
echo   list              list the installed packages
echo   update            update all packages and add missing default ones
echo   help              show this help
echo.
echo The environment is %%POSIX_ENV_HOME%% (default %%USERPROFILE%%\posix-env),
echo created on first use.  In the shell, "posix-env COMMAND" does the same.
exit /b 0

:run
rem A Start menu entry and a Windows Terminal profile, both "POSIX Shell",
rem start "posix-shell run"; posix-shell-entries.ps1 creates them, or
rem rewrites them when they predate the run command, and -Remove deletes
rem them.
set "ENTRY=%APPDATA%\Microsoft\Windows\Start Menu\Programs\POSIX Shell.lnk"
set "FRAGMENT=%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\posix-env\posix-shell.json"
set "ENTRIES=1"
if not exist "%ENTRY%" set "ENTRIES="
if not exist "%FRAGMENT%" set "ENTRIES="
if defined ENTRIES findstr /r /c:"posix-shell.cmd.* run" "%FRAGMENT%" >nul || set "ENTRIES="
if not defined ENTRIES "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%TOOLS%posix-shell-entries.ps1"

if not exist "%POSIX_ENV_TOOLCHAIN%\gcc.exe" echo Warning: no gcc in %POSIX_ENV_TOOLCHAIN% (set POSIX_ENV_TOOLCHAIN).
if not defined POSIX_ENV_GIT set "POSIX_ENV_GIT=%ProgramFiles%\Git\cmd"
set "PATH=%POSIX_ENV_TOOLCHAIN%;%SystemRoot%\System32;%SystemRoot%"
if exist "%POSIX_ENV_GIT%\git.exe" set "PATH=%PATH%;%POSIX_ENV_GIT%"
if defined POSIX_ENV_EXTRA_PATH set "PATH=%PATH%;%POSIX_ENV_EXTRA_PATH%"
rem Started by double-click: begin in the home directory, not in tools\.
if /i "%CD%\"=="%TOOLS%" cd /d "%USERPROFILE%"

set "POSIX_ENV_LAUNCHER=%LAUNCHER%"

rem Activate the environment here and start sh directly.  micromamba run
rem switches the console to VT processing without wrapping at the end of
rem the line for the program it runs (restored only when it exits): make's
rem long command lines ran off the right edge.
set "CONDA_PREFIX=%POSIX_ENV_HOME%"
set "PATH=%POSIX_ENV_HOME%\bin;%PATH%"
for %%f in ("%POSIX_ENV_HOME%\etc\conda\activate.d\*.bat") do call "%%~f"
if defined ARGS goto command
"%POSIX_ENV_HOME%\bin\sh.exe"
exit /b
:command
"%POSIX_ENV_HOME%\bin\sh.exe" -c "exec ""$@""" sh %ARGS%
