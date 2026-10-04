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
