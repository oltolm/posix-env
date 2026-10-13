@echo off
rem posix-env from this checkout's channel (output\).  "setup" creates the
rem environment if there is none, records the channel in its .condarc and
rem runs the installed launcher's setup (posix-env.cmd at the top of the
rem environment: default packages, Start menu entry, Windows Terminal
rem profile, posix-env on PATH).  Every other command goes to the installed
rem launcher ("posix-env help").  Once the environment is set up, the
rem checkout is not needed.
rem
rem   POSIX_ENV_HOME       the environment (default %USERPROFILE%\posix-env)
setlocal
set "TOOLS=%~dp0"
if not defined POSIX_ENV_HOME set "POSIX_ENV_HOME=%USERPROFILE%\posix-env"
if /i "%~1"=="setup" goto setup

if not exist "%POSIX_ENV_HOME%\posix-env.cmd" (
  1>&2 echo posix-env: no environment in %POSIX_ENV_HOME%
  1>&2 echo Run "%~f0 setup" first.
  if "%~1"=="" pause
  exit /b 1
)
rem Double-clicked: open the shell, in the home directory.
if "%~1"=="" if /i "%CD%\"=="%TOOLS%" (
  cd /d "%USERPROFILE%"
  "%POSIX_ENV_HOME%\posix-env.cmd" run
  exit /b
)
"%POSIX_ENV_HOME%\posix-env.cmd" %*
exit /b

:setup
set "CHANNEL=%TOOLS%..\output"
for %%i in ("%CHANNEL%") do set "CHANNEL=file:///%%~fi"
set "CHANNEL=%CHANNEL:\=/%"
set "MAMBA=%TOOLS%micromamba.exe"
if exist "%POSIX_ENV_HOME%\conda-meta" goto have_env
echo Creating the environment in %POSIX_ENV_HOME% ...
"%MAMBA%" create -y -q -p "%POSIX_ENV_HOME%" -c "%CHANNEL%" --override-channels posix-env || exit /b 1
:have_env
rem An environment from before the launcher was packaged ("install" keeps
rem the installed posix-env).
if exist "%POSIX_ENV_HOME%\posix-env.cmd" goto have_launcher
"%MAMBA%" update -y -q -p "%POSIX_ENV_HOME%" -c "%CHANNEL%" --override-channels posix-env || exit /b 1
:have_launcher
if exist "%POSIX_ENV_HOME%\.condarc" goto have_channel
>"%POSIX_ENV_HOME%\.condarc" echo channels:
>>"%POSIX_ENV_HOME%\.condarc" echo   - %CHANNEL%
:have_channel
"%POSIX_ENV_HOME%\posix-env.cmd" setup
