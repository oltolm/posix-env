# Activates the environment of this prefix for a shell that posix-env.cmd
# did not start: name this file in BASH_ENV and run the prefix's bash.exe.
# It sets the PATH of "posix-env run" and the variables of
# activate.d/posix-env.bat, which this file must follow.  Installed as
# <prefix>/share/posix-env/activate.sh.
#
# A shell that inherits an activated environment, as every shell that the
# first one starts does, finds POSIX_ENV_PREFIX set and changes nothing.
if test -z "${POSIX_ENV_PREFIX-}"; then
  POSIX_ENV_PREFIX=${BASH_SOURCE[0]//\\//}
  POSIX_ENV_PREFIX=${POSIX_ENV_PREFIX%/share/posix-env/activate.sh}

  # The PATH of "posix-env run": not the caller's, whose programs (Git's or
  # MSYS2's tools, text-mode ports) build scripts would otherwise find.
  _posix_env_root=${SystemRoot:-C:/Windows}
  _posix_env_root=${_posix_env_root//\\//}
  _posix_env_git=${POSIX_ENV_GIT:-${ProgramFiles:-C:/Program Files}/Git/cmd}
  _posix_env_git=${_posix_env_git//\\//}
  _posix_env_toolchain=${POSIX_ENV_TOOLCHAIN:-C:/msys64/ucrt64/bin}
  PATH="$POSIX_ENV_PREFIX/bin;${_posix_env_toolchain//\\//};$_posix_env_root/System32;$_posix_env_root"
  if test -f "$_posix_env_git/git.exe"; then
    PATH="$PATH;$_posix_env_git"
  fi
  if test -n "${POSIX_ENV_EXTRA_PATH-}"; then
    PATH="$PATH;${POSIX_ENV_EXTRA_PATH//\\//}"
  fi
  # posix-env.cmd itself, for posix-env in cmd started from the shell.
  PATH="$PATH;$POSIX_ENV_PREFIX"
  unset _posix_env_root _posix_env_git _posix_env_toolchain

  CONDA_PREFIX=$POSIX_ENV_PREFIX
  # bin/posix-env hands its commands to the launcher named here.
  POSIX_ENV_LAUNCHER="${POSIX_ENV_PREFIX//\//\\}\\posix-env.cmd"
  test -z "${TEMP-}" || TEMP=${TEMP//\\//}
  test -z "${TMP-}" || TMP=${TMP//\\//}

  # As in activate.d/posix-env.bat, which explains each of them.
  CONFIG_SHELL=$POSIX_ENV_PREFIX/bin/sh.exe
  SHELL=$POSIX_ENV_PREFIX/bin/sh.exe
  PATH_SEPARATOR=';'
  CONFIG_SITE=$POSIX_ENV_PREFIX/share/posix-env/config.site
  ac_executable_extensions=.exe
  GREP=$POSIX_ENV_PREFIX/bin/grep.exe
  EGREP="$POSIX_ENV_PREFIX/bin/grep.exe -E"
  FGREP="$POSIX_ENV_PREFIX/bin/grep.exe -F"
  SED=$POSIX_ENV_PREFIX/bin/sed.exe
  PERL5SHELL=$POSIX_ENV_PREFIX/bin/perlsh.exe
  lt_cv_deplibs_check_method='file_magic file format (pei*-i386(.*architecture: i386)?|pe-arm-wince|pei?-x86-64)'
  lt_cv_file_magic_cmd='$OBJDUMP -f'
  if test -z "${LC_ALL-}" && test -z "${LANG-}"; then
    LANG=C.UTF-8
    POSIX_ENV_SET_LANG=1
    export LANG POSIX_ENV_SET_LANG
  fi
  export POSIX_ENV_PREFIX PATH CONDA_PREFIX POSIX_ENV_LAUNCHER CONFIG_SHELL SHELL \
    PATH_SEPARATOR CONFIG_SITE ac_executable_extensions GREP EGREP FGREP SED \
    PERL5SHELL lt_cv_deplibs_check_method lt_cv_file_magic_cmd
fi
