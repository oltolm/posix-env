@echo off
rem Sets up the posix-env environment from this checkout's channel (output\)
rem and hands over to the launcher installed in it, posix-env.cmd at the
rem top of the environment, which takes the same commands ("posix-env
rem help").  Once the environment exists, the checkout is not needed: the
rem Start menu entry and the Windows Terminal profile start the installed
rem launcher, which installs and updates from the channel in the
rem environment's .condarc.
rem
rem   POSIX_ENV_HOME       the environment (default %USERPROFILE%\posix-env)
setlocal
set "TOOLS=%~dp0"
if not defined POSIX_ENV_HOME set "POSIX_ENV_HOME=%USERPROFILE%\posix-env"
set "CHANNEL=%TOOLS%..\output"
for %%i in ("%CHANNEL%") do set "CHANNEL=file:///%%~fi"
set "CHANNEL=%CHANNEL:\=/%"
set "MAMBA=%TOOLS%micromamba.exe"

set "FRESH="
if exist "%POSIX_ENV_HOME%\conda-meta" goto have_env
echo Creating the environment in %POSIX_ENV_HOME% ...
"%MAMBA%" create -y -q -p "%POSIX_ENV_HOME%" -c "%CHANNEL%" --override-channels posix-env || (pause & exit /b 1)
set "FRESH=1"
:have_env
rem An environment from before the launcher was packaged ("install" keeps
rem the installed posix-env).
if exist "%POSIX_ENV_HOME%\posix-env.cmd" goto have_launcher
"%MAMBA%" update -y -q -p "%POSIX_ENV_HOME%" -c "%CHANNEL%" --override-channels posix-env || (pause & exit /b 1)
:have_launcher
if exist "%POSIX_ENV_HOME%\.condarc" goto have_channel
>"%POSIX_ENV_HOME%\.condarc" echo channels:
>>"%POSIX_ENV_HOME%\.condarc" echo   - %CHANNEL%
:have_channel
rem The default packages are the installed launcher's to name.
if defined FRESH call "%POSIX_ENV_HOME%\posix-env.cmd" update || (pause & exit /b 1)
rem A new environment, once: the Start menu entry, the Terminal profile and
rem the user's PATH (posix-env in cmd).  Nothing else changes them.
if defined FRESH "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%POSIX_ENV_HOME%\share\posix-env\posix-env-entries.ps1"

rem Double-clicked: open the shell, in the home directory.
if "%~1"=="" if /i "%CD%\"=="%TOOLS%" (
  cd /d "%USERPROFILE%"
  "%POSIX_ENV_HOME%\posix-env.cmd" run
  exit /b
)
"%POSIX_ENV_HOME%\posix-env.cmd" %*
