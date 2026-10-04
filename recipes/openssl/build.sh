# Configure options as MSYS2's mingw-w64-openssl.  OPENSSLBIN is what the
# relocation patch resolves the other directories against.  libgcc is linked
# statically: the toolchain's DLLs are not part of any environment.
perl Configure \
  --prefix="$PREFIX" \
  --libdir=lib \
  --openssldir=etc/ssl \
  --with-zlib-include="$PREFIX/include" \
  mingw64 \
  shared \
  zlib-dynamic \
  enable-camellia \
  enable-capieng \
  enable-idea \
  enable-mdc2 \
  enable-rc5 \
  enable-rfc3779 \
  -static-libgcc \
  -DOPENSSLBIN=\"\\\"$PREFIX/bin\\\"\"

make -j"$(nproc)"
# install is not safe in parallel.
make install
