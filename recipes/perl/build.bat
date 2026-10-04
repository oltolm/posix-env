@rem Builds perl with win32\GNUmakefile under cmd.exe, as README.win32 and
@rem MSYS2 do.  SHELL is passed explicitly: the build environment has sh.exe
@rem in PATH and SHELL set, which mingw32-make would otherwise use.  The
@rem runtime (libgcc, libstdc++, winpthread) is linked statically: the
@rem toolchain's DLLs are not part of any environment.
@rem posix-env activation turned PREFIX into C:/...; conda relocates the
@rem backslashed form, so install with that.
set "WPREFIX=%PREFIX:/=\%"
for %%i in (gcc.exe) do set "GCCDIR=%%~dp$PATH:i"
for %%i in ("%GCCDIR%..") do set "CCHOME=%%~fi"
@rem posix-env's setlocale and _wsetlocale for the C locales, as its
@rem config.site arranges it for configure: perl reads LC_ALL and LANG itself
@rem and passes names such as C.UTF-8, which the UCRT rejects.  A full path:
@rem LINK32 links with -static.
set "LINK32=g++ -static -Wl,--wrap=__imp_setlocale -Wl,--wrap=__imp__wsetlocale"
set "LIBC=%BUILD_PREFIX%/lib/posix-env/c-locale.o"
cd win32 || exit /b 1
mingw32-make -j%NUMBER_OF_PROCESSORS% CCTYPE=GCC GCCBIN=gcc CC=gcc "LINK32=%LINK32%" "LIBC=%LIBC%" CCHOME="%CCHOME%" INST_DRV=%WPREFIX:~0,2% INST_TOP="%WPREFIX%" INST_DOC="%WPREFIX%" USE_64_BIT_INT=define USE_MINGW_ANSI_STDIO=define SHELL=%COMSPEC% PLMAKE=mingw32-make || exit /b 1
mingw32-make CCTYPE=GCC GCCBIN=gcc CC=gcc "LINK32=%LINK32%" "LIBC=%LIBC%" CCHOME="%CCHOME%" INST_DRV=%WPREFIX:~0,2% INST_TOP="%WPREFIX%" INST_DOC="%WPREFIX%" USE_64_BIT_INT=define USE_MINGW_ANSI_STDIO=define SHELL=%COMSPEC% PLMAKE=mingw32-make install || exit /b 1
cd /d "%WPREFIX%" || exit /b 1
@rem Config.pm and CORE\config.h spell the prefix with doubled backslashes,
@rem which conda does not relocate; give them the single-backslash form,
@rem which it does (and which both a Perl '...' and a C string accept after
@rem relocation turns it into C:/...).  The setlocale wrapping is perl's own:
@rem XS modules built later must not inherit it from Config (ld, libs), which
@rem names the build environment.  The files are read-only, hence del /f.
"%WPREFIX%\bin\perl.exe" -i.bak -pe "BEGIN { $d = $ENV{WPREFIX} =~ s/\\/\\\\/gr } s/\Q$d\E/$ENV{WPREFIX}/g; s{ -Wl,--wrap=__imp_setlocale -Wl,--wrap=__imp__wsetlocale}{}g; s{\S*/lib/posix-env/c-locale\.o ?}{}g" lib\perl5\core_perl\Config.pm lib\perl5\core_perl\Config_heavy.pl lib\perl5\core_perl\CORE\config.h || exit /b 1
del /f lib\perl5\core_perl\Config.pm.bak lib\perl5\core_perl\Config_heavy.pl.bak lib\perl5\core_perl\CORE\config.h.bak
@rem Install bookkeeping that conda tracks itself.
"%WPREFIX%\bin\perl.exe" -MFile::Find -e "find(sub { unlink $_ if $_ eq q{.packlist} || $_ eq q{perllocal.pod} }, q{.})" || exit /b 1
