# The patches change configure.ac.
autoreconf -fi
# Features as MSYS2's mingw-w64-libarchive, except crypto from OpenSSL,
# which is not packaged yet; Windows CNG still provides it for zip and
# 7-zip.  libgcc is linked statically: the toolchain's DLLs are not part of
# any environment.
# bsdtar and bsdunzip embed their own manifests (UTF-8 active code page by
# patches 0006 and 0009), so config.site must not add one; bsdcat and
# bsdcpio get posix-env's below.
posix_env_manifest=no \
./configure --prefix="$PREFIX" --enable-shared --disable-static \
  --enable-bsdtar=shared --enable-bsdcpio=shared --enable-bsdcat=shared \
  --enable-bsdunzip=shared --enable-posix-regex-lib=libpcre2posix \
  --with-zlib --with-bz2lib --with-libb2 --with-lzma --with-lz4 --with-zstd \
  --with-iconv --with-libiconv-prefix="$PREFIX" --with-cng --with-expat \
  --without-xml2 --without-openssl --without-nettle --without-mbedtls \
  --without-lzo2 \
  CC="gcc -static-libgcc" CPPFLAGS="-I$PREFIX/include" LDFLAGS="-L$PREFIX/lib" \
  lt_cv_deplibs_check_method=pass_all
manifest="$BUILD_PREFIX/lib/posix-env/utf8-manifest.o"
make -j"$(nproc)" \
  bsdcat_LDFLAGS="\$(bsdcat_ldstatic) \$(DEAD_CODE_REMOVAL) -Wl,$manifest" \
  bsdcpio_LDFLAGS="\$(bsdcpio_ldstatic) \$(DEAD_CODE_REMOVAL) -Wl,$manifest"
make install

# The usual names, as in MSYS2's package.
cp "$PREFIX/bin/bsdtar.exe" "$PREFIX/bin/tar.exe"
cp "$PREFIX/bin/bsdunzip.exe" "$PREFIX/bin/unzip.exe"
