@echo off
rem Builds recipes into the local channel C:\src\posix-env\output.
rem   build RECIPE [RECIPE...] [-- rattler-build options]
rem
rem Only the local channel is used: rattler-build adds conda-forge when no
rem channel is given.  The toolchain is external; POSIX_ENV_TOOLCHAIN names
rem its bin directory.  rattler-build itself needs git for git sources;
rem POSIX_ENV_GIT names a directory with git.exe and nothing else of note.
rem Run tools\prefill.ps1 first to take sources from local copies.
setlocal
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
if not defined POSIX_ENV_TOOLCHAIN set "POSIX_ENV_TOOLCHAIN=C:\msys64\ucrt64\bin"
if not defined POSIX_ENV_GIT set "POSIX_ENV_GIT=%ProgramFiles%\Git\cmd"
set "PATH=%SystemRoot%\System32;%SystemRoot%;%POSIX_ENV_TOOLCHAIN%;%POSIX_ENV_GIT%"
set "CHANNEL=file:///%ROOT:\=/%/output"

set "RECIPES="
:args
if "%~1"=="" goto run
if "%~1"=="--" (shift & goto run)
set "RECIPES=%RECIPES% --recipe "%ROOT%\recipes\%~1""
shift
goto args

:run
if not defined RECIPES (echo usage: build RECIPE... [-- options] & exit /b 2)
"%ROOT%\tools\rattler-build.exe" build %RECIPES% --output-dir "%ROOT%\output" -c "%CHANNEL%" %1 %2 %3 %4 %5 %6 %7 %8 %9
