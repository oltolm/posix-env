# TODO

## Locale
* [x] Decided (2026-10-04): every C/C++ program gets a UTF-8 active-code-page manifest, and `setlocale` behaves as on POSIX: `""` reads `LC_ALL`, `LC_<CATEGORY>`, `LANG` and falls back to `"C"` (not the Windows locale); `"POSIX"` is mapped to `"C"` and `"C.UTF-8"` to C with UTF-8 characters (UCRT `".UTF-8"` for `LC_CTYPE`), the two names the UCRT rejects; other names go to the UCRT unchanged (it accepts `de_DE.UTF-8`). Activation sets `LANG=C.UTF-8` when no locale is set and switches the console to code page 65001. (Routing through libintl's/gnulib's `setlocale` was tried and dropped: its locale names broke perl and gawk, and libintl's exports leaked into configure checks.)
* [x] Implementation: posix-env ships `lib/posix-env/utf8-manifest.o` (mingw-w64's default manifest plus `activeCodePage`) and `lib/posix-env/c-locale.o` (`-Wl,--wrap=__imp_setlocale`/`__imp__wsetlocale`, linked as an object with `-lmsvcrt` after it, `--exclude-symbols` for DLLs); config.site adds both to LDFLAGS (`posix_env_manifest=no` opts out of the manifest). Hand-wired: lz4, zstd, gawk, winflexbison, perl (own manifest, patch 018; Config stripped of the wrap), libarchive (own manifests for bsdtar/bsdunzip, patch 0009). gawk patch 003: UTF-8 codeset names, NULL dereference in `mbrlenc32`. perl patch 019: `C`, not `".ACP"`, without locale variables. All packages rebuilt and checked.
* [x] perl patch 021: `perlglob.exe` linked with posix-env's `utf8-manifest.o` (`PERLGLOB_RES` from build.bat); it printed wildcard matches in code page 1252. Test globs a UTF-8 file name.
* [x] Binary I/O for all C programs: posix-env ships `lib/posix-env/binmode.o` (constructor: `_fmode`, stdin/stdout/stderr binary; only in the exe, not when linked into a DLL), config.site links it (with `-lmsvcrt,-lkernel32` after it); hand-wired in gawk, winflexbison, lz4, zstd (their own `binmode-std.c` is gone). All C packages rebuilt and tested.
* [x] perl patch 020: default PerlIO layer `:perlio` instead of `:crlf` (binary I/O like the other tools; `binmode(FH, ":crlf")` still available).
* [x] Locale names other than the C ones are not overridden (the user's choice); builds set `LC_ALL=C` anyway. The external gcc/cc1 keep the UCRT's default until the toolchain is ours.
* [x] Rust tools (uutils, brush) need no manifest (std uses the wide APIs and `WriteConsoleW`). Checked 2026-10-05: coreutils' `sort`, `ls`, number and date formatting read `LC_ALL`/`LC_<CATEGORY>`/`LANG` themselves (ICU4X); without any of them the Windows build falls back to the UI language, not `C` (activation sets `LANG`). Messages read `LANG` only, English only embedded. sed reads `LC_ALL`/`LC_CTYPE`/`LANG` for byte vs UTF-8 mode (default `C`); grep, findutils, brush ignore the locale.
* [x] uutils patch 0002 (`C:\src\uutils-coreutils` `windows-native` e799c6bb8): `dd conv=lcase/ucase` called `setlocale(LC_CTYPE, "")` (the only `setlocale` on Windows; `date`'s and `sort`'s are Unix-only), which the UCRT takes as the Windows locale; with code page 1252 it case-mapped UTF-8 lead bytes (`É` became `0xE3 0x89`). Now no `setlocale` on Windows: ASCII only, as glibc in a UTF-8 locale. Unit test plus recipe test.

## UTF-8 by default, binary I/O, locale

* [x] gawk
* [x] make
* [x] flex, bison
* [x] m4
* [x] perl
* [ ] binutils
* [x] diffutils
* [x] GNU gzip
* [ ] GCC

## Missing tools

- [x] GNU gzip 1.15: built with `GNU_STANDARD=0`, so `gunzip`, `zcat`, `uncompress` are copies of `gzip.exe` (no sh needed); `zgrep` etc. via scriptexe, build-env paths rewritten.
- [x] GNU patch 2.8: patch 0001 (gnulib backupfile calls `rewinddir` on its own `DIR` wrapper; still in gnulib master, report upstream), 0002 (native Windows: getrlimit, `S_IFLNK`, owners/groups, SIGHUP/SIGCHLD).
- [x] `unzstd`, `zstdcat` (and `zstdmt`) in the zstd package: copies of `zstd.exe`, tested.
- [ ] Port the real flex release (native MinGW, gnulib where needed), replacing winflexbison's `flex`/`lex`.
- [ ] Port the real GNU bison release (native MinGW, gnulib where needed), replacing winflexbison's `bison`/`yacc`.

## posix-env packaging (conda format, no MSYS)

Own `.conda` packages built with rattler-build and installed with micromamba,
in a local channel only; no package from any conda channel. The toolchain
(gcc, binutils, mingw-w64) stays external. Flat prefix (`bin`, `lib`,
`share`). Work lives in `C:\src\posix-env` (`build.cmd RECIPE...`).

- [x] rattler-build runs `build.sh` with `interpreter: brush` from the build env.
- [x] Bootstrap package `posix-env 0.0.0 bootstrap`, seeded from the MSYS2-installed tools.
- [x] Activation script: forward-slash paths, `CONFIG_SHELL`, `CONFIG_SITE`, `PATH_SEPARATOR`, `PERL5SHELL`.
- [x] `tools\prefill.ps1` fills rattler-build's source cache from `C:\src\source-packages`, `C:\src\MINGW-packages` and the git repos in `C:\src`.
- [x] `tools\prefill.ps1` also extracts archives into `<key>_extracted` (rattler-build otherwise copies the archive itself into the work directory).
- [x] Release sources only, no git snapshots (brush excepted until a newer release; see below).
- [x] uutils-coreutils 0.12.0: one `coreutils.exe` plus `share\uutils-coreutils\utilities.txt`; post-link `.bat` hard-links each name, pre-unlink `.bat` deletes them. Add `--features openssl` once openssl is packaged (it only speeds up md5/sha digests).
- [x] scriptexe 0.1.0 (`libexec\posix-env\scriptexe.exe`).
- [x] winflexbison 2.5.25 release plus a backport of upstream a243a1c (CMake without MSVC); `yacc` needs `sh` at run time.
- [x] gmp 6.3.0 (shared only; `CC="gcc -std=gnu17"`, GCC 16's C23 default breaks its configure probes) and mpfr 4.2.2.
- [x] gawk 5.4.1 with the pc/ port and MPFR. The pc/ Makefile also has readline targets: add readline once it is packaged.
- [x] brush snapshot with patches 0001-0021 from `C:\src\brush` `windows-native` (0021: libtool's `cmd //c` path conversion); `sh`/`bash` hard links via link scripts.
- [x] uutils-sed 0.2.0 (5 patches), uutils-grep 0.2.0, uutils-findutils 0.10.0 (find, xargs); grep and findutils link the packaged oniguruma through pkg-config.
- [x] pkgconf 3.0.7 (release tarball's configure, no meson), oniguruma 6.9.10, gperf 3.3.
- [x] libiconv 1.19 with the CP65001 alias (tables regenerated with gperf); no NLS, since gettext-runtime needs libiconv in `host:`.
- [x] gettext-runtime 1.0 (libintl, libasprintf, gettext/ngettext/envsubst); MSYS2's libasprintf patch is obsolete in 1.0.
- [x] make 4.4.1 with NLS. MSYS2's linebuf patch disables `setlocale` on MinGW, which conflicts with honoring `LC_*` below.
- [x] m4 1.4.21 and the real `posix-env 0.1.0` (which, chmod, perlsh, config.site without the libtool lines, activation); builds now use it instead of the bootstrap.
- [x] GNU sources come from `https://ftpmirror.gnu.org/gnu/`.
- [ ] Maybe later: `configure -C` in recipes, so that nested configures (gettext) reuse their parent's results.
- [x] termcap 1.3.1 (compiled directly, `-std=gnu17`; its Autoconf 1 configure would need regenerating) and readline 8.3.003 (official patches 001-003 and MSYS2's 4, as unified diffs). gawk uses readline for its debugger.
- [x] Compiled-in prefix paths: conda relocates text files only on Windows. gawk (AWKPATH/AWKLIBPATH), make and m4 (LOCALEDIR) now compute them from the exe location (one small patch each, with tests: `gawk -i join`, German messages); perl rewrites doubled-backslash prefixes in Config.pm/config.h at build time.
- [x] perl 5.44.0 (MSYS2's 17 patches incl. 3 upstream PRs, regenerated; built under cmd.exe with mingw32-make, fully static runtime).
- [x] zlib 1.3.2 (win32/Makefile.gcc; minizip not packaged).
- [ ] Blocked: openssl 3.6.5 (`recipes\openssl`, with MSYS2's relocation patch and arch suffix). Its MinGW Configure requires a perl with Unix paths ("This perl implementation doesn't produce Unix like paths"); native Win32 perl's File::Spec gives backslashes, and the generated Makefile is run by sh. Needs OpenSSL's MinGW build made to work with a native perl. Users: uutils coreutils `--features openssl` (faster md5/sha), libarchive (MSYS2 enables it; ours has CNG only).
- [x] perl warned "Setting locale failed" with LC_ALL=C.UTF-8 and pcre2grep failed; both fixed by the locale work (`c-locale.o`, perl's test checks for no warning, pcre2's test no longer clears LC_ALL).
- [ ] The external toolchain's own include and lib directories (`C:\msys64\ucrt64`) can leak MSYS2 libraries into builds; a dependency missing from `host:` goes unnoticed (gettext-tools' libtextstyle found libncurses there; it now pins termcap). Its `bin` also puts MSYS2's tools on PATH: configure finds `perl`, `msgfmt`, `xgettext`, `texi2pdf`, `xz` there, and gettext-runtime's build runs `help2man` with MSYS2's perl. A toolchain directory with only gcc/binutils would avoid both.
- [x] Toolchain runtime DLLs are linked statically for now (`-static-libgcc`; gmp's C++ library also gets libtool's `-lstdc++`/`-lpthread` replaced by the static archives, with `lt_cv_deplibs_check_method=pass_all`). No package imports a DLL from the toolchain.
- [x] uutils-sed: backport of upstream e40667f; 0.2.0 took `sed -i SCRIPT FILE`'s SCRIPT as the backup suffix.
- [x] Rebuild every package with the real packages instead of the bootstrap (all pass; every binary's imports resolve in the env or System32). gperf is linked fully statically, gettext-runtime's libasprintf (C++) like gmp's libgmpxx.
- [x] Removed (2026-10-05) the bootstrap recipe, both bootstrap packages and the superseded builds in `output\win-64` (37 current builds left); `repodata.json` is rewritten by the next build.
- [x] autoconf 2.73 (branch patches 001, 003, 004; 002 and relocate.pl replaced by conda relocation) and automake 1.18.1. configure records perl and sh from the build env; the build scripts strip those paths and fail if anything installed still names the build env. Test: autoreconf -i, configure, make on a small project.
- [x] libtool 2.6.2 (MSYS2's patches except 0007-msysize; plus 0015: PROG.exe in extract-trace's and inline-source's program searches, and inline-source recursing through sh because env cannot start a #! script). Test: a DLL through LT_INIT with libtoolize, autoreconf, configure, make.
- [x] brush patch 0022: command substitution keeps output that is not UTF-8 (lossy) instead of failing; libtool's `m4 --version` check hit it.
- [x] Compression libraries, all with tests: xz 5.8.4 (liblzma, NLS; xzgrep etc. via scriptexe), lz4 1.10.0 and zstd 1.5.7 (own makefiles, no CMake; zstd reads/writes .gz/.xz/.lz4), bzip2 1.0.8 (MSYS2's 3 patches, autoconf build, `--show-progress`), expat 2.8.5, pcre2 10.49 (JIT, 8/16/32, pcre2test with readline, pcre2grep with zlib/bzip2), libb2 0.98.1 (4 upstream commits; `--enable-fat`, MSYS2's default `-march=native` ties it to the build CPU). install's symlinks become copies (packages cannot hold symlinks); no `install` program in the env, so lz4 gets `MAKE_DIR="mkdir -p"` and `cp`.
- [x] libarchive 3.8.9 via autotools: bsdtar/bsdcpio/bsdcat/bsdunzip shared, `tar.exe`/`unzip.exe` copies, every packaged library, CNG, expat for xar, pcre2posix for `-s`. Patches: MSYS2's 3 unzip merges, e048b3b8 (multithreaded xz decoding), a53d87cd, 8d9a1564, plus 0007 (quote `PLATFORMCPPFLAGS`, which configure ran as a command) and 0008 (build bsdunzip on MinGW, check for `direct.h`).
- [x] m4 patch 0002: stdout, stderr and `--debugfile` in binary mode; CRLF traces made libtoolize read `AC_CONFIG_AUX_DIR([build/autoconf])` as `build/autoconf])`. Test counts bytes.
- [x] autoconf 005: close files after reading (autoheader and autoreconf kept `config.h.in` open as perl's last-read handle; Win32 cannot replace it: "cannot backup config.h.in: Permission denied"); 006: report exit statuses on Win32 perl, which has no `POSIX::WIFEXITED`.
- [x] automake 0001: forward slashes in paths written to Makefile.in/aclocal.m4 (Win32 `File::Spec` gave `tar\$(DEPDIR)/$(am__dirstamp)` and `m4_include([build\autoconf/...])`); aclocal compares autom4te's Win32-form traced file names with forward slashes. Test: subdir-objects and an m4 macro dir.
- [x] scriptexe 0.1.0 build 2 passes the script path with `/` (autopoint split `$0` at `/` and printed "cd: not a directory").
- [x] Rebuild the other packages that copy scriptexe.exe so they get build 2 (done with the locale rebuild).
- [ ] Configure speed (profile of m4's configure, 113 s): gcc 44 % (79 ms per compile+link; external toolchain), uutils `rm`/`cat`/`mv` 27 % (10 ms each, 3.4 ms above the 6.8 ms process floor; the 13 MB multicall `coreutils.exe` or uucore's startup work: a single-utility build would tell), config.status 17 % (not traced inside), brush < 3 %. No preseeding, no lld.
- [x] automake 0002: the same exit-status fix as autoconf's 006, in `Automake/FileUtils.pm` (its `General.pm` has no wait macros). `aclocal --install --diff` died on any difference (diff exits 1). Test: `handle_exec_errors` reports and propagates status 3.
- [x] gettext-tools 1.0 (whole tree built, tools part installed): libtextstyle with GNU termcap (`gl_cv_terminfo=no gl_cv_termcap=libtermcap`; it had picked up MSYS2's libncurses), archive format pinned to xz (`--with-xz`, xz in `build:`), patch 0005 lets autopoint hand the archive to tar (bsdtar, run dependency libarchive). Test runs autopoint on a configure.ac with `AM_GNU_GETTEXT`. uutils has no `id` on Windows; configure only warns.
- [ ] uutils `env` cannot start a `#!` script (Windows reports "not a valid Win32 application"); libtool's inline-source needed `env ... sh SCRIPT`. Teach env (or a scriptexe-like fallback) to run scripts through their interpreter.
- [x] MSYS2-era packages removed from `C:\msys64\ucrt64` (2026-10-05: brush, m4, make, scriptexe, uutils-*, winflexbison and their `lib\posix-env`). perl and gawk had used its `mingw32-make.exe`; both now run our `make` (perl build 6 also records `make`, not `mingw32-make`, as `$Config{make}` for module builds). Left over: `ucrt64\lib\posix-env\bin\code.exe` (unowned launcher, 2026-10-03).
- [ ] Choose the external toolchain and how the environment finds it (now `POSIX_ENV_TOOLCHAIN`, default `C:\msys64\ucrt64\bin`).
- [x] Interactive launcher: `tools\posix-shell.cmd` (creates `%USERPROFILE%\posix-env` on first use, puts the toolchain on PATH, `micromamba run … sh`) and `tools\posix-shell-entries.ps1` (Start menu shortcut and Windows Terminal profile fragment "POSIX Shell", created by posix-shell.cmd when missing; `-Remove`). Installation is per user only (decided 2026-10-05).
- [ ] Rewrite the environment doc for conda packaging.
- [x] Retire `C:\nativetools` (2026-10-05): TODO.md and the design doc moved here; the MSYS2-era launcher and packaging scripts deleted.
- [x] brush patch 0023: `esac` is no case pattern without `(` (POSIX rule 4); `(case x in x) …;; esac)` failed (automake install hooks, gzip). Parser test added.
- [ ] brush: `$(case x in x) …;; esac)` still fails: `command_substitution_body` ends at the pattern's `)`; the tokenizer needs to track `case … in … esac`.
- [x] config.site: `ac_cv_path_shell=$CONFIG_SHELL` (gzip's POSIX-shell search looks only in `/bin`-style PATH entries).

## Encoding and locale

- [x] UTF-8 manifests in gawk, m4, make, flex, bison, perl, which, chmod (checked 2026-10-05; see Locale).
- [x] Native GNU tools honor `LC_ALL`, `LC_*`, `LANG` through `c-locale.o`; activation sets `LANG=C.UTF-8` (see Locale).
- [x] GNU diffutils 3.12 (cmp, diff, diff3, sdiff), binary standard streams; tested byte for byte.

## Deferred alternatives

- [ ] Port GNU findutils
- [ ] Port GNU grep
- [ ] Port GNU sed
