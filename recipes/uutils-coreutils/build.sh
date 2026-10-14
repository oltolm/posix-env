# One multicall coreutils.exe; it dispatches on the name it is run as.  The
# post-link script hard-links each utility name to it, the pre-unlink script
# removes those links again.
cargo build --release --locked --features windows

# Loading these DLLs made every start of coreutils.exe 3.5 ms slower (7.5 ms
# instead of 4 ms for cat, rm, mv), though only a few utilities call them.
# They are delay-loaded instead.  GNU ld has no --delayload: dlltool builds a
# delay-import library from the functions the first link imports, and -u
# makes ld take each function from it.  ld takes a symbol from the first
# library that defines it, and rustc puts -C link-arg after its own import
# libraries, so ldwrap puts these arguments in front.
delay_dlls='advapi32 bcrypt mpr user32 version ws2_32 wtsapi32'
mkdir -p delay
objdump -p target/release/coreutils.exe | tr -d '\r' | awk -v dlls=" $delay_dlls " '
  /DLL Name:/ { d = tolower($3); sub(/\.dll$/, "", d); keep = index(dlls, " " d " ") }
  keep && /^\t[0-9a-f]+ +<none> +[0-9a-f]+ +[A-Za-z_]/ { print d, $4 }' \
  | sort -u > delay/imports.txt
link_args=x86_64-w64-mingw32-gcc
for d in $delay_dlls; do
  grep "^$d " delay/imports.txt | cut -d' ' -f2 > "delay/$d.txt" || continue
  { echo "LIBRARY $d.dll"; echo EXPORTS; cat "delay/$d.txt"; } > "delay/$d.def"
  dlltool -m i386:x86-64 -d "delay/$d.def" -D "$d.dll" -y "delay/lib$d-delay.a" || exit 1
  for f in $(cat "delay/$d.txt"); do link_args="$link_args -Wl,-u,__imp_$f"; done
  link_args="$link_args $(pwd)/delay/lib$d-delay.a"
done
echo "$link_args" > delay/ldwrap.args
gcc -O2 -municode -o delay/ldwrap.exe "$RECIPE_DIR/ldwrap.c" || exit 1
cargo rustc --release --locked --features windows --bin coreutils -- \
  -C "linker=$(pwd)/delay/ldwrap.exe" || exit 1
if objdump -p target/release/coreutils.exe | tr -d '\r' \
   | grep -Ei "DLL Name: ($(echo $delay_dlls | tr ' ' '|'))\.dll\$"; then
  echo "still imported directly" >&2
  exit 1
fi

mkdir -p "$PREFIX/bin"
cp target/release/coreutils.exe "$PREFIX/bin/"

mkdir -p "$PREFIX/share/uutils-coreutils" "$PREFIX/Scripts"
target/release/coreutils.exe --list | tr -d '\r' | grep -vx coreutils \
  > "$PREFIX/share/uutils-coreutils/utilities.txt"

cp "$RECIPE_DIR/post-link.bat" "$PREFIX/Scripts/.$PKG_NAME-post-link.bat"
cp "$RECIPE_DIR/pre-unlink.bat" "$PREFIX/Scripts/.$PKG_NAME-pre-unlink.bat"
