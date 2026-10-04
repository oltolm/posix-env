@rem Activates the native POSIX environment of this prefix: brush as sh, the
@rem prefix's POSIX tools, and whatever toolchain the caller has on PATH.
@rem Installed as <prefix>/etc/conda/activate.d/posix-env.bat.
@rem
@rem Paths use forward slashes: build scripts paste PATH entries and shell
@rem paths into sed and eval, where backslashes are escape characters.

@for %%i in ("%~dp0..\..\..") do @set "POSIX_ENV_PREFIX=%%~fi"
@set "POSIX_ENV_PREFIX=%POSIX_ENV_PREFIX:\=/%"

@for %%v in (PATH PREFIX BUILD_PREFIX SRC_DIR RECIPE_DIR CONDA_PREFIX LIBRARY_PREFIX LIBRARY_BIN LIBRARY_INC LIBRARY_LIB SCRIPTS TEMP TMP) do @if defined %%v @call set "%%v=%%%%v:\=/%%"

@rem Configure runs /bin/sh, which does not exist, unless told otherwise.
@set "CONFIG_SHELL=%POSIX_ENV_PREFIX%/bin/sh.exe"
@set "SHELL=%POSIX_ENV_PREFIX%/bin/sh.exe"
@rem Autoconf detects ';' only by running /bin/sh, before config.site is read.
@set "PATH_SEPARATOR=;"
@set "CONFIG_SITE=%POSIX_ENV_PREFIX%/share/posix-env/config.site"
@rem Win32 perl hands commands to its shell the way cmd.exe expects them.
@set "PERL5SHELL=%POSIX_ENV_PREFIX%/bin/perlsh.exe"

@rem Programs follow LC_ALL, LC_* and LANG as on POSIX systems (config.site
@rem links posix-env's setlocale); without any, C conventions with UTF-8.
@if not defined LC_ALL if not defined LANG (
  set "LANG=C.UTF-8"
  set "POSIX_ENV_SET_LANG=1"
)
@rem The programs write UTF-8 (their manifests make it the active code page);
@rem the console shows it only in code page 65001.  The previous code page
@rem comes back on deactivation.
@if not defined POSIX_ENV_SAVED_CP for /f "tokens=2 delims=:." %%c in ('chcp 2^>nul') do @set /a "POSIX_ENV_SAVED_CP=%%c" >nul 2>&1
@chcp 65001 >nul 2>&1
