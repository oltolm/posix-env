/* scriptexe: a launcher that makes a #! script runnable by Windows itself.
   Copied as NAME.exe next to the script NAME, it runs the script with the
   interpreter named on its #! line, followed by its own arguments.

   Windows cannot execute a script, so programs that start other programs
   without a shell (Win32 perl, make, cmd) fail on autoconf, automake and the
   like; given DIR/NAME, they try DIR/NAME.exe.

   The interpreter is used as written if it exists, and otherwise looked up
   by its base name in PATH, as brush does: "#! /bin/sh" finds sh.exe.
   "#! /usr/bin/env PROG" looks up PROG.  One optional argument after the
   interpreter is passed as one word, as on Linux.  */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <windows.h>

/* Return the text after the first token of the command line CMDLINE, which
   is split the way the C runtime splits argv[0].  */
static const wchar_t *
skip_program_name (const wchar_t *cmdline)
{
  const wchar_t *p = cmdline;

  if (*p == L'"')
    {
      p = wcschr (p + 1, L'"');
      p = p ? p + 1 : cmdline + wcslen (cmdline);
    }
  else
    while (*p && *p != L' ' && *p != L'\t')
      p++;
  while (*p == L' ' || *p == L'\t')
    p++;
  return p;
}

/* Append ARG to OUT as one argument for the C runtime's argv splitting.  */
static wchar_t *
append_quoted (wchar_t *out, const wchar_t *arg)
{
  *out++ = L'"';
  for (size_t i = 0, len = wcslen (arg); i < len;)
    {
      size_t backslashes = 0;
      while (i < len && arg[i] == L'\\')
	backslashes++, i++;
      if (i == len)
	backslashes *= 2;
      else if (arg[i] == L'"')
	backslashes = backslashes * 2 + 1;
      while (backslashes--)
	*out++ = L'\\';
      if (i < len)
	*out++ = arg[i++];
    }
  *out++ = L'"';
  return out;
}

static int
is_file (const wchar_t *path)
{
  DWORD attr = GetFileAttributesW (path);
  return attr != INVALID_FILE_ATTRIBUTES && !(attr & FILE_ATTRIBUTE_DIRECTORY);
}

/* Store in OUT the program PROG: the path itself or with ".exe" if either
   exists, else its base name searched in PATH.  */
static int
resolve (const wchar_t *prog, wchar_t *out, DWORD size)
{
  const wchar_t *base = prog;

  for (const wchar_t *p = prog; *p; p++)
    if (*p == L'/' || *p == L'\\')
      base = p + 1;
  if (base != prog)
    {
      if (is_file (prog) && wcslen (prog) < size)
	return wcscpy (out, prog), 1;
      if (_snwprintf (out, size, L"%ls.exe", prog) < (int) size && is_file (out))
	return 1;
    }
  return SearchPathW (NULL, base, L".exe", size, out, NULL) != 0;
}

static BOOL WINAPI
ignore_console_event (DWORD event)
{
  (void) event;
  return TRUE;
}

static void
die (const char *msg, const wchar_t *what)
{
  fprintf (stderr, "scriptexe: %s: %ls\n", msg, what);
  exit (127);
}

int
wmain (void)
{
  wchar_t script[MAX_PATH], interp[MAX_PATH];
  wchar_t prog[MAX_PATH] = L"", arg[MAX_PATH] = L"";
  char line[2 * MAX_PATH];
  const wchar_t *rest = skip_program_name (GetCommandLineW ());
  DWORD n = GetModuleFileNameW (NULL, script, MAX_PATH);
  wchar_t *cmd, *end;
  FILE *f;
  STARTUPINFOW si;
  PROCESS_INFORMATION pi;
  HANDLE job;
  DWORD status;

  if (n == 0 || n >= MAX_PATH || n < 4 || _wcsicmp (script + n - 4, L".exe"))
    die ("cannot find own name", L"");
  script[n - 4] = L'\0';

  f = _wfopen (script, L"rb");
  if (!f || !fgets (line, sizeof line, f) || strncmp (line, "#!", 2))
    die ("not a #! script", script);
  fclose (f);
  line[strcspn (line, "\r\n")] = '\0';

  /* "#! INTERP [ARG]": ARG is the rest of the line.  */
  {
    char *p = line + 2, *q;
    p += strspn (p, " \t");
    q = p + strcspn (p, " \t");
    if (*q)
      {
	*q++ = '\0';
	q += strspn (q, " \t");
      }
    MultiByteToWideChar (CP_UTF8, 0, p, -1, prog, MAX_PATH);
    MultiByteToWideChar (CP_UTF8, 0, q, -1, arg, MAX_PATH);
  }

  /* "#! /usr/bin/env PROG": PROG is the interpreter.  */
  {
    const wchar_t *b = wcsrchr (prog, L'/');
    if (b && !wcscmp (b + 1, L"env") && *arg)
      {
	wcscpy (prog, arg);
	*arg = L'\0';
      }
  }
  if (!resolve (prog, interp, MAX_PATH))
    die ("interpreter not found", prog);

  /* The script sees its path as $0; scripts split it at '/' to find their
     installation directory (autopoint, gettextize).  */
  for (wchar_t *p = script; *p; p++)
    if (*p == L'\\')
      *p = L'/';

  cmd = malloc ((2 * (wcslen (interp) + wcslen (arg) + wcslen (script))
		 + wcslen (rest) + 16) * sizeof (wchar_t));
  if (!cmd)
    die ("out of memory", L"");
  end = append_quoted (cmd, interp);
  if (*arg)
    {
      *end++ = L' ';
      end = append_quoted (end, arg);
    }
  *end++ = L' ';
  end = append_quoted (end, script);
  if (*rest)
    {
      *end++ = L' ';
      wcscpy (end, rest);
    }
  else
    *end = L'\0';

  /* The interpreter shares our console and handles Ctrl-C itself; we only
     have to survive until it exits, to report its status.  */
  SetConsoleCtrlHandler (ignore_console_event, TRUE);

  /* If we are killed, as by make on an interrupted build, the interpreter
     must not run on.  Its own children may break away.  */
  job = CreateJobObjectW (NULL, NULL);
  if (job)
    {
      JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits;
      memset (&limits, 0, sizeof limits);
      limits.BasicLimitInformation.LimitFlags
	= JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE | JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK;
      SetInformationJobObject (job, JobObjectExtendedLimitInformation,
			       &limits, sizeof limits);
    }

  memset (&si, 0, sizeof si);
  si.cb = sizeof si;
  if (!CreateProcessW (interp, cmd, NULL, NULL, TRUE, CREATE_SUSPENDED, NULL,
		       NULL, &si, &pi))
    die ("cannot run", interp);
  if (job)
    AssignProcessToJobObject (job, pi.hProcess);
  ResumeThread (pi.hThread);
  CloseHandle (pi.hThread);
  WaitForSingleObject (pi.hProcess, INFINITE);
  if (!GetExitCodeProcess (pi.hProcess, &status))
    status = 127;
  CloseHandle (pi.hProcess);
  return (int) status;
}
