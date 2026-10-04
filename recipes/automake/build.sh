# brush lacks aliases named like builtins, which only automake's own
# testsuite needs; skip its search for a better shell.
./configure --prefix="$PREFIX" PERL=perl AM_TEST_RUNNER_SHELL="$SHELL"
make -j"$(nproc)"
make install
rm -f "$PREFIX/share/info/dir"

# Programs that start these #! scripts without a shell, such as perl and
# make, look for NAME.exe.
for script in aclocal-${PKG_VERSION%.*} automake-${PKG_VERSION%.*} aclocal automake; do
  cp "$PREFIX/libexec/posix-env/scriptexe.exe" "$PREFIX/bin/$script.exe"
done

# configure records perl and sh as programs of the build environment, which
# does not exist where the package is installed; name them for PATH.  Then
# nothing installed may name the build environment.
grep -rlF "$BUILD_PREFIX/bin/" "$PREFIX" | while IFS= read -r f; do
  sed -i "s|$BUILD_PREFIX/bin/||g" "$f"
done
if grep -rlF "$BUILD_PREFIX" "$PREFIX"; then exit 1; fi
