# Fixture provenance

These are source files or excerpts used to test source preparation. They are
never compiled by this test suite.

- `gcc/`: GCC commit `a8394f028bc8481558b502ea97240002a205cb0f`'s parent,
  before the maintained libgcc and testsuite changes; GCC 17.0.0.
  `gcc/gcc/configure.ac` and `gcc/gcc/configure` contain the as, nm and
  dsymutil probes from the same revision.
- `binutils/`: binutils commit `d10697b9257`; binutils 2.47.50, before the
  selected LTO plugin and linker bootstrap changes on this branch.
- The `ltmain.sh` files contain complete selected functions from the Libtool
  2.2.7a copies in those trees, including the executable-wrapper generator.
- `config/po.m4` and `configure` contain the affected source-directory case
  statement from the bundled gettext 0.12 `po.m4`. The macro fixture retains
  its double-quoted `AC_CONFIG_COMMANDS` body.

GCC and binutils files retain their Free Software Foundation copyright notices
and GPL version 3 or later licenses. The Libtool excerpts are copyright
1996-2009 the Free Software Foundation, under GPL version 2 or later with the
Libtool distribution exception. The gettext excerpts are copyright 1995-2003
the Free Software Foundation, under the GPL with its Autoconf distribution
exception. See `../../data/README.md`, `../../COPYING2`, and `../../COPYING3`.
