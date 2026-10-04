# zstd's own makefiles; MSYS2 uses its CMake build, which needs CMake.
# Their install targets know Windows only as MSYS or Cygwin, so the files
# are copied below.  The flags go in the environment: on the command line
# they would replace the makefiles' own additions.  libgcc is linked
# statically: the toolchain's DLLs are not part of any environment.  The
# zstd program has the library compiled in, as with MSYS2.
# posix-env's UTF-8 manifest and binary I/O, as config.site adds them.
export CPPFLAGS="-I$PREFIX/include" \
  LDFLAGS="-L$PREFIX/lib -static-libgcc -Wl,$BUILD_PREFIX/lib/posix-env/utf8-manifest.o -Wl,$BUILD_PREFIX/lib/posix-env/binmode.o"
# The makefiles detect Windows by OS, which rattler-build does not pass on,
# and take BUILD_DIR, which rattler-build sets, as their object directory.
export OS=Windows_NT
unset BUILD_DIR
make -j"$(nproc)" -C lib libzstd
# The rule for libzstd.pc, too, exists only for MSYS and Cygwin.  Windows
# threads need no flags.
sed -e "s|@PREFIX@|$PREFIX|" -e 's|@EXEC_PREFIX@|${prefix}|' \
  -e 's|@INCLUDEDIR@|${prefix}/include|' -e 's|@LIBDIR@|${exec_prefix}/lib|' \
  -e "s|@VERSION@|$PKG_VERSION|" -e 's|@LIBS_MT@||' -e 's|@LIBS_PRIVATE@||' \
  lib/libzstd.pc.in > lib/libzstd.pc
make -j"$(nproc)" -C programs zstd-release

mkdir -p "$PREFIX/bin" "$PREFIX/lib/pkgconfig" "$PREFIX/include" "$PREFIX/share/man/man1"
cp lib/dll/libzstd.dll "$PREFIX/bin/"
cp lib/dll/libzstd.dll.a "$PREFIX/lib/"
cp lib/libzstd.pc "$PREFIX/lib/pkgconfig/"
cp lib/zstd.h lib/zdict.h lib/zstd_errors.h "$PREFIX/include/"
for name in zstd zstdcat unzstd zstdmt; do
  cp programs/zstd.exe "$PREFIX/bin/$name.exe"
done
cp programs/zstdgrep programs/zstdless "$PREFIX/bin/"
cp programs/zstd.1 programs/zstdgrep.1 programs/zstdless.1 "$PREFIX/share/man/man1/"
cp programs/zstd.1 "$PREFIX/share/man/man1/zstdcat.1"
cp programs/zstd.1 "$PREFIX/share/man/man1/unzstd.1"

# Programs that start these #! scripts without a shell look for NAME.exe.
for script in zstdgrep zstdless; do
  cp "$PREFIX/libexec/posix-env/scriptexe.exe" "$PREFIX/bin/$script.exe"
done
