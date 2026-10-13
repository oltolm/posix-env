@echo off
rem The posix-env launcher, installed at the top of the environment: opens a
rem POSIX shell (brush) in it, runs commands in it and manages its packages
rem from the channel named in its .condarc.  "posix-env help" lists the
rem commands; double-clicked (no arguments) it opens the shell.  In the
rem shell, the posix-env sh script hands its commands to this script.
rem
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
rem
rem Package changes can replace this script and micromamba: cmd reads a
rem batch file while it runs it, and Windows does not let a running program
rem be overwritten.  So micromamba runs from a copy, and every command that
rem can change the environment, the shell included, is one parenthesized
rem block ending in exit, which cmd reads whole before it runs it.
setlocal
set "POSIX_ENV_HOME=%~dp0"
set "POSIX_ENV_HOME=%POSIX_ENV_HOME:~0,-1%"
rem The posix-env command in the shell calls this script (before shift).
set "LAUNCHER=%~f0"
set "VERB=%~1"
rem Double-clicked: open the shell.
if "%VERB%"=="" if /i "%CD%"=="%POSIX_ENV_HOME%" set "VERB=run"
if "%VERB%"=="" goto help
if /i "%VERB%"=="help" goto help
if "%VERB%"=="-h" goto help
if "%VERB%"=="--help" goto help
if "%VERB%"=="/?" goto help
set "KNOWN="
for %%v in (run install remove list update setup) do if /i "%VERB%"=="%%v" set "KNOWN=1"
if not defined KNOWN (
  1>&2 echo posix-env: unknown command "%VERB%"
  1>&2 echo Run "posix-env help" for the commands.
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

if /i "%VERB%"=="run" goto run
set "MAMBA=%POSIX_ENV_HOME%\libexec\posix-env\micromamba.exe"
if /i "%VERB%"=="list" (
  "%MAMBA%" list -p "%POSIX_ENV_HOME%"
  exit /b
)
if /i not "%VERB%"=="update" if /i not "%VERB%"=="setup" if not defined ARGS (1>&2 echo usage: posix-env %VERB% NAME...& exit /b 2)

rem The channel the environment was created from: "  - URL" in .condarc.
set "CHANNEL="
if exist "%POSIX_ENV_HOME%\.condarc" for /f "usebackq tokens=1,*" %%a in ("%POSIX_ENV_HOME%\.condarc") do if "%%a"=="-" if not defined CHANNEL set "CHANNEL=%%b"
if not defined CHANNEL (
  1>&2 echo posix-env: no channel in %POSIX_ENV_HOME%\.condarc
  exit /b 1
)
set PACKAGES=posix-env autoconf automake libtool gettext-tools pkgconf ^
  diffutils patch file gzip libarchive xz zstd less
set "COPY=%TEMP%\posix-env-micromamba-%RANDOM%.exe"
copy /y "%MAMBA%" "%COPY%" >nul || exit /b 1

rem Each block ends in "exit /b !STATUS!" on a line of its own: joined to
rem another command (&, ||, a one-line if), or as a bare "exit /b", it
rem leaves the exit code of cmd /c at 0.  Delayed expansion only now: the
rem arguments may hold "!".
rem setup is the only command that adds the default packages or changes the
rem user's settings (Start menu, Windows Terminal, PATH): the installer runs
rem it, and the user runs it again to restore them.
if /i "%VERB%"=="setup" (
  echo Setting up the environment in %POSIX_ENV_HOME% ...
  "%COPY%" install -y -q -p "%POSIX_ENV_HOME%" -c "%CHANNEL%" --override-channels %PACKAGES% && "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%POSIX_ENV_HOME%\share\posix-env\posix-env-entries.ps1"
  call set "STATUS=%%ERRORLEVEL%%"
  del "%COPY%"
  setlocal EnableDelayedExpansion
  exit /b !STATUS!
)
if /i "%VERB%"=="update" (
  echo Updating the environment in %POSIX_ENV_HOME% ...
  "%COPY%" update --all -y -q -p "%POSIX_ENV_HOME%" -c "%CHANNEL%" --override-channels && echo Restart open POSIX shells to use the updated packages.
  call set "STATUS=%%ERRORLEVEL%%"
  del "%COPY%"
  setlocal EnableDelayedExpansion
  exit /b !STATUS!
)
if /i "%VERB%"=="install" (
  "%COPY%" install -y -q -p "%POSIX_ENV_HOME%" -c "%CHANNEL%" --override-channels %ARGS%
  call set "STATUS=%%ERRORLEVEL%%"
  del "%COPY%"
  setlocal EnableDelayedExpansion
  exit /b !STATUS!
)
(
  "%COPY%" remove -y -q -p "%POSIX_ENV_HOME%" %ARGS%
  call set "STATUS=%%ERRORLEVEL%%"
  del "%COPY%"
  setlocal EnableDelayedExpansion
  exit /b !STATUS!
)

:help
echo usage: posix-env COMMAND [ARGUMENTS]
echo.
echo   run               open a POSIX shell in the posix-env environment
echo   run COMMAND...    run a command in it (posix-env run make -j8)
echo   install NAME...   add packages (posix-env install dejagnu)
echo   remove NAME...    remove packages
echo   list              list the installed packages
echo   update            update all packages
echo   setup             add the default packages, the Start menu entry, the
echo                     Windows Terminal profile and posix-env on PATH
echo   help              show this help
echo.
echo The environment is %POSIX_ENV_HOME%.
echo In the shell, "posix-env COMMAND" does the same.
exit /b 0

:run
rem The user's settings (Start menu, Windows Terminal, PATH) are setup's;
rem run leaves them alone.

if not defined POSIX_ENV_TOOLCHAIN set "POSIX_ENV_TOOLCHAIN=C:\msys64\ucrt64\bin"
if not exist "%POSIX_ENV_TOOLCHAIN%\gcc.exe" echo Warning: no gcc in %POSIX_ENV_TOOLCHAIN% (set POSIX_ENV_TOOLCHAIN).
if not defined POSIX_ENV_GIT set "POSIX_ENV_GIT=%ProgramFiles%\Git\cmd"
set "PATH=%POSIX_ENV_TOOLCHAIN%;%SystemRoot%\System32;%SystemRoot%"
if exist "%POSIX_ENV_GIT%\git.exe" set "PATH=%PATH%;%POSIX_ENV_GIT%"
if defined POSIX_ENV_EXTRA_PATH set "PATH=%PATH%;%POSIX_ENV_EXTRA_PATH%"
rem Started by double-click: begin in the home directory, not here.
if /i "%CD%"=="%POSIX_ENV_HOME%" cd /d "%USERPROFILE%"

set "POSIX_ENV_LAUNCHER=%LAUNCHER%"

rem Activate the environment here and start sh directly.  micromamba run
rem switches the console to VT processing without wrapping at the end of
rem the line for the program it runs (restored only when it exits): make's
rem long command lines ran off the right edge.
set "CONDA_PREFIX=%POSIX_ENV_HOME%"
set "PATH=%POSIX_ENV_HOME%\bin;%PATH%"
for %%f in ("%POSIX_ENV_HOME%\etc\conda\activate.d\*.bat") do call "%%~f"
rem posix-env in cmd started from the shell (bin/posix-env is for sh): this
rem directory, which holds no other program.  After activation, which drops
rem it from PATH.
set "PATH=%PATH%;%POSIX_ENV_HOME:\=/%"
rem The shell's status, as the package commands above pass theirs on.
if defined ARGS (
  "%POSIX_ENV_HOME%\bin\sh.exe" -c "exec ""$@""" sh %ARGS%
  call set "STATUS=%%ERRORLEVEL%%"
  setlocal EnableDelayedExpansion
  exit /b !STATUS!
)
(
  "%POSIX_ENV_HOME%\bin\sh.exe"
  call set "STATUS=%%ERRORLEVEL%%"
  setlocal EnableDelayedExpansion
  exit /b !STATUS!
)
