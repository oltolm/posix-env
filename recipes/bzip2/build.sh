# The autoconf build system from MSYS2's patches; its aclocal.m4 is
# hand-written, so only autoconf runs.  libgcc is linked statically: the
# toolchain's DLLs are not part of any environment.
autoconf
./configure --prefix="$PREFIX" --enable-shared LDFLAGS=-static-libgcc
make -j"$(nproc)" all-dll-shared
make -j"$(nproc)"
make install
# Shared only, like the other libraries.
rm "$PREFIX/lib/libbz2.a"

# install may make symlinks (bzegrep, bzless, ...), which packages cannot
# hold; copy the targets instead.
find "$PREFIX/bin" -type l | while IFS= read -r link; do
  target=$(readlink -f "$link")
  rm "$link"
  cp "$target" "$link"
done

# Programs that start these #! scripts without a shell look for NAME.exe.
for script in bzgrep bzegrep bzfgrep bzmore bzless bzdiff bzcmp; do
  cp "$PREFIX/libexec/posix-env/scriptexe.exe" "$PREFIX/bin/$script.exe"
done
