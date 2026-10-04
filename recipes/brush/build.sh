cargo build --release --locked

mkdir -p "$PREFIX/bin" "$PREFIX/share/man/man1" "$PREFIX/share/doc/brush" "$PREFIX/Scripts"
cp target/release/brush.exe "$PREFIX/bin/"
cp docs/man/brush.1 "$PREFIX/share/man/man1/"
cp README.md "$PREFIX/share/doc/brush/"

# sh and bash are hard links to brush.exe, made by the post-link script.
cp "$RECIPE_DIR/post-link.bat" "$PREFIX/Scripts/.$PKG_NAME-post-link.bat"
cp "$RECIPE_DIR/pre-unlink.bat" "$PREFIX/Scripts/.$PKG_NAME-pre-unlink.bat"
