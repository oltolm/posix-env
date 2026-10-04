# A native POSIX build environment for MSYS2

## Summary

Autotools-based software can be built on Windows without the MSYS runtime:
a native shell (brush), native POSIX tools (uutils and friends) and the
existing UCRT64 toolchain. A full GCC build (C and C++, libstdc++ and
libsanitizer as DLLs) works this way today, with configure scripts running
1.7 to 2.8 times faster than under MSYS bash.

The environment only works if its tools follow POSIX conventions (binary
I/O, `/` path separators) while the text-mode Windows tools in
`/ucrt64/bin` stay out of its way. This proposal asks for agreement on how
to package it: a separate bin directory, a few new packages, and a launcher.
The patches it depends on are listed at the end; most are upstream fixes.

## Why

- **Speed.** Every process an MSYS shell starts goes through the `fork()`
  emulation. Native process creation is several times cheaper, and configure
  scripts are mostly process creation.
- **Environment mixing.** A UCRT64 shell puts `/ucrt64/bin` before `/usr/bin`,
  so any native package that provides a POSIX command name silently replaces
  the MSYS tool in build scripts. Installing `mingw-w64-ucrt-x86_64-sed`
  breaks `autopoint` (its text-mode output adds `\r` to file names);
  a native `file` would change libtool's behaviour.
- **No translation layer.** Native tools see native paths. There is no
  argument or environment rewriting to work around.

### Measurements

Same machine, idle, release builds:

| Workload | Native | MSYS | Ratio |
|---|---|---|---|
| zlib `configure` | 7.6 s | 21.6 s | 2.8× |
| GCC top-level `configure` | 7.7 s | 19.5 s | 2.5× |
| libiberty `configure` | 24.9 s | 42.4 s | 1.7× |
| Start an external program, 500× | 4.1 s | 9.8 s | 2.4× |
| `x=$(echo … \| tr …)`, 500× | 4.3 s | 20.8 s | 4.8× |
| Shell-only loop, 100k iterations | 1.5 s | 1.4 s | 1.0× |

Interpreting shell code is equally fast; the difference is process creation.

## Conventions of the environment

1. **Paths** are native Windows paths written with `/`: `C:/msys64/ucrt64/lib`.
   Shells present `PWD`, `PATH` lookups and `command -v` the same way, because
   scripts paste these values into `sed` and `eval`, where `\` is an escape.
2. **Binary I/O by default.** The environment's tools read and write bytes
   unchanged, with no CRLF translation; text mode is available per tool
   through its own options (`sed -b`, `grep -U`, gawk `BINMODE`). Cygwin made
   the same choice in 1.7, when it removed `CYGWIN=binmode` because every
   open defaults to binary. Rust tools are binary already; C tools get it by
   linking mingw-w64's `binmode.o` (see below). Toolchain programs such as gcc
   still write CRLF, so the shell converts CRLF to LF in command substitution,
   as MSYS2's bash does.
3. **PATH** contains only native binaries, never MSYS ones.
4. **UTF-8** throughout: programs use a UTF-8 active code page manifest and
   the console uses code page 65001.
5. **No POSIX absolute paths.** `/bin/sh`, `/usr`, `/ucrt64` and `/tmp` do
   not exist. The shell runs `#!` scripts by looking up the interpreter's
   file name in `PATH`; `/dev/null` is handled in redirections.
6. **Executable lookup** finds `foo.exe` for `foo` (PATHEXT), and `test -x`
   is true for directories and `#!` scripts.
7. **Symlinks** are real NTFS symlinks (`ln -s` with Developer Mode).
   Tools that compare timestamps must follow them.
8. **Windows process model.** No `fork`; children inherit only stdin,
   stdout and stderr; `exec` is spawn-wait-exit; signals other than Ctrl-C
   are accepted but never delivered; permissions are the read-only bit.
9. **LF-only sources.** With binary I/O, CRLF files reach tools as they are,
   so source trees should be checked out with LF: `core.autocrlf=false`, and
   a `.gitattributes` (`* text=auto eol=lf`) in repositories that need it.
10. **Limits that remain:** a case-insensitive file system and a 32K
    command-line limit (response files work with gcc and binutils).

## Proposed packaging

