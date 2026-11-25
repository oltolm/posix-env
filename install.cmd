@echo off
rem Installs packages from the checkout's local output\ channel into a
rem posix-env environment.
rem   install PACKAGE [PACKAGE...] [-- micromamba options]
rem
rem POSIX_ENV_PREFIX names the environment (default %USERPROFILE%\posix-env,
rem where the installer creates it).  Dependencies that were not built
rem locally come from the channel in the environment's .condarc.  Strict
rem channel priority takes a package that is in output\ only from there, so a
rem local build is installed even when the published channel has a higher
rem build number.
rem
rem The checkout's micromamba runs, not the environment's: installing the
rem posix-env package replaces the environment's copy.
setlocal
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
if not defined POSIX_ENV_PREFIX set "POSIX_ENV_PREFIX=%USERPROFILE%\posix-env"
if not exist "%POSIX_ENV_PREFIX%\conda-meta\" (
  1>&2 echo install: no posix-env environment in %POSIX_ENV_PREFIX% ^(set POSIX_ENV_PREFIX^)
  exit /b 1
)
set "CHANNEL=file:///%ROOT:\=/%/output"
rem The published channel: "  - URL" in .condarc, as the launcher reads it.
set "PUBLISHED="
if exist "%POSIX_ENV_PREFIX%\.condarc" for /f "usebackq tokens=1,*" %%a in ("%POSIX_ENV_PREFIX%\.condarc") do if "%%a"=="-" if not defined PUBLISHED set "PUBLISHED=-c %%b"

set "SPECS="
:args
if "%~1"=="" goto run
if "%~1"=="--" (shift & goto run)
set SPECS=%SPECS% "%~1"
shift
goto args

:run
if not defined SPECS (echo usage: install PACKAGE... [-- micromamba options] & exit /b 2)
rem install leaves an installed package alone even when output\ has a newer
rem build of it; update moves it to that build but refuses a package that is
rem not installed.  So install adds the missing packages first.
"%ROOT%\tools\micromamba.exe" --no-rc install -y -p "%POSIX_ENV_PREFIX%" --override-channels --strict-channel-priority -c "%CHANNEL%" %PUBLISHED% %SPECS% %1 %2 %3 %4 %5 %6 %7 %8 %9
if errorlevel 1 goto end
"%ROOT%\tools\micromamba.exe" --no-rc update -y -p "%POSIX_ENV_PREFIX%" --override-channels --strict-channel-priority -c "%CHANNEL%" %PUBLISHED% %SPECS% %1 %2 %3 %4 %5 %6 %7 %8 %9
:end
exit /b %ERRORLEVEL%
