# posix-env: a native POSIX build environment for Windows

## Summary

posix-env builds Autotools-based software on Windows without the MSYS or
Cygwin runtime: a native shell (brush), native POSIX tools (uutils and GNU
ports) and an external MinGW-w64 UCRT toolchain. Every tool is an ordinary
Windows program; there is no `fork()` emulation and no path translation.

The tools are packaged as `.conda` packages, built from release sources with
rattler-build and installed with micromamba. Only the local channel in
`output\` is used: no package comes from conda-forge or any other channel.

## Using it

The launcher is `posix-env.cmd` at the top of the environment
(`%USERPROFILE%\posix-env\posix-env.cmd`), installed by the posix-env
package; it takes a command:

| Command | Does |
|---|---|
| `posix-env run` | opens a POSIX shell |
| `posix-env run COMMAND...` | runs a command in the environment (`posix-env run make -j8`) |
| `posix-env install NAME...` | adds packages (`posix-env install dejagnu`) |
| `posix-env remove NAME...` | removes packages |
| `posix-env list` | lists the installed packages |
| `posix-env update` | updates all packages |
| `posix-env setup` | adds the default packages and the user's settings (below) |
| `posix-env help` | lists the commands (also without a command) |

The same command works in the POSIX shell, where `bin/posix-env`, a small
sh script, hands it to the launcher. Double-clicked, the launcher opens the
shell. Packages come from the channel named in the environment's `.condarc`,
and the package commands use the environment's own micromamba (the
micromamba package, the upstream release binary), so an installed
environment needs no source checkout. `posix-env update` can replace the
launcher and micromamba while they run: micromamba runs from a temporary
copy, and cmd reads each command block whole before it runs it.

`posix-env setup` is the only command that adds the default packages
(posix-env, autoconf, automake, libtool, gettext-tools, pkgconf, diffutils,
patch, file, gzip, libarchive, xz, zstd and less) or changes the user's settings:
a Start menu entry and a Windows Terminal profile, both named "POSIX Shell"
and both running `posix-env run`, and the environment's top directory on
the user's `PATH`, so `posix-env` works in any new cmd window. That
directory holds no program but `posix-env.cmd`: the tools in `bin` stay off
the Windows `PATH`. The installer runs `setup`; running it again restores
whatever is missing. `share\posix-env\posix-env-entries.ps1 -Remove` in the
environment removes the three settings.

`tools\posix-env.cmd` in a checkout is the installer for the checkout's
channel (`output\`): `tools\posix-env setup` creates `%USERPROFILE%\posix-env`
if there is none (per user only, `POSIX_ENV_HOME` names another place),
records the channel in `.condarc` and runs the installed `posix-env setup`.
Every other command goes to the installed launcher.

| Variable | Meaning | Default |
|---|---|---|
| `POSIX_ENV_HOME` | the environment `tools\posix-env.cmd` works on | `%USERPROFILE%\posix-env` |
| `POSIX_ENV_TOOLCHAIN` | the compiler's `bin` directory, put on `PATH` | `C:\msys64\ucrt64\bin` |
| `POSIX_ENV_GIT` | a directory with `git.exe`, put on `PATH` if it has one | `%ProgramFiles%\Git\cmd` |
| `POSIX_ENV_EXTRA_PATH` | more directories for `PATH` | none |

The shell's `PATH` is the environment's `bin`, the toolchain, `System32` and
`Windows`, git, then `POSIX_ENV_EXTRA_PATH`; the Windows `PATH` is not
inherited, so build scripts find no other `grep`, `sed` or `perl`.

The toolchain (gcc, binutils, mingw-w64) is not packaged. Any MinGW-w64 UCRT
toolchain works; MSYS2's UCRT64 one is the default.

## Building packages

```
powershell -ExecutionPolicy Bypass -File tools\fetch.ps1
powershell -ExecutionPolicy Bypass -File tools\prefill.ps1 [RECIPE...]
build RECIPE [RECIPE...] [-- rattler-build options]
```

- `tools\fetch.ps1` downloads the pinned `rattler-build.exe` and
  `micromamba.exe` into `tools\` and checks their SHA-256 sums.
- `tools\prefill.ps1` (optional) fills rattler-build's source cache
  (`output\src_cache`) from local archives and git repositories, so that
  sources already on the machine are not downloaded again.
- `build.cmd` builds recipes from `recipes\` into `output\` with only the
  local channel. `PATH` holds System32, the toolchain (`POSIX_ENV_TOOLCHAIN`)
  and git (`POSIX_ENV_GIT`, default `%ProgramFiles%\Git\cmd`); everything
  else comes from the build environment.

Recipe conventions:

- Release sources only, no git snapshots (brush is the exception until its
  next release). GNU sources come from `https://ftpmirror.gnu.org/gnu/`.
