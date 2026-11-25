# share/posix-env/activate.sh, named in BASH_ENV, gives a bash started
# outside the environment (no activation variables, PATH only System32)
# what activate.d/posix-env.bat gives the test environment.
sh test/show-activation.sh > activated.txt || exit 1
set --
for v in POSIX_ENV_PREFIX CONDA_PREFIX POSIX_ENV_LAUNCHER CONFIG_SHELL SHELL \
    PATH_SEPARATOR CONFIG_SITE ac_executable_extensions GREP EGREP FGREP SED \
    PERL5SHELL lt_cv_deplibs_check_method lt_cv_file_magic_cmd; do
  set -- "$@" -u "$v"
done
test -z "${POSIX_ENV_SET_LANG-}" || set -- "$@" -u LANG -u POSIX_ENV_SET_LANG
env "$@" PATH="$SystemRoot/System32" \
  BASH_ENV="$POSIX_ENV_PREFIX/share/posix-env/activate.sh" \
  "$POSIX_ENV_PREFIX/bin/bash.exe" test/show-activation.sh > direct.txt || exit 1
diff activated.txt direct.txt
