# Prints what the environment's activation sets.
for v in POSIX_ENV_PREFIX CONFIG_SHELL SHELL PATH_SEPARATOR CONFIG_SITE \
    ac_executable_extensions GREP EGREP FGREP SED PERL5SHELL \
    lt_cv_deplibs_check_method lt_cv_file_magic_cmd LANG; do
  eval "printf '%s=%s\n' $v \"\${$v-<unset>}\""
done
printf 'grep=%s\n' "$(command -v grep)"
