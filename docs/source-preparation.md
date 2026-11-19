# Preparing source trees

`posix-env-prepare` applies maintained patches to an existing source directory
before configuring a native Windows build. GCC and binutils are the first
project-specific patch sets. Other projects can use the recognized bundled
Libtool/gettext fixes.

The command is supplied by the `posix-env-prepare` package and included in
`posix-env setup`. For an existing environment:

```console
posix-env install posix-env-prepare
```

Run it inside the posix-env shell, or through `posix-env run`:

```sh
posix-env-prepare --dry-run C:/src/gcc
posix-env-prepare C:/src/gcc

posix-env-prepare --dry-run C:/src/binutils-gdb
posix-env-prepare C:/src/binutils-gdb
```

With no directory argument it uses the current directory. Paths containing
spaces must be quoted. Source trees can be release archives or existing Git
checkouts. The command does not download sources, run configure, build, or
change Git history. Continue with the project's normal out-of-tree configure
and build procedure after preparation.

GCC is detected using `gcc/BASE-VER`; binutils using `bfd/version.m4`. An explicit
`--project=gcc` or `--project=binutils` checks that the directory is the expected
project. `--project=generic` applies only the bundled build-script fixes.

## What it changes

- Libtool's handling of drive-letter paths and MSYS-specific path conversion.
- Libtool's Windows executable wrappers, including their own executable path
  and symbolic-link resolution.
- Gettext's source-directory handling in the relevant macros and generated
  configure scripts.
- GCC's build-tree libgcc DLL placement, runtime-library discovery in the
  testsuite, and PATH separators with native Windows Tcl.
- Binutils' native LTO plugin discovery and executable suffixes/libdl handling
  in the linker bootstrap tests.

The command searches bundled copies recursively, including `ltmain.sh`,
`libtool`, `configure`, `config.status`, and M4 source files. It excludes VCS
metadata and symbolic links. Project patch paths must also be ordinary files,
without symbolic-link components.

It reports each selected patch as `planned` or `already applied`. All selected
patches are checked before any source file is opened for writing. An unsupported
version of an affected function, a missing required project file, or a local
edit inside a patch's context makes preparation fail without applying anything.
It does not use patch fuzz, execute source files, or run regeneration tools.

Already applied hunks are recognized from their contents. Running the command
again makes no changes unless a relevant file has changed or been regenerated.
Run it again after `autoreconf` or other script regeneration, before configure.
There is no stamp file that could conceal newly regenerated code.

LF and CRLF files keep their existing line endings. The command preserves file
permissions, checks for concurrent changes before writing, and attempts to
restore originals if a write fails. Updates to several files are not atomic
against a process crash or power loss; keep source changes under version control
or retain the source archive.

## Coverage

Initial application checks cover the existing GCC 17.0.0 and binutils 2.47.50
trees, whose bundled Libtool is 2.2.7a. Selection uses exact source context;
other revisions can work when those contexts match. Preparation success means
the selected patches applied, not that every compiler configuration or test
will pass. The ordinary posix-env shell, tools, and external native toolchain
are still required.

Starting with brush 0.4.0.post177 build 12, the shell no longer substitutes
Libtool/gettext code at runtime. Run `posix-env-prepare` before configuring
source trees that need these fixes, and rerun it after regenerating affected
build scripts.

## Development

The command can run directly from this checkout without building a package:

```console
posix-env run perl recipes/posix-env-prepare/posix-env-prepare --dry-run C:/src/gcc
posix-env run perl recipes/posix-env-prepare/test/run.pl
```

Tests use temporary source fixtures under `%TEMP%`; they do not compile GCC or
binutils. They cover patch application, repeated runs, regenerated files,
conflicts, CRLF, source links, native path conversion, and emitted wrapper code.
Shell behavior tests rename the patched functions so runtime substitutions in
older brush packages cannot mask an incorrect source patch.

The patch catalog and its provenance are described in
[the patch directory](../recipes/posix-env-prepare/data/README.md).
