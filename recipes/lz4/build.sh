# lz4's own makefiles, as MSYS2's mingw-w64-lz4.  TARGET_OS names the
# platform that uname would report there; POSIX_ENV enables install.
# The environment has no install program.
# libgcc is linked statically: the toolchain's DLLs are not part of any
# environment.  The lz4 program has the library compiled in.
# posix-env's UTF-8 manifest and binary I/O, as config.site adds them.
opts=(TARGET_OS=MINGW64 POSIX_ENV=Yes BUILD_STATIC=no PREFIX="$PREFIX"
      CC=gcc LDFLAGS="-static-libgcc -Wl,$BUILD_PREFIX/lib/posix-env/utf8-manifest.o -Wl,$BUILD_PREFIX/lib/posix-env/binmode.o"
      MAKE_DIR="mkdir -p" INSTALL_PROGRAM=cp INSTALL_DATA=cp)
make -j"$(nproc)" -C lib "${opts[@]}"
make -j"$(nproc)" -C programs "${opts[@]}" lz4
make -C lib "${opts[@]}" install
make -C programs "${opts[@]}" install

# install makes symlinks (lz4c, lz4cat, unlz4 and their man pages), which
# packages cannot hold; copy the targets instead.
find "$PREFIX/bin" "$PREFIX/share/man" -type l | while IFS= read -r link; do
  target=$(readlink -f "$link")
  rm "$link"
  cp "$target" "$link"
done
