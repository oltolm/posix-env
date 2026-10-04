/* Linked into every program (config.site): POSIX tools read and write
   bytes, as on POSIX systems.  The UCRT opens stdin, stdout and stderr in
   text mode before main, and files default to it, translating LF to CRLF
   on output and dropping CR on input; generated files and patches would
   differ from what the same tools produce elsewhere.  mingw-w64's binmode.o
   covers only the files a program opens.

   Only in the program itself: linked into a DLL, the constructor would
   switch the I/O of whatever program loads it.  */
#include <fcntl.h>
#include <io.h>
#include <stdlib.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

extern IMAGE_DOS_HEADER __ImageBase;

__attribute__ ((constructor)) static void
posix_env_binmode (void)
{
  if (GetModuleHandleW (NULL) != (HMODULE) &__ImageBase)
    return;
  _set_fmode (_O_BINARY);
  _setmode (0, _O_BINARY);
  _setmode (1, _O_BINARY);
  _setmode (2, _O_BINARY);
}
