# Excerpts from Libtool 2.2.7a bundled with gcc.
func_normal_abspath ()
{
  # Start from root dir and reassemble the path.
  func_normal_abspath_result=
  func_normal_abspath_tpath=$1
  func_normal_abspath_altnamespace=
  case $func_normal_abspath_tpath in
    "")
      # Empty path, that just means $cwd.
      func_stripname '' '/' "`pwd`"
      func_normal_abspath_result=$func_stripname_result
      return
    ;;
    # The next three entries are used to spot a run of precisely
    # two leading slashes without using negated character classes;
    # we take advantage of case's first-match behaviour.
    ///*)
      # Unusual form of absolute path, do nothing.
    ;;
    //*)
      # Not necessarily an ordinary path; POSIX reserves leading '//'
      # and for example Cygwin uses it to access remote file shares
      # over CIFS/SMB, so we conserve a leading double slash if found.
      func_normal_abspath_altnamespace=/
    ;;
    /*)
      # Absolute path, do nothing.
    ;;
    *)
      # Relative path, prepend $cwd.
      func_normal_abspath_tpath=`pwd`/$func_normal_abspath_tpath
    ;;
  esac
  # Cancel out all the simple stuff to save iterations.  We also want
  # the path to end with a slash for ease of parsing, so make sure
  # there is one (and only one) here.
  func_normal_abspath_tpath=`$ECHO "$func_normal_abspath_tpath" | $SED \
        -e "$removedotparts" -e "$collapseslashes" -e "$finalslash"`
  while :; do
    # Processed it all yet?
    if test "$func_normal_abspath_tpath" = / ; then
      # If we ascended to the root using ".." the result may be empty now.
      if test -z "$func_normal_abspath_result" ; then
        func_normal_abspath_result=/
      fi
      break
    fi
    func_normal_abspath_tcomponent=`$ECHO "$func_normal_abspath_tpath" | $SED \
        -e "$pathcar"`
    func_normal_abspath_tpath=`$ECHO "$func_normal_abspath_tpath" | $SED \
        -e "$pathcdr"`
    # Figure out what to do with it
    case $func_normal_abspath_tcomponent in
      "")
        # Trailing empty path component, ignore it.
      ;;
      ..)
        # Parent dir; strip last assembled component from result.
        func_dirname "$func_normal_abspath_result"
        func_normal_abspath_result=$func_dirname_result
      ;;
      *)
        # Actual path component, append it.
        func_normal_abspath_result=$func_normal_abspath_result/$func_normal_abspath_tcomponent
      ;;
    esac
  done
  # Restore leading double-slash if one was found on entry.
  func_normal_abspath_result=$func_normal_abspath_altnamespace$func_normal_abspath_result
}
func_to_host_path ()
{
  func_to_host_path_result="$1"
  if test -n "$1"; then
    case $host in
      *mingw* )
        lt_sed_naive_backslashify='s|\\\\*|\\|g;s|/|\\|g;s|\\|\\\\|g'
        case $build in
          *mingw* ) # actually, msys
            # awkward: cmd appends spaces to result
            func_to_host_path_result=`( cmd //c echo "$1" ) 2>/dev/null |
              $SED -e 's/[ ]*$//' -e "$lt_sed_naive_backslashify"`
            ;;
          *cygwin* )
            func_to_host_path_result=`cygpath -w "$1" |
	      $SED -e "$lt_sed_naive_backslashify"`
            ;;
          * )
            # Unfortunately, winepath does not exit with a non-zero
            # error code, so we are forced to check the contents of
            # stdout. On the other hand, if the command is not
            # found, the shell will set an exit code of 127 and print
            # *an error message* to stdout. So we must check for both
            # error code of zero AND non-empty stdout, which explains
            # the odd construction:
            func_to_host_path_tmp1=`winepath -w "$1" 2>/dev/null`
            if test "$?" -eq 0 && test -n "${func_to_host_path_tmp1}"; then
              func_to_host_path_result=`$ECHO "$func_to_host_path_tmp1" |
                $SED -e "$lt_sed_naive_backslashify"`
            else
              # Allow warning below.
              func_to_host_path_result=
            fi
            ;;
        esac
        if test -z "$func_to_host_path_result" ; then
          func_error "Could not determine host path corresponding to"
          func_error "  \`$1'"
          func_error "Continuing, but uninstalled executables may not work."
          # Fallback:
          func_to_host_path_result="$1"
        fi
        ;;
    esac
  fi
}
func_to_host_pathlist ()
{
  func_to_host_pathlist_result="$1"
  if test -n "$1"; then
    case $host in
      *mingw* )
        lt_sed_naive_backslashify='s|\\\\*|\\|g;s|/|\\|g;s|\\|\\\\|g'
        # Remove leading and trailing path separator characters from
        # ARG. msys behavior is inconsistent here, cygpath turns them
        # into '.;' and ';.', and winepath ignores them completely.
	func_stripname : : "$1"
        func_to_host_pathlist_tmp1=$func_stripname_result
        case $build in
          *mingw* ) # Actually, msys.
            # Awkward: cmd appends spaces to result.
            func_to_host_pathlist_result=`
	      ( cmd //c echo "$func_to_host_pathlist_tmp1" ) 2>/dev/null |
	      $SED -e 's/[ ]*$//' -e "$lt_sed_naive_backslashify"`
            ;;
          *cygwin* )
            func_to_host_pathlist_result=`cygpath -w -p "$func_to_host_pathlist_tmp1" |
              $SED -e "$lt_sed_naive_backslashify"`
            ;;
          * )
            # unfortunately, winepath doesn't convert pathlists
            func_to_host_pathlist_result=""
            func_to_host_pathlist_oldIFS=$IFS
            IFS=:
            for func_to_host_pathlist_f in $func_to_host_pathlist_tmp1 ; do
              IFS=$func_to_host_pathlist_oldIFS
              if test -n "$func_to_host_pathlist_f" ; then
                func_to_host_path "$func_to_host_pathlist_f"
                if test -n "$func_to_host_path_result" ; then
                  if test -z "$func_to_host_pathlist_result" ; then
                    func_to_host_pathlist_result="$func_to_host_path_result"
                  else
                    func_append func_to_host_pathlist_result ";$func_to_host_path_result"
                  fi
                fi
              fi
            done
            IFS=$func_to_host_pathlist_oldIFS
            ;;
        esac
        if test -z "$func_to_host_pathlist_result"; then
          func_error "Could not determine the host path(s) corresponding to"
          func_error "  \`$1'"
          func_error "Continuing, but uninstalled executables may not work."
          # Fallback. This may break if $1 contains DOS-style drive
          # specifications. The fix is not to complicate the expression
          # below, but for the user to provide a working wine installation
          # with winepath so that path translation in the cross-to-mingw
          # case works properly.
          lt_replace_pathsep_nix_to_dos="s|:|;|g"
          func_to_host_pathlist_result=`echo "$func_to_host_pathlist_tmp1" |\
            $SED -e "$lt_replace_pathsep_nix_to_dos"`
        fi
        # Now, add the leading and trailing path separators back
        case "$1" in
          :* ) func_to_host_pathlist_result=";$func_to_host_pathlist_result"
            ;;
        esac
        case "$1" in
          *: ) func_append func_to_host_pathlist_result ";"
            ;;
        esac
        ;;
    esac
  fi
}
func_emit_cwrapperexe_src ()
{
	cat <<EOF

/* $cwrappersource - temporary wrapper executable for $objdir/$outputname
   Generated by $PROGRAM (GNU $PACKAGE$TIMESTAMP) $VERSION

   The $output program cannot be directly executed until all the libtool
   libraries that it depends on are installed.

   This wrapper executable should never be moved out of the build directory.
   If it is, it will not operate correctly.

   Currently, it simply execs the wrapper *script* "$SHELL $output",
   but could eventually absorb all of the scripts functionality and
   exec $objdir/$outputname directly.
*/
EOF
	    cat <<"EOF"
