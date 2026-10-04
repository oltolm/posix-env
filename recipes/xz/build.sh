# Options as MSYS2's mingw-w64-xz, without its regenerated documentation.
# libgcc is linked statically: the toolchain's DLLs are not part of any
# environment.  gnulib's shell probe accepts only /... paths; the result is
# just the #! line of xzgrep and friends, which scriptexe resolves on PATH.
./configure --prefix="$PREFIX" --enable-shared --disable-static \
  --disable-rpath --disable-lzma-links --disable-doc \
  --with-libiconv-prefix="$PREFIX" --with-libintl-prefix="$PREFIX" \
  CC="gcc -static-libgcc" gl_cv_posix_shell=/bin/sh
make -j"$(nproc)"
make install

# install makes symlinks (unxz, xzcat, xzcmp, ... and their man pages),
# which packages cannot hold; copy the targets instead.
find "$PREFIX/bin" "$PREFIX/share/man" -type l | while IFS= read -r link; do
  target=$(readlink -f "$link")
  rm "$link"
  cp "$target" "$link"
done

# Programs that start these #! scripts without a shell look for NAME.exe.
for script in xzdiff xzcmp xzgrep xzegrep xzfgrep xzless xzmore; do
  cp "$PREFIX/libexec/posix-env/scriptexe.exe" "$PREFIX/bin/$script.exe"
done
