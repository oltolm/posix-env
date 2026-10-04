/* chmod for Windows: the only permission NTFS exposes through the CRT is
   the read-only attribute, so honor write-bit changes and accept the rest.
   Build scripts run "chmod +x" on generated scripts; failing there would
   break them for no benefit.  */
#include <stdio.h>
#include <string.h>
#include <io.h>
#include <sys/stat.h>

/* Return 1 to set writable, 0 to clear, -1 for no write-bit change.  */
static int
write_bit (const char *mode)
{
  if (mode[0] >= '0' && mode[0] <= '7')
    {
      size_t n = strlen (mode);
      /* Owner digit is third from the right.  */
      char owner = n >= 3 ? mode[n - 3] : '0';
      return (owner - '0') & 2 ? 1 : 0;
    }
  int result = -1;
  const char *p = mode;
  while (*p)
    {
      int who_u = 0, any_who = 0;
      while (*p && strchr ("ugoa", *p))
	{
	  if (*p == 'u' || *p == 'a')
	    who_u = 1;
	  any_who = 1;
	  p++;
	}
      if (!any_who)
	who_u = 1;
      while (*p && strchr ("+-=", *p))
	{
	  char op = *p++;
	  int has_w = 0;
	  while (*p && strchr ("rwxXst", *p))
	    has_w |= *p++ == 'w';
	  if (who_u && (has_w || op == '='))
	    result = op == '-' ? 0 : has_w;
	}
      if (*p == ',')
	p++;
      else if (*p)
	return -2;
    }
  return result;
}

int
main (int argc, char **argv)
{
  int i = 1, status = 0;
  while (i < argc && argv[i][0] == '-' && strchr ("Rcfv", argv[i][1])
	 && argv[i][1])
    i++;
  if (i + 1 >= argc)
    {
      fprintf (stderr, "usage: chmod MODE FILE...\n");
      return 1;
    }
  int w = write_bit (argv[i]);
  if (w == -2)
    {
      fprintf (stderr, "chmod: invalid mode: '%s'\n", argv[i]);
      return 1;
    }
  for (i++; i < argc; i++)
    {
      struct _stat st;
      if (_stat (argv[i], &st) != 0)
	{
	  fprintf (stderr, "chmod: cannot access '%s'\n", argv[i]);
	  status = 1;
	  continue;
	}
      if (w >= 0
	  && _chmod (argv[i], w ? _S_IREAD | _S_IWRITE : _S_IREAD) != 0)
	{
	  fprintf (stderr, "chmod: changing permissions of '%s' failed\n",
		   argv[i]);
	  status = 1;
	}
    }
  return status;
}
