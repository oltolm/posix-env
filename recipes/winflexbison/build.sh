# mingw-compat.h supplies what the MSVC build gets from MSVC itself.
export CFLAGS="-O2 -D_GNU_SOURCE -include $RECIPE_DIR/mingw-compat.h -Wno-error=incompatible-pointer-types"
# posix-env's UTF-8 manifest, setlocale and binary I/O (generated scanners
# and parsers get LF line endings), as config.site adds them for configure.
pe="$BUILD_PREFIX/lib/posix-env"
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_EXE_LINKER_FLAGS="$pe/utf8-manifest.o $pe/c-locale.o $pe/binmode.o -Wl,--wrap=__imp_setlocale -Wl,--wrap=__imp__wsetlocale"
cmake --build build

# The programs land in the source tree's bin/Release, with bison's data
# directory, which win_bison looks for next to its executable.
cd bin/Release
mkdir -p "$PREFIX/bin"
cp win_bison.exe "$PREFIX/bin/bison.exe"
cp win_flex.exe "$PREFIX/bin/flex.exe"
# Invoked as lex, flex behaves as POSIX lex.
cp win_flex.exe "$PREFIX/bin/lex.exe"
cp -r data "$PREFIX/bin/data"

# make runs simple recipe lines without a shell, so yacc needs an .exe.
printf '#! /bin/sh\nexec bison -y "$@"\n' > "$PREFIX/bin/yacc"
cp "$PREFIX/libexec/posix-env/scriptexe.exe" "$PREFIX/bin/yacc.exe"
