# The MS-Windows port lives in pc/ and is built with its own Makefile
# (README_d/README.pc); configure does not handle MinGW.  That Makefile uses
# Windows VPATH syntax, so it needs a native make (ours is).
for f in pc/*; do
  case ${f##*/} in
    ChangeLog*) ;;
    *) test -d "$f" || cp -f "$f" . ;;
  esac
done
cp -f pc/Makefile.ext extension/Makefile

# DEFPATH and DEFLIBPATH are compiled in from prefix; patch 002 replaces
# them at run time with paths below gawk.exe's installation.  The
# mingw32-readline-mpfr target, spelled out to pass our own flags.  readline
# is for the debugger (gawk -D).
# posix-env's UTF-8 manifest, setlocale and binary I/O, as config.site adds
# them for configure.
make -j"$(nproc)" all prefix="$PREFIX" CC=gcc O=.o OBJ=popen.o \
  CF="-D__USE_MINGW_ANSI_STDIO -DHAVE_LIBREADLINE -DHAVE_MPFR -Wno-deprecated-declarations -I$PREFIX/include" \
  OPT=-O2 LNK=LMINGW32 \
  LF="-L$PREFIX/lib $BUILD_PREFIX/lib/posix-env/utf8-manifest.o $BUILD_PREFIX/lib/posix-env/c-locale.o $BUILD_PREFIX/lib/posix-env/binmode.o -Wl,--wrap=__imp_setlocale -Wl,--wrap=__imp__wsetlocale" \
  LF2="-lmpfr -lgmp -lreadline -lws2_32" RSP=

mkdir -p "$PREFIX/bin" "$PREFIX/include" "$PREFIX/lib/awk" \
  "$PREFIX/share/man/man1" "$PREFIX/share/info"
cp gawk.exe "$PREFIX/bin/gawk.exe"
cp gawk.exe "$PREFIX/bin/awk.exe"
cp gawkapi.h "$PREFIX/include/"
cp -r awklib/eg/lib/* "$PREFIX/lib/awk/"
cp doc/*.1 "$PREFIX/share/man/man1/"
cp doc/*.info "$PREFIX/share/info/"