### A separate bin directory

The environment's POSIX tools live in their own directory, for example
`/ucrt64/lib/posix-env/bin`, so that they never shadow `/ucrt64/bin` for
interactive use or for MSYS shells, and text-mode tools never shadow them.

- `sh.exe` and `bash.exe`: brush.
- The uutils packages install plain-named binaries (`ls.exe`, `sed.exe`, …)
  into this directory in addition to the `uu-` prefixed ones in
  `/ucrt64/bin`. No shims or copies are needed.
- `awk`, `yacc`, `flex`, `make` and small helpers (`which`, `chmod`) as below.

The environment's `PATH` is this directory, then `/ucrt64/bin` (for the
compilers), then `C:/Windows/System32`.

### New or changed packages

| Tool | Proposal |
|---|---|
| brush | already packaged; needs the Windows fixes below (upstream) |
| uutils coreutils, findutils, sed, grep | install plain names into the new directory; needs the fixes below |
| awk | gawk: a new native package, built through gawk's `pc/` port (patch below) |
| flex, bison | winflexbison, built with mingw-w64: `win_flex` and `win_bison` (bison 3.8 with m4 built in); upstream flex requires `fork`. MSYS2 currently has no native yacc at all |
| make | `mingw-w64-make` with the symlink timestamp patch |
| which, chmod | small native implementations, or Windows support in uutils `chmod` |

### Program and package inventory

The following programs are supplied by the packages in the current UCRT64
prototype.  Names are shown without `.exe`; aliases are listed separately.
Only the first table is installed by `mingw-w64-ucrt-x86_64-posix-env`'s
required dependencies.

| Package | Programs in the environment |
|---|---|
| `mingw-w64-ucrt-x86_64-posix-env` | `posix-env.cmd`; `chmod`, `which`, and the internal `perlsh` shell adapter |
| `mingw-w64-ucrt-x86_64-brush` | `sh`, `bash` |
| `mingw-w64-ucrt-x86_64-uutils-coreutils` | `[`, `arch`, `b2sum`, `base32`, `base64`, `basename`, `basenc`, `cat`, `cksum`, `comm`, `coreutils`, `cp`, `csplit`, `cut`, `date`, `dd`, `df`, `dir`, `dircolors`, `dirname`, `du`, `echo`, `env`, `expand`, `expr`, `factor`, `false`, `fmt`, `fold`, `head`, `hostid`, `hostname`, `join`, `kill`, `link`, `ln`, `ls`, `md5sum`, `mkdir`, `mktemp`, `more`, `mv`, `nice`, `nl`, `nohup`, `nproc`, `numfmt`, `od`, `paste`, `pathchk`, `pr`, `printenv`, `printf`, `ptx`, `pwd`, `readlink`, `realpath`, `rm`, `rmdir`, `seq`, `sha1sum`, `sha224sum`, `sha256sum`, `sha384sum`, `sha512sum`, `shred`, `shuf`, `sleep`, `sort`, `split`, `stdbuf`, `sum`, `sync`, `tac`, `tail`, `tee`, `test`, `timeout`, `touch`, `tr`, `true`, `truncate`, `tsort`, `tty`, `uname`, `unexpand`, `uniq`, `unlink`, `uptime`, `vdir`, `wc`, `whoami`, `yes` |
| `mingw-w64-ucrt-x86_64-uutils-findutils` | `find`, `xargs` |
| `mingw-w64-ucrt-x86_64-uutils-grep` | `grep` |
| `mingw-w64-ucrt-x86_64-uutils-sed` | `sed` |
| `mingw-w64-ucrt-x86_64-gawk` | `awk`, `gawk` |
| `mingw-w64-ucrt-x86_64-make` | `make` |
| `mingw-w64-ucrt-x86_64-winflexbison` | `flex`, `lex`, `bison`, `yacc` |
| `mingw-w64-ucrt-x86_64-scriptexe` | internal `scriptexe` wrapper generator in `lib/posix-env/libexec` |

These optional dependencies add the native Autotools stack:

| Package | Programs in the environment |
|---|---|
| `mingw-w64-ucrt-x86_64-autoconf` | `autoconf`, `autoheader`, `autom4te`, `autoreconf`, `autoscan`, `autoupdate`, `ifnames` |
| `mingw-w64-ucrt-x86_64-automake` | `aclocal`, `aclocal-1.18`, `automake`, `automake-1.18` |
| `mingw-w64-ucrt-x86_64-m4` | `m4` |
| `mingw-w64-ucrt-x86_64-perl` | `perl`, `wperl`, `perlglob`; Perl is used through `perlsh` by Autoconf and Automake |

The launcher puts `/ucrt64/bin` after the private environment directory.
Programs found there are visible but are not supplied or guaranteed by the
`posix-env` package.  The prototype currently relies at least on these:

| Package | Programs used by the environment |
|---|---|
| `mingw-w64-ucrt-x86_64-gcc` | `cc`, `gcc`, `c++`, `g++`, `cpp`, `gcc-ar`, `gcc-nm`, `gcc-ranlib`, `gcov`, `gcov-dump`, `gcov-tool` |
| `mingw-w64-ucrt-x86_64-binutils` | `addr2line`, `ar`, `as`, `c++filt`, `dlltool`, `dllwrap`, `elfedit`, `gprof`, `ld`, `ld.bfd`, `nm`, `objcopy`, `objdump`, `ranlib`, `readelf`, `size`, `strings`, `strip`, `windmc`, `windres` |
| `mingw-w64-ucrt-x86_64-diffutils` | `cmp`, `diff`, `diff3`, `sdiff` |

If these inherited programs are part of the supported environment rather than
incidental tools in an existing UCRT64 installation, their packages should be
declared as dependencies.

### Binary mode for C tools

mingw-w64's `binmode.o` makes files a program opens default to binary
(`_fmode`), but UCRT opens stdin, stdout and stderr in text mode before
`main`, so linking it is not enough today. Extending `binmode.o` to switch
the three standard streams as well would make binary mode a one-line
`LDFLAGS` change in the PKGBUILDs of POSIX tools (sed, grep, gawk,
diffutils), with no source patches. Programs that do not link it, such as
the compilers, are unaffected.

This changes behaviour for current users of `mingw-w64-sed` and
`mingw-w64-grep`: CRLF input is no longer stripped and output is LF. Text
mode remains available through `sed -b` and `grep -U`.

### Site defaults

Autoconf and libtool need a few settings that MSYS provides implicitly. Most
belong in a `config.site` shipped with the environment (`CONFIG_SITE`):

| Setting | Why |
|---|---|
| `ac_executable_extensions=.exe` | autoconf's program search tries `gcc`, not `gcc.exe` |
| `SED`, `GREP`, `EGREP`, `FGREP` | `AC_PROG_SED`/`AC_PROG_GREP` search all of `PATH` for the "best" implementation; pin the environment's own |
| `lt_cv_deplibs_check_method`, `lt_cv_file_magic_cmd` | without a `file` command, libtool 2.2.x falls back to an i386-only pattern and builds no DLL that depends on an x86-64 import library; both are computed in one cached check, so both must be set |

Three settings must come from the launcher because they are needed before
`config.site` is read: `CONFIG_SHELL` and `SHELL` (otherwise configure runs
`/bin/sh`), and `PATH_SEPARATOR=;` (autoconf detects it by running
`/bin/sh`).

### Launchers

- `posix-env.cmd`, which sets `PATH`, `CONFIG_SHELL`, `SHELL`,
  `PATH_SEPARATOR`, `CONFIG_SITE` and the console code page in the current
  cmd window.
- A Windows Terminal profile fragment and a Start menu entry, as for the
  existing environments.

## POSIX utilities