#ifdef _MSC_VER
# define _CRT_SECURE_NO_DEPRECATE 1
#endif
#include <stdio.h>
#include <stdlib.h>
#ifdef _MSC_VER
# include <direct.h>
# include <process.h>
# include <io.h>
#else
# include <unistd.h>
# include <stdint.h>
# ifdef __CYGWIN__
#  include <io.h>
# endif
#endif
#include <malloc.h>
#include <stdarg.h>
#include <assert.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>

/* declarations of non-ANSI functions */
#if defined(__MINGW32__)
# ifdef __STRICT_ANSI__
int _putenv (const char *);
# endif
#elif defined(__CYGWIN__)
# ifdef __STRICT_ANSI__
char *realpath (const char *, char *);
int putenv (char *);
int setenv (const char *, const char *, int);
# endif
/* #elif defined (other platforms) ... */
#endif

/* portability defines, excluding path handling macros */
#if defined(_MSC_VER)
# define setmode _setmode
# define stat    _stat
# define chmod   _chmod
# define getcwd  _getcwd
# define putenv  _putenv
# define S_IXUSR _S_IEXEC
# ifndef _INTPTR_T_DEFINED
#  define _INTPTR_T_DEFINED
#  define intptr_t int
# endif
#elif defined(__MINGW32__)
# define setmode _setmode
# define stat    _stat
# define chmod   _chmod
# define getcwd  _getcwd
# define putenv  _putenv
#elif defined(__CYGWIN__)
# define HAVE_SETENV
# define FOPEN_WB "wb"
/* #elif defined (other platforms) ... */
#endif

