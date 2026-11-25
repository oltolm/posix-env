# configure.ac excerpt
AS_VAR_SET_IF(gcc_cv_as,, [
if test -x "$DEFAULT_ASSEMBLER"; then
	gcc_cv_as="$DEFAULT_ASSEMBLER"
elif test -f $gcc_cv_as_gas_srcdir/configure.ac \
     && test -f ../gas/Makefile \
     && test x$build = x$host; then
	gcc_cv_as=../gas/as-new$build_exeext
elif test -x as$build_exeext; then
	# Build using assembler in the current directory.
	gcc_cv_as=./as$build_exeext
elif ( set dummy $AS_FOR_TARGET; test -x $[2] ); then
        gcc_cv_as="$AS_FOR_TARGET"
else
        AC_PATH_PROG(gcc_cv_as, $AS_FOR_TARGET)
fi])

AS_VAR_SET_IF(gcc_cv_nm,, [
if test -f $gcc_cv_binutils_srcdir/configure.ac \
     && test -f ../binutils/Makefile \
     && test x$build = x$host; then
	gcc_cv_nm=../binutils/nm-new$build_exeext
elif test -x nm$build_exeext; then
	gcc_cv_nm=./nm$build_exeext
elif ( set dummy $NM_FOR_TARGET; test -x $[2] ); then
        gcc_cv_nm="$NM_FOR_TARGET"
else
        AC_PATH_PROG(gcc_cv_nm, $NM_FOR_TARGET)
fi])

AS_VAR_SET_IF(gcc_cv_dsymutil,, [
if test -x "$DEFAULT_DSYMUTIL"; then
    gcc_cv_dsymutil="$DEFAULT_DSYMUTIL"
elif test -x dsymutil$build_exeext; then
    gcc_cv_dsymutil=./dsymutil$build_exeext
elif ( set dummy $DSYMUTIL_FOR_TARGET; test -x $[2] ); then
    gcc_cv_dsymutil=$DSYMUTIL_FOR_TARGET
elif ( set dummy $DSYMUTIL; test -x $[2] ); then
    gcc_cv_dsymutil=$DSYMUTIL
else
    AC_PATH_PROG(gcc_cv_dsymutil, $DSYMUTIL_FOR_TARGET)
fi])
