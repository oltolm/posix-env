# Configure options as MSYS2's mingw-w64-openssl.  OpenSSL 4 requires a Perl
# that emits POSIX paths, so use the MSYS Perl beside the external UCRT64
# toolchain.  The relocation patch resolves directories relative to libcrypto.
# libgcc is linked statically.
toolchain_bin=$(dirname "$(command -v gcc)")
msys2_root=$(dirname "$(dirname "$toolchain_bin")")
PERL="$msys2_root/usr/bin/perl.exe" \
  "$msys2_root/usr/bin/perl.exe" Configure \
  --prefix="$PREFIX" \
  --libdir=lib \
  --openssldir=etc/ssl \
  --with-zlib-include="$PREFIX/include" \
  mingw64 \
  shared \
  no-asm \
  zlib-dynamic \
  enable-camellia \
  enable-idea \
  enable-mdc2 \
  enable-rc5 \
  enable-rfc3779 \
  -static-libgcc

make -j"$(nproc)" build_sw
# Installation is not safe in parallel; documentation is not packaged.
make install_sw install_ssldirs
