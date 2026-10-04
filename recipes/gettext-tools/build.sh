# Options as MSYS2's mingw-w64-gettext.  libgcc and libstdc++ are linked
# statically: the toolchain's DLLs are not part of any environment.
# pass_all: libtool's file_magic check drops a static archive from a DLL's
# dependencies.  gl_cv_func_mkdir_trailing_dot_works avoids two clashing
# declarations of mkdir.
# libtextstyle uses GNU termcap, where MSYS2 uses ncurses: it has no
# terminfo functions, and the checks would otherwise take libncurses from
# the toolchain's directories.
# autopoint's archive of infrastructure files is xz-compressed, whatever
# compressors the build happens to find; tar (bsdtar) unpacks it.
./configure --prefix="$PREFIX" --enable-shared --disable-static \
  --enable-threads=windows --enable-relocatable --disable-rpath \
  --disable-java --disable-csharp --without-emacs --disable-openmp \
  --without-cvs --without-git --with-xz \
  --with-included-libcroco --with-included-libunistring \
  --with-included-libxml --with-included-glib \
  --with-libiconv-prefix="$PREFIX" --with-libtermcap-prefix="$PREFIX" \
  CC="gcc -static-libgcc" CXX="g++ -static-libgcc -static-libstdc++" \
  lt_cv_deplibs_check_method=pass_all \
  gl_cv_func_mkdir_trailing_dot_works=yes \
  gl_cv_terminfo=no gl_cv_termcap=libtermcap
# libtool links C++ libraries with -nostdlib and its own -lstdc++ and
# -lpthread, which ignores -static-libstdc++; name the static archives.
find . -name libtool -type f -exec sed -i \
  -e "/^postdeps=/s|-lstdc++|$(g++ -print-file-name=libstdc++.a)|" \
  -e "/^postdeps=/s|-lpthread|$(g++ -print-file-name=libpthread.a)|" {} +
make -j"$(nproc)"

# Only the tools part; gettext-runtime is its own package.
make -C libtextstyle install
make -C gettext-tools install
rm -f "$PREFIX/share/info/dir"

# Programs that start these #! scripts without a shell look for NAME.exe.
for script in autopoint gettextize; do
  cp "$PREFIX/libexec/posix-env/scriptexe.exe" "$PREFIX/bin/$script.exe"
done

# configure records programs of the build environment, which does not exist
# where the package is installed; name them for PATH.  Then nothing
# installed may name the build environment.
{ grep -rlF "$BUILD_PREFIX/bin/" "$PREFIX" || true; } | while IFS= read -r f; do
  sed -i "s|$BUILD_PREFIX/bin/||g" "$f"
done
if grep -rlF "$BUILD_PREFIX" "$PREFIX"; then exit 1; fi