#if defined(PATH_MAX)
# define LT_PATHMAX PATH_MAX
#elif defined(MAXPATHLEN)
# define LT_PATHMAX MAXPATHLEN
#else
# define LT_PATHMAX 1024
#endif

#ifndef S_IXOTH
# define S_IXOTH 0
#endif
#ifndef S_IXGRP
# define S_IXGRP 0
#endif

/* path handling portability macros */
#ifndef DIR_SEPARATOR
# define DIR_SEPARATOR '/'
# define PATH_SEPARATOR ':'
#endif

#if (defined (_WIN32) && ! defined(__CYGWIN__)) || defined (__MSDOS__) || \
  defined (__DJGPP__) || defined (__OS2__)
# define HAVE_DOS_BASED_FILE_SYSTEM
# define FOPEN_WB "wb"
# ifndef DIR_SEPARATOR_2
#  define DIR_SEPARATOR_2 '\\'
# endif
# ifndef PATH_SEPARATOR_2
#  define PATH_SEPARATOR_2 ';'
# endif
#endif

#ifndef DIR_SEPARATOR_2
# define IS_DIR_SEPARATOR(ch) ((ch) == DIR_SEPARATOR)
#else /* DIR_SEPARATOR_2 */
# define IS_DIR_SEPARATOR(ch) \
	(((ch) == DIR_SEPARATOR) || ((ch) == DIR_SEPARATOR_2))
#endif /* DIR_SEPARATOR_2 */

#ifndef PATH_SEPARATOR_2
# define IS_PATH_SEPARATOR(ch) ((ch) == PATH_SEPARATOR)
#else /* PATH_SEPARATOR_2 */
# define IS_PATH_SEPARATOR(ch) ((ch) == PATH_SEPARATOR_2)
#endif /* PATH_SEPARATOR_2 */

#ifndef FOPEN_WB
# define FOPEN_WB "w"
#endif
#ifndef _O_BINARY
# define _O_BINARY 0
#endif

#define XMALLOC(type, num)      ((type *) xmalloc ((num) * sizeof(type)))
#define XFREE(stale) do { \
  if (stale) { free ((void *) stale); stale = 0; } \
} while (0)

#undef LTWRAPPER_DEBUGPRINTF
#if defined LT_DEBUGWRAPPER
# define LTWRAPPER_DEBUGPRINTF(args) ltwrapper_debugprintf args
static void
ltwrapper_debugprintf (const char *fmt, ...)
{
    va_list args;
    va_start (args, fmt);
    (void) vfprintf (stderr, fmt, args);
    va_end (args);
}
#else
# define LTWRAPPER_DEBUGPRINTF(args)
#endif

const char *program_name = NULL;

void *xmalloc (size_t num);
char *xstrdup (const char *string);
const char *base_name (const char *name);
char *find_executable (const char *wrapper);
char *chase_symlinks (const char *pathspec);
int make_executable (const char *path);
int check_executable (const char *path);
char *strendzap (char *str, const char *pat);
void lt_fatal (const char *message, ...);
void lt_setenv (const char *name, const char *value);
char *lt_extend_str (const char *orig_value, const char *add, int to_end);
void lt_update_exe_path (const char *name, const char *value);
void lt_update_lib_path (const char *name, const char *value);
char **prepare_spawn (char **argv);
void lt_dump_script (FILE *f);
EOF

	    cat <<EOF
const char * MAGIC_EXE = "$magic_exe";
const char * LIB_PATH_VARNAME = "$shlibpath_var";
EOF

	    if test "$shlibpath_overrides_runpath" = yes && test -n "$shlibpath_var" && test -n "$temp_rpath"; then
              func_to_host_pathlist "$temp_rpath"
	      cat <<EOF
