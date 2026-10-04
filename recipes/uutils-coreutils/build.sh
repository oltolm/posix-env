# One multicall coreutils.exe; it dispatches on the name it is run as.  The
# post-link script hard-links each utility name to it, the pre-unlink script
# removes those links again.
cargo build --release --locked --features windows

mkdir -p "$PREFIX/bin"
cp target/release/coreutils.exe "$PREFIX/bin/"

mkdir -p "$PREFIX/share/uutils-coreutils" "$PREFIX/Scripts"
target/release/coreutils.exe --list | tr -d '\r' | grep -vx coreutils \
  > "$PREFIX/share/uutils-coreutils/utilities.txt"

cp "$RECIPE_DIR/post-link.bat" "$PREFIX/Scripts/.$PKG_NAME-post-link.bat"
cp "$RECIPE_DIR/pre-unlink.bat" "$PREFIX/Scripts/.$PKG_NAME-pre-unlink.bat"
