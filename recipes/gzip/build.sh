# GNU_STANDARD=0: gzip acts by its name (gunzip, zcat, uncompress), so
# that those are copies of gzip.exe rather than the shell scripts gzip
# installs for them; they then work without sh.  libgcc is linked
# statically: the toolchain's DLLs are not part of any environment.
./configure --prefix="$PREFIX" CC="gcc -static-libgcc" CFLAGS="-O2 -DGNU_STANDARD=0"
make -j"$(nproc)"
make install
rm -f "$PREFIX/share/info/dir"
for name in gunzip zcat uncompress; do
  rm -f "$PREFIX/bin/$name"
  cp "$PREFIX/bin/gzip.exe" "$PREFIX/bin/$name.exe"
done

# The other programs are shell scripts.  The build put the build
# environment's sh in place of /bin/sh throughout them, and its grep into
# zgrep: back to /bin/sh (scriptexe finds sh in PATH), and the other
# programs by name.  Programs that start the scripts without a shell look
# for NAME.exe.
for script in "$PREFIX"/bin/*; do
  case $script in *.exe | *.dll) continue ;; esac
  test "$(head -c 2 "$script")" = '#!' || continue
  sed -i -e "s|$BUILD_PREFIX/bin/sh.exe|/bin/sh|g" -e "s|$BUILD_PREFIX/bin/||g" "$script"
  cp "$PREFIX/libexec/posix-env/scriptexe.exe" "$script.exe"
done

# Nothing installed may name the build environment.
if grep -rlF "$BUILD_PREFIX" "$PREFIX/bin" "$PREFIX/share"; then exit 1; fi