const char * LIB_PATH_VALUE   = "$func_to_host_pathlist_result";
EOF
	    else
	      cat <<"EOF"
const char * LIB_PATH_VALUE   = "";
EOF
	    fi

	    if test -n "$dllsearchpath"; then
              func_to_host_pathlist "$dllsearchpath:"
	      cat <<EOF
const char * EXE_PATH_VARNAME = "PATH";
const char * EXE_PATH_VALUE   = "$func_to_host_pathlist_result";
EOF
	    else
	      cat <<"EOF"
const char * EXE_PATH_VARNAME = "";
const char * EXE_PATH_VALUE   = "";
EOF
	    fi

	    if test "$fast_install" = yes; then
	      cat <<EOF
const char * TARGET_PROGRAM_NAME = "lt-$outputname"; /* hopefully, no .exe */
EOF
	    else
	      cat <<EOF
const char * TARGET_PROGRAM_NAME = "$outputname"; /* hopefully, no .exe */
EOF
	    fi


	    cat <<"EOF"

#define LTWRAPPER_OPTION_PREFIX         "--lt-"
#define LTWRAPPER_OPTION_PREFIX_LENGTH  5

static const size_t opt_prefix_len         = LTWRAPPER_OPTION_PREFIX_LENGTH;
static const char *ltwrapper_option_prefix = LTWRAPPER_OPTION_PREFIX;

static const char *dumpscript_opt       = LTWRAPPER_OPTION_PREFIX "dump-script";

int
main (int argc, char *argv[])
{
  char **newargz;
  int  newargc;
  char *tmp_pathspec;
  char *actual_cwrapper_path;
  char *actual_cwrapper_name;
  char *target_name;
  char *lt_argv_zero;
  intptr_t rval = 127;

  int i;

  program_name = (char *) xstrdup (base_name (argv[0]));
  LTWRAPPER_DEBUGPRINTF (("(main) argv[0]      : %s\n", argv[0]));
  LTWRAPPER_DEBUGPRINTF (("(main) program_name : %s\n", program_name));

  /* very simple arg parsing; don't want to rely on getopt */
  for (i = 1; i < argc; i++)
    {
      if (strcmp (argv[i], dumpscript_opt) == 0)
	{
EOF
	    case "$host" in
	      *mingw* | *cygwin* )
		# make stdout use "unix" line endings
		echo "          setmode(1,_O_BINARY);"
		;;
	      esac

	    cat <<"EOF"
	  lt_dump_script (stdout);
	  return 0;
	}
    }

  newargz = XMALLOC (char *, argc + 1);
  tmp_pathspec = find_executable (argv[0]);
  if (tmp_pathspec == NULL)
    lt_fatal ("Couldn't find %s", argv[0]);
  LTWRAPPER_DEBUGPRINTF (("(main) found exe (before symlink chase) at : %s\n",
			  tmp_pathspec));

  actual_cwrapper_path = chase_symlinks (tmp_pathspec);
  LTWRAPPER_DEBUGPRINTF (("(main) found exe (after symlink chase) at : %s\n",
			  actual_cwrapper_path));
  XFREE (tmp_pathspec);

  actual_cwrapper_name = xstrdup( base_name (actual_cwrapper_path));
  strendzap (actual_cwrapper_path, actual_cwrapper_name);

  /* wrapper name transforms */
  strendzap (actual_cwrapper_name, ".exe");
  tmp_pathspec = lt_extend_str (actual_cwrapper_name, ".exe", 1);
  XFREE (actual_cwrapper_name);
  actual_cwrapper_name = tmp_pathspec;
  tmp_pathspec = 0;

  /* target_name transforms -- use actual target program name; might have lt- prefix */
  target_name = xstrdup (base_name (TARGET_PROGRAM_NAME));
  strendzap (target_name, ".exe");
  tmp_pathspec = lt_extend_str (target_name, ".exe", 1);
  XFREE (target_name);
  target_name = tmp_pathspec;
  tmp_pathspec = 0;

  LTWRAPPER_DEBUGPRINTF (("(main) libtool target name: %s\n",
			  target_name));
EOF

	    cat <<EOF
  newargz[0] =
    XMALLOC (char, (strlen (actual_cwrapper_path) +
		    strlen ("$objdir") + 1 + strlen (actual_cwrapper_name) + 1));
  strcpy (newargz[0], actual_cwrapper_path);
  strcat (newargz[0], "$objdir");
  strcat (newargz[0], "/");
