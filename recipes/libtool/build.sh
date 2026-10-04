# Patch 0014 changes m4/libtool.m4; keep make from re-running aclocal,
# autoconf and automake on libtool itself: mark the generated files current,
# in dependency order.
touch aclocal.m4 libltdl/aclocal.m4
touch configure libltdl/configure config-h.in libltdl/config-h.in
touch Makefile.in libltdl/Makefile.in

./configure --prefix="$PREFIX" --enable-shared --disable-static
# The patches change ltmain.in, which the man pages depend on; regenerating
# them needs help2man.  The help text is unchanged: keep the shipped ones.
make -j"$(nproc)" HELP2MAN=:
make install HELP2MAN=:
rm -f "$PREFIX/share/info/dir"

# Programs that start these #! scripts without a shell, such as perl and
# make, look for NAME.exe.
for script in libtool libtoolize; do
  cp "$PREFIX/libexec/posix-env/scriptexe.exe" "$PREFIX/bin/$script.exe"
done

# configure records sed, grep and the like as programs of the build
# environment, which does not exist where the package is installed; name
# them for PATH.  Then nothing installed may name the build environment.
grep -rlF "$BUILD_PREFIX/bin/" "$PREFIX" | while IFS= read -r f; do
  sed -i "s|$BUILD_PREFIX/bin/||g" "$f"
done
if grep -rlF "$BUILD_PREFIX" "$PREFIX"; then exit 1; fi