- `build.sh` runs with `interpreter: brush` from the build environment, which
  holds the posix-env packages themselves.
- Builds use all cores: `make -j"$(nproc)"`.
- Every recipe has tests; rattler-build runs them in a fresh environment.
- Toolchain runtime DLLs are linked statically (`-static-libgcc`), so no
  package imports a DLL from the toolchain.
- Packages cannot hold symlinks: `install`'s symlinks become copies, and
  multicall programs get hard links from `post-link.bat` (removed by
  `pre-unlink.bat`).
- conda relocates prefixes only in text files on Windows. Programs with
  compiled-in paths (gawk's `AWKPATH`, make's and m4's `LOCALEDIR`) compute
  them from the executable's location instead.
- `#!` scripts that must be started by Windows programs get a copy of
  `scriptexe.exe` as `NAME.exe` next to them (`zgrep`, `xzgrep`, `autopoint`).

## Conventions of the environment

1. **Paths** are native Windows paths written with `/`: `C:/Users/me/posix-env/lib`.
   The activation script rewrites `PATH`, `PREFIX`, `TEMP` and similar
   variables that way, and brush presents `PWD` and `command -v` the same,
   because scripts paste these values into `sed` and `eval`, where `\` is an
   escape.
2. **Binary I/O.** The tools read and write bytes unchanged, with no CRLF
   translation; text mode is available per tool through its own options
   (`sed -b`, `grep -U`, gawk `BINMODE`, perl `binmode(FH, ":crlf")`).
   Toolchain programs such as gcc still write CRLF, so the shell converts CRLF
   to LF in command substitution, as MSYS2's bash does.
3. **PATH** contains only native programs: the environment, the toolchain,
   System32.
4. **UTF-8.** Every C program carries a UTF-8 active code page manifest, and
   activation switches the console to code page 65001.
5. **Locale as on POSIX.** `setlocale(…, "")` reads `LC_ALL`,
   `LC_<CATEGORY>` and `LANG` and falls back to `C`, not to the Windows
   locale; `POSIX` and `C.UTF-8` are accepted. Activation sets
   `LANG=C.UTF-8` when no locale is set.
6. **No POSIX absolute paths.** `/bin/sh`, `/usr` and `/tmp` do not exist.
   brush runs `#!` scripts by looking up the interpreter's file name in
   `PATH`, and handles `/dev/null` in redirections.
7. **Executable lookup** finds `foo.exe` for `foo` (PATHEXT), and `test -x`
   is true for directories and `#!` scripts.
8. **Symlinks** are real NTFS symlinks (`ln -s` with Developer Mode).
9. **Windows process model.** No `fork`; children inherit only stdin,
   stdout and stderr; `exec` is spawn-wait-exit; signals other than Ctrl-C
   are accepted but never delivered; permissions are the read-only bit.
10. **LF-only sources.** With binary I/O, CRLF files reach tools as they are,
    so source trees should be checked out with LF: `core.autocrlf=false`, and
    a `.gitattributes` (`* text=auto eol=lf`) where needed.
11. **Remaining limits:** a case-insensitive file system and a 32K
    command-line limit (response files work with gcc and binutils).

## How it works

### Activation

The posix-env package installs `etc\conda\activate.d\posix-env.bat`, which
micromamba runs on activation (`micromamba run`, `micromamba activate`):

| Variable | Why |
|---|---|
| `CONFIG_SHELL`, `SHELL` | configure otherwise runs `/bin/sh` |
| `PATH_SEPARATOR=;` | autoconf detects it by running `/bin/sh`, before `config.site` is read |
| `CONFIG_SITE` | the environment's `config.site`, below |
| `PERL5SHELL` | `perlsh.exe`: Win32 perl hands commands to its shell quoted for cmd.exe; perlsh passes them to `sh -c` |
| `LANG=C.UTF-8` | only when neither `LC_ALL` nor `LANG` is set |

It also switches the console to code page 65001. Deactivation undoes all of
this, including the code page.

### config.site

| Setting | Why |
|---|---|
| `build_alias=x86_64-w64-mingw32` | `config.guess` recognizes MinGW only by MSYS's `uname -s` |
| `ac_executable_extensions=.exe` | autoconf's program search tries `gcc`, not `gcc.exe` |
| `SED`, `GREP`, `EGREP`, `FGREP` | `AC_PROG_SED`/`AC_PROG_GREP` search all of `PATH` and can pick a text-mode tool from the toolchain directory |
| `ac_cv_path_shell` | some POSIX-shell searches look only in `/bin`-style directories |
| `lt_cv_deplibs_check_method`, `lt_cv_file_magic_cmd` | without a `file` command, libtool 2.2.x falls back to an i386-only pattern and builds no DLL that depends on an x86-64 import library |
| `LDFLAGS`: `utf8-manifest.o` | UTF-8 active code page; `posix_env_manifest=no` opts out for packages with their own manifest |
| `LDFLAGS`: `c-locale.o` | wraps the UCRT's `setlocale`/`_wsetlocale` for the POSIX locale rules above |
| `LDFLAGS`: `binmode.o` | standard streams and opened files in binary mode (programs only, not DLLs) |

The three objects live in `lib\posix-env`. Packages not built by configure
(perl, gawk's `pc/` port, winflexbison, lz4, zstd, libarchive's own
manifests) link them by hand. Rust programs (brush, uutils) need none of
them: Rust's standard library uses the wide Windows APIs and binary I/O.

## Packages

| Package | Programs |
|---|---|
| posix-env | `posix-env.cmd` (the launcher) and `posix-env` (its sh front end), `chmod`, `which`, `perlsh`; activation, `config.site`, the link objects. Depends on the packages up to micromamba |
| brush | `sh`, `bash` (hard links to `brush`) |
| uutils-coreutils | `coreutils` and a hard link for every utility it contains (`ls`, `cp`, `sort`, …) |
| uutils-findutils | `find`, `xargs` |
| uutils-grep | `grep` |
| uutils-sed | `sed` |
| gawk | `awk`, `gawk` (with MPFR and readline) |
| make | `make` |
| m4 | `m4` |
| winflexbison | `flex`, `lex`, `bison`, `yacc` |
| scriptexe | `libexec\posix-env\scriptexe.exe`, copied by other packages, not on `PATH` |
| micromamba | `libexec\posix-env\micromamba.exe`, the launcher's package manager, not on `PATH` |
| autoconf | `autoconf`, `autoheader`, `autom4te`, `autoreconf`, `autoscan`, `autoupdate`, `ifnames` |
| automake | `aclocal`, `automake` (and `-1.18` names) |
| libtool | `libtool`, `libtoolize` |
| perl | `perl`, `wperl`, `perlglob` |
| gettext-runtime | `gettext`, `ngettext`, `envsubst`, … and libintl, libasprintf |
| gettext-tools | `msgfmt`, `xgettext`, `msgmerge`, `autopoint`, … |
| pkgconf | `pkg-config`, `pkgconf` |
| diffutils | `cmp`, `diff`, `diff3`, `sdiff` |
| patch | `patch` |
| file | `file` and libmagic |
| libiconv | `iconv` |
| gperf | `gperf` |
| gzip | `gzip`, `gunzip`, `zcat`, `uncompress`, `zgrep`, … |
| bzip2 | `bzip2`, `bunzip2`, `bzcat`, `bzgrep`, … |
| xz | `xz`, `unxz`, `xzcat`, `xzgrep`, … |
| zstd | `zstd`, `unzstd`, `zstdcat`, `zstdmt`, `zstdgrep`, … |
| lz4 | `lz4`, `unlz4`, `lz4cat` |
| libarchive | `bsdtar`, `bsdcpio`, `bsdcat`, `bsdunzip`; `tar`, `unzip` |
| pcre2 | `pcre2grep`, `pcre2test` |
| expat | `xmlwf` |
| less | `less`, `lessecho` |
| bear | `bear` (and `bear-wrapper`, which it runs) |
| tcl | `tclsh` |
| expect | `expect` (Expect's commands for DejaGnu, on pipes) |
| dejagnu | `runtest`, `dejagnu` |
| Libraries only | gmp, mpfr, readline, termcap, zlib, libb2, oniguruma, libtre, libsystre |

openssl has a recipe but does not build yet (see TODO.md).

## POSIX utilities

[POSIX.1-2024](https://pubs.opengroup.org/onlinepubs/9799919799/idx/utilities.html)
defines 155 utilities, plus the special built-ins (`break`, `:`, `.`, `eval`,
`exec`, `exit`, `export`, `readonly`, `return`, `set`, `shift`, `times`,
`trap`, `unset`), all of which brush provides.

| Group | Count | Utilities |
|---|---|---|
| Shell built-ins (brush) | 15 | alias bg cd command fc fg getopts hash jobs read time type umask unalias wait |
| posix-env packages | 79 | awk basename cat chmod cksum cmp comm cp csplit cut date dd df diff dirname du echo env expand expr false file find fold gettext grep head iconv join kill lex¹ link ln ls m4 make mkdir more msgfmt mv ngettext nice nl nohup od paste patch pathchk pr printf pwd readlink realpath rm rmdir sed sh sleep sort split tail tee test timeout touch tr true tsort tty uname uncompress unexpand uniq unlink wc xargs xgettext yacc¹ zcat |
| External toolchain (binutils) | 4 | ar nm strings strip |
| Not provided | 16 | bc c17² compress ctags ed gencat getconf id locale localedef logname mkfifo pax ulimit³ uudecode uuencode |
| Not provided: interactive and terminal | 11 | cal ex man mesg stty tabs talk tput vi who write |
| Not provided: administration, jobs, printing, mail, UUCP | 17 | at batch chgrp chown crontab fuser ipcrm ipcs logger lp mailx newgrp ps renice uucp uustat uux |
| Not provided: SCCS | 10 | admin delta get prs rmdel sact sccs unget val what |
| Not provided: development aids | 3 | asa cflow cxref |

1. `lex` and `yacc` are winflexbison's flex and `bison -y`.
2. There is no `c17` driver; build systems call `gcc`.
3. brush does not implement `ulimit` on Windows.

## Speed

Measured with the MSYS2-era prototype of this environment (same tools, same
machine, idle, release builds), against MSYS2's bash and coreutils:

| Workload | Native | MSYS | Ratio |
|---|---|---|---|
| zlib `configure` | 7.6 s | 21.6 s | 2.8× |
| GCC top-level `configure` | 7.7 s | 19.5 s | 2.5× |
| libiberty `configure` | 24.9 s | 42.4 s | 1.7× |
| Start an external program, 500× | 4.1 s | 9.8 s | 2.4× |
| `x=$(echo … \| tr …)`, 500× | 4.3 s | 20.8 s | 4.8× |
| Shell-only loop, 100k iterations | 1.5 s | 1.4 s | 1.0× |

Interpreting shell code is equally fast; the difference is process creation.
In m4's configure (113 s), gcc takes 44 % of the time and uutils `rm`, `cat`
and `mv` 27 %; brush itself takes under 3 %.

## Patches

Patches live next to each recipe (`recipes\NAME\*.patch`). The larger series:

| Project | Changes |
|---|---|
| brush | Windows: `exec`, `/` in `PWD` and command paths, `#!` scripts, `test -x` on directories, `test -ef`, POSIX signal names in `trap`, `umask`, CRLF in command substitution, libtool's MSYS path conversion; all platforms: deadlocks with large here-docs and concurrent pipeline stages, backquote and `case` parsing, non-UTF-8 command substitution output |
| uutils | coreutils: `ln` symlink targets, `dd conv=lcase/ucase`, `env` runs `#!` scripts; sed: `&` as delimiter, unknown escapes, bracket expressions, escaped anchors, `n`, the `-i` suffix |
| perl | MSYS2's patches; binary PerlIO by default, POSIX `setlocale`, UTF-8 manifests |
| autoconf, automake | closing files before Win32 replaces them, exit statuses without `POSIX::WIFEXITED`, `/` in generated paths |
| libtool | MSYS2's patches, `PROG.exe` in program searches, scripts started through sh |
| gawk, make, m4 | paths computed from the executable's location; gawk's `pc/` port for current UCRT headers |

Open problems are tracked in `TODO.md`.