EOF

	    cat <<"EOF"
  /* stop here, and copy so we don't have to do this twice */
  tmp_pathspec = xstrdup (newargz[0]);

  /* do NOT want the lt- prefix here, so use actual_cwrapper_name */
  strcat (newargz[0], actual_cwrapper_name);

  /* DO want the lt- prefix here if it exists, so use target_name */
  lt_argv_zero = lt_extend_str (tmp_pathspec, target_name, 1);
  XFREE (tmp_pathspec);
  tmp_pathspec = NULL;
EOF

	    case $host_os in
	      mingw*)
	    cat <<"EOF"
  {
    char* p;
    while ((p = strchr (newargz[0], '\\')) != NULL)
      {
	*p = '/';
      }
    while ((p = strchr (lt_argv_zero, '\\')) != NULL)
      {
	*p = '/';
      }
  }
EOF
	    ;;
	    esac

	    cat <<"EOF"
  XFREE (target_name);
  XFREE (actual_cwrapper_path);
  XFREE (actual_cwrapper_name);

  lt_setenv ("BIN_SH", "xpg4"); /* for Tru64 */
  lt_setenv ("DUALCASE", "1");  /* for MSK sh */
  lt_update_lib_path (LIB_PATH_VARNAME, LIB_PATH_VALUE);
  lt_update_exe_path (EXE_PATH_VARNAME, EXE_PATH_VALUE);

  newargc=0;
  for (i = 1; i < argc; i++)
    {
      if (strncmp (argv[i], ltwrapper_option_prefix, opt_prefix_len) == 0)
        {
          /* however, if there is an option in the LTWRAPPER_OPTION_PREFIX
             namespace, but it is not one of the ones we know about and
             have already dealt with, above (inluding dump-script), then
             report an error. Otherwise, targets might begin to believe
             they are allowed to use options in the LTWRAPPER_OPTION_PREFIX
             namespace. The first time any user complains about this, we'll
             need to make LTWRAPPER_OPTION_PREFIX a configure-time option
             or a configure.ac-settable value.
           */
          lt_fatal ("Unrecognized option in %s namespace: '%s'",
                    ltwrapper_option_prefix, argv[i]);
        }
      /* otherwise ... */
      newargz[++newargc] = xstrdup (argv[i]);
    }
  newargz[++newargc] = NULL;

  LTWRAPPER_DEBUGPRINTF     (("(main) lt_argv_zero : %s\n", (lt_argv_zero ? lt_argv_zero : "<NULL>")));
  for (i = 0; i < newargc; i++)
    {
      LTWRAPPER_DEBUGPRINTF (("(main) newargz[%d]   : %s\n", i, (newargz[i] ? newargz[i] : "<NULL>")));
    }

EOF

	    case $host_os in
	      mingw*)
		cat <<"EOF"
  /* execv doesn't actually work on mingw as expected on unix */
  newargz = prepare_spawn (newargz);
  rval = _spawnv (_P_WAIT, lt_argv_zero, (const char * const *) newargz);
  if (rval == -1)
    {
      /* failed to start process */
      LTWRAPPER_DEBUGPRINTF (("(main) failed to launch target \"%s\": errno = %d\n", lt_argv_zero, errno));
      return 127;
    }
  return rval;
EOF
		;;
	      *)
		cat <<"EOF"
  execv (lt_argv_zero, newargz);
  return rval; /* =127, but avoids unused variable warning */
EOF
		;;
	    esac

	    cat <<"EOF"
}

void *
xmalloc (size_t num)
{
  void *p = (void *) malloc (num);
  if (!p)
    lt_fatal ("Memory exhausted");

  return p;
}

char *
xstrdup (const char *string)
{
  return string ? strcpy ((char *) xmalloc (strlen (string) + 1),
			  string) : NULL;
}

const char *
base_name (const char *name)
{
  const char *base;

#if defined (HAVE_DOS_BASED_FILE_SYSTEM)
  /* Skip over the disk name in MSDOS pathnames. */
  if (isalpha ((unsigned char) name[0]) && name[1] == ':')
    name += 2;
#endif

  for (base = name; *name; name++)
    if (IS_DIR_SEPARATOR (*name))
      base = name + 1;
  return base;
}

