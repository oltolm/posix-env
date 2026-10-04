/* perlsh: a PERL5SHELL for Win32 perl that runs commands with sh.exe from
   the same directory.

   Win32 perl hands a command to its shell the way cmd.exe expects it: it
   appends the command to the shell's command line, wrapped in double quotes
   only if the command has whitespace and no '"' of its own.  sh would split
   such a line into several arguments, so take the raw text after our own
   name, undo the wrapping, and pass it to sh as one -c argument.

   A command that is exactly one double-quoted word with no other '"' looks
   the same as a wrapped command and loses its quotes.

     PERL5SHELL=C:/nativetools/bin/perlsh.exe  */
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <windows.h>

/* Return the text after the first token of the command line CMDLINE, which
   is split the way the C runtime splits argv[0], and after the one space
   perl puts between the shell and the command.  */
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
  if (*p == L' ' || *p == L'\t')
    p++;
  return p;
}

/* Append ARG to OUT as one argument for the C runtime's argv splitting:
   double quotes around it, '"' escaped, and backslashes doubled where they
   precede a '"'.  */
static wchar_t *
append_quoted (wchar_t *out, const wchar_t *arg, size_t len)
{
  *out++ = L'"';
  for (size_t i = 0; i < len;)
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

int
wmain (void)
{
  const wchar_t *cmd = skip_program_name (GetCommandLineW ());
  size_t len = wcslen (cmd);
  wchar_t sh[MAX_PATH + 8];
  DWORD n = GetModuleFileNameW (NULL, sh, MAX_PATH);
  wchar_t *base, *line, *end;
  STARTUPINFOW si;
  PROCESS_INFORMATION pi;
  DWORD status;

  if (len >= 2 && cmd[0] == L'"' && cmd[len - 1] == L'"'
      && !wmemchr (cmd + 1, L'"', len - 2))
    cmd++, len -= 2;

  if (n == 0 || n >= MAX_PATH)
    return 127;
  base = wcsrchr (sh, L'\\');
  if (!base || (wcsrchr (sh, L'/') && wcsrchr (sh, L'/') > base))
    base = wcsrchr (sh, L'/');
  wcscpy (base ? base + 1 : sh, L"sh.exe");

  /* Each character needs at most two, plus quotes, "-c" and spaces.  */
  line = malloc ((wcslen (sh) + 2 * len + 16) * sizeof (wchar_t));
  if (!line)
    return 127;
  end = append_quoted (line, sh, wcslen (sh));
  wcscpy (end, L" -c ");
  end = append_quoted (end + 4, cmd, len);
  *end = L'\0';

  memset (&si, 0, sizeof si);
  si.cb = sizeof si;
  if (!CreateProcessW (sh, line, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi))
    return 127;
  CloseHandle (pi.hThread);
  WaitForSingleObject (pi.hProcess, INFINITE);
  if (!GetExitCodeProcess (pi.hProcess, &status))
    status = 127;
  CloseHandle (pi.hProcess);
  return (int) status;
}
