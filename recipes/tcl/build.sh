# Tcl's own Windows build (win/), out of tree.  tclsh embeds its own
# manifest (UTF-8 active code page by patch 0006), so config.site must not
# add one.  --with-encoding: the encoding of the compiled-in paths.
mkdir build
cd build
posix_env_manifest=no \
"$SRC_DIR/win/configure" --prefix="$PREFIX" --enable-64bit --enable-threads \
  --with-encoding=utf-8

# Link the zlib package instead of the prebuilt zlib1.dll that Tcl bundles
# (the same DLL name, which the zlib package provides).
sed -i \
  -e 's|^ZLIB_DLL_FILE[	 ]*=.*|ZLIB_DLL_FILE =|' \
  -e "s|\$(shell \$(CYGPATH) '\${ZLIB_DIR_NATIVE}/win64/libz.dll.a')|-L$PREFIX/lib -lz|" \
  -e 's|-I"${ZLIB_DIR_NATIVE}"|-I"'"$PREFIX"'/include"|g' \
  -e '/^\${ZLIB_DLL_FILE}:/,/^$/d' \
  Makefile
grep -q -- "-lz" Makefile

# The bundled extensions in pkgs/ (thread, itcl, tdbc, sqlite) are not
# built: their TEA configures produce broken link commands here, and
# DejaGnu needs none of them.
make -j"$(nproc)" binaries libraries
make install-binaries install-libraries install-headers
cp "$PREFIX/bin/tclsh86.exe" "$PREFIX/bin/tclsh.exe"
# Import and stub libraries under the usual names too.
cp "$PREFIX/lib/libtcl86.dll.a" "$PREFIX/lib/libtcl.dll.a"
