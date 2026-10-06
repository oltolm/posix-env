/* expect: tclsh with the Expect package loaded, and Expect's command line:

     expect [-dinNv] [-c cmds] [-D n] [[-f|-b] cmdfile] [--] [args]

   -c runs commands before the script (repeatable), -d turns on
   exp_internal, -v prints the version.  -D (the debugger), -i, -n and -N
   are accepted and ignored.  Without a script, it is an interactive Tcl
   shell.  DejaGnu's runtest starts "expect -- runtest.exp ARGS". */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <tcl.h>

static const char **commands;
static int ncommands;
static int diagnostics;

static int
AppInit (Tcl_Interp *interp)
{
  int i;

  if (Tcl_Init (interp) != TCL_OK)
    return TCL_ERROR;
  if (Tcl_PkgRequire (interp, "Expect", NULL, 0) == NULL)
    return TCL_ERROR;
  if (diagnostics && Tcl_Eval (interp, "exp_internal 1") != TCL_OK)
    return TCL_ERROR;
  for (i = 0; i < ncommands; i++)
    if (Tcl_EvalEx (interp, commands[i], -1, TCL_EVAL_GLOBAL) != TCL_OK)
      {
        fprintf (stderr, "%s\n",
                 Tcl_GetVar (interp, "errorInfo", TCL_GLOBAL_ONLY));
        exit (1);
      }
  Tcl_SetVar (interp, "tcl_rcFileName", "~/.expectrc", TCL_GLOBAL_ONLY);
  return TCL_OK;
}

int
main (int argc, char **argv)
{
  char **args = malloc ((argc + 1) * sizeof *args);
  int n = 0, i;

  commands = malloc (argc * sizeof *commands);
  args[n++] = argv[0];
  for (i = 1; i < argc; i++)
    {
      const char *a = argv[i];

      if (a[0] != '-' || a[1] == '\0')
        break;
      if (strcmp (a, "--") == 0)
        {
          i++;
          break;
        }
      if (strcmp (a, "-f") == 0 || strcmp (a, "-b") == 0)
        {
          i++;
          break;
        }
      if (strcmp (a, "-c") == 0)
        {
          if (++i < argc)
            commands[ncommands++] = argv[i];
          continue;
        }
      if (strcmp (a, "-D") == 0)
        {
          i++;
          continue;
        }
      if (strncmp (a, "-D", 2) == 0 || strcmp (a, "-i") == 0
          || strcmp (a, "-n") == 0 || strcmp (a, "-N") == 0)
        continue;
      if (strcmp (a, "-d") == 0)
        {
          diagnostics = 1;
          continue;
        }
      if (strcmp (a, "-v") == 0)
        {
          printf ("expect version 5.45.4\n");
          return 0;
        }
      fprintf (stderr, "usage: expect [-dinNv] [-c cmds] [-D n] "
               "[[-f|-b] cmdfile] [--] [args]\n");
      return 1;
    }
  for (; i < argc; i++)
    args[n++] = argv[i];
  args[n] = NULL;
  Tcl_Main (n, args, AppInit);
  return 0;
}
