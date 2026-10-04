@rem Undoes the variables set by activate.d/posix-env.bat.  Slashes in paths
@rem that it rewrote stay forward; Windows accepts both.
@set "CONFIG_SHELL="
@set "SHELL="
@set "PATH_SEPARATOR="
@set "CONFIG_SITE="
@set "PERL5SHELL="
@if defined POSIX_ENV_SET_LANG set "LANG="
@set "POSIX_ENV_SET_LANG="
@if defined POSIX_ENV_SAVED_CP chcp %POSIX_ENV_SAVED_CP% >nul 2>&1
@set "POSIX_ENV_SAVED_CP="
@set "POSIX_ENV_PREFIX="
