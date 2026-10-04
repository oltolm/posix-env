# The patches do not change the man pages; keep make from regenerating them
# with help2man.
touch man/*.1

# Programs by name, found in PATH: the build environment's paths do not
# exist where the package is installed.
./configure --prefix="$PREFIX" PERL=perl M4=m4
make -j"$(nproc)"
make install
rm -f "$PREFIX/share/info/dir"

# Programs that start these #! scripts without a shell, such as perl and
# make, look for NAME.exe.
for script in autoconf autoheader autom4te autoreconf autoscan autoupdate ifnames; do
  cp "$PREFIX/libexec/posix-env/scriptexe.exe" "$PREFIX/bin/$script.exe"
done

# configure records perl and sh as programs of the build environment, which
# does not exist where the package is installed; name them for PATH.  Then
# nothing installed may name the build environment.
grep -rlF "$BUILD_PREFIX/bin/" "$PREFIX" | while IFS= read -r f; do
  sed -i "s|$BUILD_PREFIX/bin/||g" "$f"
done
if grep -rlF "$BUILD_PREFIX" "$PREFIX"; then exit 1; fi