int
check_executable (const char *path)
{
  struct stat st;

  LTWRAPPER_DEBUGPRINTF (("(check_executable)  : %s\n",
			  path ? (*path ? path : "EMPTY!") : "NULL!"));
  if ((!path) || (!*path))
    return 0;

  if ((stat (path, &st) >= 0)
      && (st.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH)))
    return 1;
  else
    return 0;
}

int
make_executable (const char *path)
{
  int rval = 0;
  struct stat st;

  LTWRAPPER_DEBUGPRINTF (("(make_executable)   : %s\n",
			  path ? (*path ? path : "EMPTY!") : "NULL!"));
  if ((!path) || (!*path))
    return 0;

  if (stat (path, &st) >= 0)
    {
      rval = chmod (path, st.st_mode | S_IXOTH | S_IXGRP | S_IXUSR);
    }
  return rval;
}

/* Searches for the full path of the wrapper.  Returns
   newly allocated full path name if found, NULL otherwise
   Does not chase symlinks, even on platforms that support them.
*/
char *
find_executable (const char *wrapper)
{
  int has_slash = 0;
  const char *p;
  const char *p_next;
  /* static buffer for getcwd */
  char tmp[LT_PATHMAX + 1];
  int tmp_len;
  char *concat_name;

  LTWRAPPER_DEBUGPRINTF (("(find_executable)   : %s\n",
			  wrapper ? (*wrapper ? wrapper : "EMPTY!") : "NULL!"));

  if ((wrapper == NULL) || (*wrapper == '\0'))
    return NULL;

  /* Absolute path? */
#if defined (HAVE_DOS_BASED_FILE_SYSTEM)
  if (isalpha ((unsigned char) wrapper[0]) && wrapper[1] == ':')
    {
      concat_name = xstrdup (wrapper);
      if (check_executable (concat_name))
	return concat_name;
      XFREE (concat_name);
    }
  else
    {
#endif
      if (IS_DIR_SEPARATOR (wrapper[0]))
	{
	  concat_name = xstrdup (wrapper);
	  if (check_executable (concat_name))
	    return concat_name;
	  XFREE (concat_name);
	}
#if defined (HAVE_DOS_BASED_FILE_SYSTEM)
    }
#endif

  for (p = wrapper; *p; p++)
    if (*p == '/')
      {
	has_slash = 1;
	break;
      }
  if (!has_slash)
    {
      /* no slashes; search PATH */
      const char *path = getenv ("PATH");
      if (path != NULL)
	{
	  for (p = path; *p; p = p_next)
	    {
	      const char *q;
	      size_t p_len;
	      for (q = p; *q; q++)
		if (IS_PATH_SEPARATOR (*q))
		  break;
	      p_len = q - p;
	      p_next = (*q == '\0' ? q : q + 1);
	      if (p_len == 0)
		{
		  /* empty path: current directory */
		  if (getcwd (tmp, LT_PATHMAX) == NULL)
		    lt_fatal ("getcwd failed");
		  tmp_len = strlen (tmp);
		  concat_name =
		    XMALLOC (char, tmp_len + 1 + strlen (wrapper) + 1);
		  memcpy (concat_name, tmp, tmp_len);
		  concat_name[tmp_len] = '/';
		  strcpy (concat_name + tmp_len + 1, wrapper);
		}
	      else
		{
		  concat_name =
		    XMALLOC (char, p_len + 1 + strlen (wrapper) + 1);
		  memcpy (concat_name, p, p_len);
		  concat_name[p_len] = '/';
		  strcpy (concat_name + p_len + 1, wrapper);
		}
	      if (check_executable (concat_name))
		return concat_name;
	      XFREE (concat_name);
	    }
	}
      /* not found in PATH; assume curdir */
    }
  /* Relative path | not found in path: prepend cwd */
  if (getcwd (tmp, LT_PATHMAX) == NULL)
    lt_fatal ("getcwd failed");
  tmp_len = strlen (tmp);
  concat_name = XMALLOC (char, tmp_len + 1 + strlen (wrapper) + 1);
  memcpy (concat_name, tmp, tmp_len);
  concat_name[tmp_len] = '/';
  strcpy (concat_name + tmp_len + 1, wrapper);

  if (check_executable (concat_name))
    return concat_name;
  XFREE (concat_name);
  return NULL;
}

