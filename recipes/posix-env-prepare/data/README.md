# Source patches

`catalog.json` selects the unified patches in this directory. The command and
package use these files directly; there is no second set embedded in the Perl
program. Future GCC/binutils recipes can use the same files or invoke prepare.

## Origins and scope

The brush patch numbers below refer to the historical patches in posix-env
commit `cf53eca`. They have been removed from the brush recipe now that their
source fixes are applied here.

| Patch | Origin | Purpose |
|---|---|---|
| `libtool-*-normal-abspath` | brush patch 0015 | Recognize drive letters and consume them before splitting a path into components |
| `libtool-*-to-host-path*`, `libtool-*-convert-core-msys-to-w32` | brush patch 0021; the 2.2 variants use the complete functions bundled with GCC/binutils | Replace MSYS `cmd //c` conversion with native path handling |
| `libtool-wrapper-executable` | brush patch 0026 | Find the wrapper through `_pgmptr` instead of potentially extensionless `argv[0]` |
| `libtool-wrapper-symlinks` | brush patch 0027 | Resolve the wrapper's final Windows path through symbolic links |
| `gettext-source-directory-*` | brush patch 0015 | Recognize drive-letter source paths when generating `po/POTFILES` |
| `gcc-libgcc-build-directory-*` | Not yet submitted to GCC | Copy the libgcc DLL to the GCC build directory; accept both upstream and partially fixed sources |
| `gcc-test-library-path` | Not yet submitted to GCC | Locate the MinGW import library and use native Windows PATH separators |
| `gcc-target-tool-paths` | Not yet submitted to GCC | Look a bare `AS_FOR_TARGET`, `NM_FOR_TARGET` or `DSYMUTIL_FOR_TARGET` up in PATH: tested in the build directory, it matched the tool's exec-tool wrapper, which then exec'd itself once the testsuite put the build directory on PATH |
| `binutils-lto-plugin` | Not yet submitted to binutils | Find `liblto_plugin.dll` |
| `binutils-bootstrap` | Not yet submitted to binutils | Use executable suffixes and omit libdl on Windows in the linker bootstrap tests |

Project source versions are printed for diagnostics. Applicability is determined
by exact hunk context, rather than assuming that every revision with a given
version number has identical files. Unknown or edited contexts are errors.

The initial integration checks use GCC 17.0.0 and binutils 2.47.50 source trees.
The bundled Libtool in both is 2.2.7a. Additional exact Libtool function variants
come from the former brush patches for 2.4 through 2.6. These are not a claim
that all releases or locally modified copies in those version ranges match.

The Libtool/gettext patches retain their original source licenses. Libtool is
copyright the Free Software Foundation and distributed under GPL version 2 or
later with its exception allowing a bundled copy to use the surrounding
program's distribution terms. The gettext 0.12 `po.m4` fragments are copyright
1995-2003 the Free Software Foundation, under the GNU GPL with the exception
allowing distribution with an Autoconf-configured program under that program's
distribution terms.
The GCC/binutils patches and source fixtures retain GPL version 3 or later.
The command itself is MIT licensed. Full GPL texts and the MIT license are in
the recipe directory and included in the package's license metadata.

## Adding a patch

Use an ordinary unified diff with `a/` and `b/` paths, nonempty context, and
modifications to existing text files. File creation, deletion, renaming, and
binary patches are not supported by this command.

A project entry has `id`, `project` (`gcc` or `binutils`), and `variants` (patch
filenames in preference order). Every file in one variant must match before
the entry is accepted. A variant may contain multiple files and hunks.

A generic entry uses `probe`, a regular expression identifying the affected
build-script construct. Each variant modifies one logical file; the command
tries it against each discovered build script containing the construct. These
diffs can therefore cover bundled copies under different directory names.
Keep probes specific: a matching probe with no applicable variant is a conflict.

Every hunk must match either its complete original or complete replacement
text uniquely. Line offsets are allowed; context is never discarded or matched
approximately. A partial application consisting of complete hunks can be
finished. An edit inside a hunk is rejected. CRLF is normalized for matching
and restored when writing; mixed line endings are rejected in changed files.

Record the patch's origin here and add a source fixture or regression test.
Keep package-layout changes and unrelated compiler features out of the catalog.
Do not change test expectations to hide a compiler or platform regression.