[POSIX.1-2024](https://pubs.opengroup.org/onlinepubs/9799919799/idx/utilities.html)
defines 155 utilities, plus the special built-ins (`break`, `:`, `.`, `eval`,
`exec`, `exit`, `export`, `readonly`, `return`, `set`, `shift`, `times`,
`trap`, `unset`), all of which brush provides.  Coverage in the prototype
environment:

| Group | Count | Utilities |
|---|---|---|
| Shell built-ins (brush) | 15 | alias bg cd command fc fg getopts hash jobs read time type umask unalias wait |
| Environment tools (uutils, awk, make, winflexbison, chmod) | 69 | awk basename cat chmod cksum cmp comm cp csplit cut date dd df diff dirname du echo env expand expr false find fold grep head join kill lex¹ link ln ls make mkdir more mv nice nl nohup od paste pathchk pr printf pwd readlink realpath rm rmdir sed sh sleep sort split tail tee test timeout touch tr true tsort tty uname unexpand uniq unlink wc xargs yacc¹ |
| Existing UCRT64 packages (binutils, gcc, gettext, ctags) | 10 | ar c17² ctags gettext msgfmt ngettext nm strings strip xgettext |
| Not provided | 20 | bc compress ed file³ gencat getconf iconv id locale localedef logname m4⁴ mkfifo patch pax ulimit⁵ uncompress uudecode uuencode zcat |
| Not provided: interactive and terminal | 11 | cal ex man mesg stty tabs talk tput vi who write |
| Not provided: administration, jobs, printing, mail, UUCP | 17 | at batch chgrp chown crontab fuser ipcrm ipcs logger lp mailx newgrp ps renice uucp uustat uux |
| Not provided: SCCS | 10 | admin delta get prs rmdel sact sccs unget val what |
| Not provided: development aids | 3 | asa cflow cxref |

1. `lex` and `yacc` are `win_flex` and `win_bison -y`.
2. There is no `c17` driver; build systems call `gcc`.
3. On Windows hosts libtool runs `file` only in its deplibs check, which the
   `config.site` settings above replace with `$OBJDUMP -f`.
4. `m4` is needed to regenerate configure scripts, not to run them;
   `win_bison` has its own.
5. brush does not implement `ulimit` on Windows.

A full GCC build needs none of the utilities that are not provided.

## Upstream work

| Project | Change | Status |
|---|---|---|
| brush | Windows: `exec`, `/` in `PWD` and command paths, ignore fds above 2 when spawning, run `#!` scripts, `test -x` on directories, POSIX signal names in `trap`, `umask`, CRLF in command substitution | 12 commits with tests |
| brush | Deadlocks with large here-docs and compound pipeline stages (all platforms; 4 KiB pipe buffer makes them common on Windows) | in the same series |
| brush | Backslash removal inside backquotes (POSIX) | in the same series |
| uutils sed | `&` as the `s` delimiter; unknown escapes in replacements yield the character, as in GNU sed | 2 commits with tests |
| uutils sed | Back-references in the C locale (byte mode) | open; hit only by a harmless GCC configure probe |
| uutils findutils | Join entries below a starting point with `/`, `-execdir` passes `./NAME` (GNU behaviour) | patch ready; changes a deliberate Windows choice, needs discussion |
| mingw-w64 | `binmode.o` also switches stdin, stdout and stderr to binary | proposed |
| gawk | `pc/` port: current mingw-w64 UCRT headers (`_UCRT` detection, `MB_CUR_MAX`, `_popen`, `strcoll`) and a C23 fix for a K&R `strftime` declaration | patch ready, builds with GCC 16 |
| GNU make | Follow symlinks when reading timestamps on Windows | patch in `mingw-w64-make` (pkgrel 6); to bug-make |
| libtool / GCC | `func_normal_abspath` loops forever on drive-letter paths | patch; GCC carries libtool 2.2.7a |
| libtool / GCC | i386-only file-magic fallback (fixed in newer libtool) | worked around by `config.site` |

## Out of scope for now

- **pacman** stays an MSYS program. It never runs during a build.
- **makepkg** is an MSYS bash script; running it under brush can come later.
- **Package metadata** that records `/ucrt64` (`.la` files, some `.pc` and
  `-config` files) is unreadable for native consumers. GCC builds work with
  `--with-sysroot`; a general fix means relocatable or native forms.

## Questions for the maintainers

1. Is a second build layer on top of UCRT64 (rather than a new environment
   with its own prefix) the right shape?
2. Directory and name: `/ucrt64/lib/posix-env/bin` and `posix-env`?
3. Should the uutils packages install plain names into that directory, or
   should a separate package provide them?
4. Is `config.site` acceptable for the autoconf and libtool defaults?
5. Is binary mode by default acceptable for the native POSIX tool packages,
   given the change for current `mingw-w64-sed` and `mingw-w64-grep` users?