char *
chase_symlinks (const char *pathspec)
{
#ifndef S_ISLNK
  return xstrdup (pathspec);
#else
  char buf[LT_PATHMAX];
  struct stat s;
  char *tmp_pathspec = xstrdup (pathspec);
  char *p;
  int has_symlinks = 0;
  while (strlen (tmp_pathspec) && !has_symlinks)
    {
      LTWRAPPER_DEBUGPRINTF (("checking path component for symlinks: %s\n",
			      tmp_pathspec));
      if (lstat (tmp_pathspec, &s) == 0)
	{
	  if (S_ISLNK (s.st_mode) != 0)
	    {
	      has_symlinks = 1;
	      break;
	    }

	  /* search backwards for last DIR_SEPARATOR */
	  p = tmp_pathspec + strlen (tmp_pathspec) - 1;
	  while ((p > tmp_pathspec) && (!IS_DIR_SEPARATOR (*p)))
	    p--;
	  if ((p == tmp_pathspec) && (!IS_DIR_SEPARATOR (*p)))
	    {
	      /* no more DIR_SEPARATORS left */
	      break;
	    }
	  *p = '\0';
	}
      else
	{
	  char *errstr = strerror (errno);
	  lt_fatal ("Error accessing file %s (%s)", tmp_pathspec, errstr);
	}
    }
  XFREE (tmp_pathspec);

  if (!has_symlinks)
    {
      return xstrdup (pathspec);
    }

  tmp_pathspec = realpath (pathspec, buf);
  if (tmp_pathspec == 0)
    {
      lt_fatal ("Could not follow symlinks for %s", pathspec);
    }
  return xstrdup (tmp_pathspec);
#endif
}

char *
strendzap (char *str, const char *pat)
{
  size_t len, patlen;

  assert (str != NULL);
  assert (pat != NULL);

  len = strlen (str);
  patlen = strlen (pat);

  if (patlen <= len)
    {
      str += len - patlen;
      if (strcmp (str, pat) == 0)
	*str = '\0';
    }
  return str;
}

static void
lt_error_core (int exit_status, const char *mode,
	       const char *message, va_list ap)
{
  fprintf (stderr, "%s: %s: ", program_name, mode);
  vfprintf (stderr, message, ap);
  fprintf (stderr, ".\n");

  if (exit_status >= 0)
    exit (exit_status);
}

void
lt_fatal (const char *message, ...)
{
  va_list ap;
  va_start (ap, message);
  lt_error_core (EXIT_FAILURE, "FATAL", message, ap);
  va_end (ap);
}

void
lt_setenv (const char *name, const char *value)
{
  LTWRAPPER_DEBUGPRINTF (("(lt_setenv) setting '%s' to '%s'\n",
                          (name ? name : "<NULL>"),
                          (value ? value : "<NULL>")));
  {
#ifdef HAVE_SETENV
    /* always make a copy, for consistency with !HAVE_SETENV */
    char *str = xstrdup (value);
    setenv (name, str, 1);
#else
    int len = strlen (name) + 1 + strlen (value) + 1;
    char *str = XMALLOC (char, len);
    sprintf (str, "%s=%s", name, value);
    if (putenv (str) != EXIT_SUCCESS)
      {
        XFREE (str);
      }
#endif
  }
}

char *
lt_extend_str (const char *orig_value, const char *add, int to_end)
{
  char *new_value;
  if (orig_value && *orig_value)
    {
      int orig_value_len = strlen (orig_value);
      int add_len = strlen (add);
      new_value = XMALLOC (char, add_len + orig_value_len + 1);
      if (to_end)
        {
          strcpy (new_value, orig_value);
          strcpy (new_value + orig_value_len, add);
        }
      else
        {
          strcpy (new_value, add);
          strcpy (new_value + add_len, orig_value);
        }
    }
  else
    {
      new_value = xstrdup (add);
    }
  return new_value;
}

void
lt_update_exe_path (const char *name, const char *value)
{
  LTWRAPPER_DEBUGPRINTF (("(lt_update_exe_path) modifying '%s' by prepending '%s'\n",
                          (name ? name : "<NULL>"),
                          (value ? value : "<NULL>")));

  if (name && *name && value && *value)
    {
      char *new_value = lt_extend_str (getenv (name), value, 0);
      /* some systems can't cope with a ':'-terminated path #' */
      int len = strlen (new_value);
      while (((len = strlen (new_value)) > 0) && IS_PATH_SEPARATOR (new_value[len-1]))
        {
          new_value[len-1] = '\0';
        }
      lt_setenv (name, new_value);
      XFREE (new_value);
    }
}

