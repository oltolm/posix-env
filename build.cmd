@echo off
rem Builds recipes into the checkout's local output\ channel.
rem   build RECIPE [RECIPE...] [-- rattler-build options]
rem
rem Only the local channel is used: rattler-build adds conda-forge when no
rem channel is given.  The toolchain is external; POSIX_ENV_TOOLCHAIN names
rem its bin directory.  rattler-build itself needs git for git sources;
rem POSIX_ENV_GIT names a directory with git.exe and nothing else of note.
rem POSIX_ENV_BOOTSTRAP_CHANNEL optionally adds an existing posix-env channel
rem after the local output channel.  CI uses the public channel to bootstrap
rem clean builds; normal local builds leave it unset.
rem
rem A package already in output\ is not built again: rattler-build keeps a
rem file's repodata.json entry when the file is replaced, so a rebuild under
rem the same build number leaves a wrong size and hash in the index, and
rem installs fail.  Raise build.number to build a changed recipe.
setlocal
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
if not defined POSIX_ENV_TOOLCHAIN set "POSIX_ENV_TOOLCHAIN=C:\msys64\ucrt64\bin"
if not defined POSIX_ENV_GIT set "POSIX_ENV_GIT=%ProgramFiles%\Git\cmd"
set "PATH=%SystemRoot%\System32;%SystemRoot%;%POSIX_ENV_TOOLCHAIN%;%POSIX_ENV_GIT%"
set "CHANNEL=file:///%ROOT:\=/%/output"
set "BOOTSTRAP_CHANNEL="
if defined POSIX_ENV_BOOTSTRAP_CHANNEL set "BOOTSTRAP_CHANNEL=-c "%POSIX_ENV_BOOTSTRAP_CHANNEL%""

set "RECIPES="
:args
if "%~1"=="" goto run
if "%~1"=="--" (shift & goto run)
set "RECIPES=%RECIPES% --recipe "%ROOT%\recipes\%~1""
shift
goto args

:run
if not defined RECIPES (echo usage: build RECIPE... [-- options] & exit /b 2)
"%ROOT%\tools\rattler-build.exe" build %RECIPES% --output-dir "%ROOT%\output" -c "%CHANNEL%" %BOOTSTRAP_CHANNEL% --skip-existing local %1 %2 %3 %4 %5 %6 %7 %8 %9
