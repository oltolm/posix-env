/* Linker wrapper: runs the command line in ldwrap.args (next to this
   program) followed by this program's own arguments, quoted as given.
   rustc puts -C link-arg after its own import libraries; this puts
   arguments in front of them.  */
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

int wmain (void)
{
  static wchar_t prefix[32768], cmd[65536];
  wchar_t path[MAX_PATH];
  DWORD n = GetModuleFileNameW (NULL, path, MAX_PATH);
  if (n == 0 || n >= MAX_PATH - 5)
    return 127;
  wcscpy (wcsrchr (path, L'.'), L".args");
  FILE *f = _wfopen (path, L"r");
  if (!f || !fgetws (prefix, 32768, f))
    {
      fwprintf (stderr, L"ldwrap: cannot read %ls\n", path);
      return 127;
    }
  fclose (f);
  prefix[wcscspn (prefix, L"\r\n")] = 0;

  /* Skip argv[0] as the CRT does: up to the next unquoted blank.  */
  const wchar_t *p = GetCommandLineW ();
  int quoted = 0;
  for (; *p && (quoted || (*p != L' ' && *p != L'\t')); p++)
    if (*p == L'"')
      quoted = !quoted;

  _snwprintf (cmd, sizeof cmd / sizeof *cmd - 1, L"%ls%ls", prefix, p);
  STARTUPINFOW si = { sizeof si };
  PROCESS_INFORMATION pi;
  if (!CreateProcessW (NULL, cmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi))
    {
      fwprintf (stderr, L"ldwrap: cannot run %ls: error %lu\n", prefix,
		GetLastError ());
      return 127;
    }
  DWORD status;
  WaitForSingleObject (pi.hProcess, INFINITE);
  GetExitCodeProcess (pi.hProcess, &status);
  return status;
}