void
lt_update_lib_path (const char *name, const char *value)
{
  LTWRAPPER_DEBUGPRINTF (("(lt_update_lib_path) modifying '%s' by prepending '%s'\n",
                          (name ? name : "<NULL>"),
                          (value ? value : "<NULL>")));

  if (name && *name && value && *value)
    {
      char *new_value = lt_extend_str (getenv (name), value, 0);
      lt_setenv (name, new_value);
      XFREE (new_value);
    }
}

EOF
	    case $host_os in
	      mingw*)
		cat <<"EOF"

/* Prepares an argument vector before calling spawn().
   Note that spawn() does not by itself call the command interpreter
     (getenv ("COMSPEC") != NULL ? getenv ("COMSPEC") :
      ({ OSVERSIONINFO v; v.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
         GetVersionEx(&v);
         v.dwPlatformId == VER_PLATFORM_WIN32_NT;
      }) ? "cmd.exe" : "command.com").
   Instead it simply concatenates the arguments, separated by ' ', and calls
   CreateProcess().  We must quote the arguments since Win32 CreateProcess()
   interprets characters like ' ', '\t', '\\', '"' (but not '<' and '>') in a
   special way:
   - Space and tab are interpreted as delimiters. They are not treated as
     delimiters if they are surrounded by double quotes: "...".
   - Unescaped double quotes are removed from the input. Their only effect is
     that within double quotes, space and tab are treated like normal
     characters.
   - Backslashes not followed by double quotes are not special.
   - But 2*n+1 backslashes followed by a double quote become
     n backslashes followed by a double quote (n >= 0):
       \" -> "
       \\\" -> \"
       \\\\\" -> \\"
 */
#define SHELL_SPECIAL_CHARS "\"\\ \001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037"
#define SHELL_SPACE_CHARS " \001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037"
char **
prepare_spawn (char **argv)
{
  size_t argc;
  char **new_argv;
  size_t i;

  /* Count number of arguments.  */
  for (argc = 0; argv[argc] != NULL; argc++)
    ;

  /* Allocate new argument vector.  */
  new_argv = XMALLOC (char *, argc + 1);

  /* Put quoted arguments into the new argument vector.  */
  for (i = 0; i < argc; i++)
    {
      const char *string = argv[i];

      if (string[0] == '\0')
	new_argv[i] = xstrdup ("\"\"");
      else if (strpbrk (string, SHELL_SPECIAL_CHARS) != NULL)
	{
	  int quote_around = (strpbrk (string, SHELL_SPACE_CHARS) != NULL);
	  size_t length;
	  unsigned int backslashes;
	  const char *s;
	  char *quoted_string;
	  char *p;

	  length = 0;
	  backslashes = 0;
	  if (quote_around)
	    length++;
	  for (s = string; *s != '\0'; s++)
	    {
	      char c = *s;
	      if (c == '"')
		length += backslashes + 1;
	      length++;
	      if (c == '\\')
		backslashes++;
	      else
		backslashes = 0;
	    }
	  if (quote_around)
	    length += backslashes + 1;

	  quoted_string = XMALLOC (char, length + 1);

	  p = quoted_string;
	  backslashes = 0;
	  if (quote_around)
	    *p++ = '"';
	  for (s = string; *s != '\0'; s++)
	    {
	      char c = *s;
	      if (c == '"')
		{
		  unsigned int j;
		  for (j = backslashes + 1; j > 0; j--)
		    *p++ = '\\';
		}
	      *p++ = c;
	      if (c == '\\')
		backslashes++;
	      else
		backslashes = 0;
	    }
	  if (quote_around)
	    {
	      unsigned int j;
	      for (j = backslashes; j > 0; j--)
		*p++ = '\\';
	      *p++ = '"';
	    }
	  *p = '\0';

	  new_argv[i] = quoted_string;
	}
      else
	new_argv[i] = (char *) string;
    }
  new_argv[argc] = NULL;

  return new_argv;
}
EOF
		;;
	    esac

            cat <<"EOF"
void lt_dump_script (FILE* f)
{
EOF
	    func_emit_wrapper yes |
              $SED -e 's/\([\\"]\)/\\\1/g' \
	           -e 's/^/  fputs ("/' -e 's/$/\\n", f);/'

            cat <<"EOF"
}
EOF
}
# end: func_emit_cwrapperexe_src
# fixture tail: preserve this
