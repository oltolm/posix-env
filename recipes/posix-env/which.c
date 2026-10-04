/* which for Windows: find commands in PATH the way CreateProcess does
   (trying PATHEXT extensions), and print paths with '/' separators so the
   output can be pasted into shell scripts.
     which [-a] NAME...  */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

/* Return nonzero if PATH names a file, and replace its last component with
   the name as stored on disk; PATHEXT entries are upper case.  */
static int
is_file (char *path)
{
  WIN32_FIND_DATAA fd;
  HANDLE h = FindFirstFileA (path, &fd);
  char *base;

  if (h == INVALID_HANDLE_VALUE)
    return 0;
  FindClose (h);
  if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
    return 0;
  base = strrchr (path, '/');
  if (!base || (strrchr (path, '\\') && strrchr (path, '\\') > base))
    base = strrchr (path, '\\');
  base = base ? base + 1 : path;
  if (strlen (base) == strlen (fd.cFileName))
    strcpy (base, fd.cFileName);
  return 1;
}

static void
print_path (const char *path)
{
  for (const char *p = path; *p; p++)
    putchar (*p == '\\' ? '/' : *p);
  putchar ('\n');
}

/* Try DIR/NAME and DIR/NAME + each PATHEXT entry; print matches.
   Return the number printed, stopping after one unless ALL.  */
static int
try_dir (const char *dir, size_t dirlen, const char *name, const char *pathext,
	 int all)
{
  char buf[MAX_PATH * 2];
  int found = 0;
  int n = snprintf (buf, sizeof buf, "%.*s%s%s", (int) dirlen, dir,
		    dirlen && !strchr ("/\\", dir[dirlen - 1]) ? "/" : "", name);
  if (n < 0 || (size_t) n >= sizeof buf)
    return 0;

  /* A name that already has an extension, like gcc.exe, is used as is.  */
  if (strchr (name, '.') && is_file (buf))
    {
      print_path (buf);
      if (!all)
	return 1;
      found++;
    }
  for (const char *e = pathext; *e;)
    {
      size_t len = strcspn (e, ";");
      if (len && (size_t) n + len < sizeof buf)
	{
	  memcpy (buf + n, e, len);
	  buf[n + len] = '\0';
	  if (is_file (buf))
	    {
	      print_path (buf);
	      if (!all)
		return 1;
	      found++;
	    }
	}
      e += len + (e[len] == ';');
    }
  return found;
}

int
main (int argc, char **argv)
{
  int all = 0, status = 0, i = 1;
  const char *path = getenv ("PATH");
  const char *pathext = getenv ("PATHEXT");

  if (!pathext || !*pathext)
    pathext = ".COM;.EXE;.BAT;.CMD";
  if (!path)
    path = "";
  if (i < argc && strcmp (argv[i], "-a") == 0)
    all = 1, i++;
  if (i >= argc)
    {
      fprintf (stderr, "usage: which [-a] NAME...\n");
      return 2;
    }

  for (; i < argc; i++)
    {
      const char *name = argv[i];
      int found = 0;

      if (strpbrk (name, "/\\:"))
	found = try_dir ("", 0, name, pathext, all);
      else
	for (const char *d = path; *d && (all || !found);)
	  {
	    size_t len = strcspn (d, ";");
	    if (len)
	      found += try_dir (d, len, name, pathext, all);
	    d += len + (d[len] == ';');
	  }
      if (!found)
	{
	  fprintf (stderr, "which: no %s in PATH\n", name);
	  status = 1;
	}
    }
  return status;
}
