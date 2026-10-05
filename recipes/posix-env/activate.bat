@rem Activates the native POSIX environment of this prefix: brush as sh, the
@rem prefix's POSIX tools, and whatever toolchain the caller has on PATH.
@rem Installed as <prefix>/etc/conda/activate.d/posix-env.bat.
@rem
@rem Paths use forward slashes: build scripts paste PATH entries and shell
@rem paths into sed and eval, where backslashes are escape characters.

@for %%i in ("%~dp0..\..\..") do @set "POSIX_ENV_PREFIX=%%~fi"
@set "POSIX_ENV_PREFIX=%POSIX_ENV_PREFIX:\=/%"

@for %%v in (PATH PREFIX BUILD_PREFIX SRC_DIR RECIPE_DIR CONDA_PREFIX LIBRARY_PREFIX LIBRARY_BIN LIBRARY_INC LIBRARY_LIB SCRIPTS TEMP TMP) do @if defined %%v @call set "%%v=%%%%v:\=/%%"

@rem The prefix is flat (bin, lib, share); micromamba still puts conda's
@rem Windows layout on PATH, directories that hold nothing here.
@for %%d in ("Library/mingw-w64/bin" "Library/usr/bin" "Library/bin" "Scripts") do @call set "PATH=%%PATH:%POSIX_ENV_PREFIX%/%%~d;=%%"
@call set "PATH=%%PATH:%POSIX_ENV_PREFIX%;=%%"

@rem Configure runs /bin/sh, which does not exist, unless told otherwise.
@set "CONFIG_SHELL=%POSIX_ENV_PREFIX%/bin/sh.exe"
@set "SHELL=%POSIX_ENV_PREFIX%/bin/sh.exe"
@rem Autoconf detects ';' only by running /bin/sh, before config.site is read.
@set "PATH_SEPARATOR=;"
@set "CONFIG_SITE=%POSIX_ENV_PREFIX%/share/posix-env/config.site"
@rem Autoconf's program search tries "grep", never "grep.exe", unless told
@rem to.  In the environment, not only in config.site: configures that run
@rem without it (gcc's build-machine libraries: CONFIG_SITE=no-such-file)
@rem would find no program at all.
@set "ac_executable_extensions=.exe"
@rem AC_PROG_GREP and AC_PROG_SED search all of PATH for the "best" program
@rem and can pick another one (Git's, MSYS2's, under "Program Files", where
@rem the unquoted $GREP breaks).  Without config.site too.
@set "GREP=%POSIX_ENV_PREFIX%/bin/grep.exe"
@set "EGREP=%POSIX_ENV_PREFIX%/bin/grep.exe -E"
@set "FGREP=%POSIX_ENV_PREFIX%/bin/grep.exe -F"
@set "SED=%POSIX_ENV_PREFIX%/bin/sed.exe"
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
