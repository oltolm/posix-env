# Checks posix-env's Tcl patches; run by the recipe's test as
# "tclsh test.tcl".  Prints "ok" at the end; any failure is an error.

proc check {what got want} {
    if {$got ne $want} {
        error "$what: got \"$got\", want \"$want\""
    }
}

# UTF-8 is the active code page (patch 0006): the system encoding, and
# arguments arrive intact.
check "system encoding" [encoding system] utf-8

# Channels write LF (patch 0002).
set f [open lf.txt w]
puts $f line
close $f
set f [open lf.txt rb]
check "line ending" [read $f] "line\n"
close $f

# A ^Z in a file or a pipe is data (patch 0005).
set f [open z.txt wb]
puts -nonewline $f "a\x1ab"
close $f
set f [open z.txt r]
check "^Z in a file" [read $f] "a\x1ab"
close $f
check "^Z in a pipe" [exec printf {a\032b}] "a\x1ab"

# /dev/null is the NUL device, in open and in exec redirections (0003).
set f [open /dev/null w]
puts $f discarded
close $f
check "exec > /dev/null" [exec printf x > /dev/null] ""
check "exec < /dev/null" [exec cat < /dev/null] ""
check "file exists /dev/null" [file exists /dev/null] 1
check "source /dev/null" [source /dev/null] ""

# #! scripts run through their interpreter (patch 0004): by file name in
# PATH, through /usr/bin/env, with an argument, in pipelines.
set f [open script w]
puts $f "#!/bin/sh"
puts $f {echo "$# $1"}
close $f
check "#!/bin/sh" [exec ./script "a b"] "1 a b"
set f [open |[list ./script x] r]
check "open |script" [read -nonewline $f] "1 x"
close $f
set f [open script2 w]
puts $f "#!/usr/bin/env sh"
puts $f {echo env}
close $f
check "#!/usr/bin/env" [exec ./script2] env
set f [open script3 w]
puts $f "#!/bin/sh -e"
puts $f {false; echo not reached}
close $f
check "#! argument" [catch {exec ./script3} msg] 1

# A symbolic link to a #! script (if links can be made here).
if {![catch {file link -symbolic scriptlink [file normalize script]}]} {
    check "symlink to #!" [exec ./scriptlink y] "1 y"
}

# /bin/NAME and /usr/bin/NAME are NAME in PATH, as on #! lines.
check "exec /bin/sh" [exec /bin/sh -c {echo bin}] bin
check "exec /usr/bin/env" [exec /usr/bin/env printf usr] usr

# Empty environment variables exist, here and in child processes (0007).
set env(POSIX_ENV_EMPTY) ""
check "empty variable" [info exists env(POSIX_ENV_EMPTY)]-$env(POSIX_ENV_EMPTY) 1-
check "empty variable in a child" \
        [exec sh -c {echo "${POSIX_ENV_EMPTY-unset}."}] .
unset env(POSIX_ENV_EMPTY)
check "unset variable in a child" \
        [exec sh -c {echo "${POSIX_ENV_EMPTY-unset}"}] unset

# An open file can be deleted (0008).
set f [open open.txt w]
file delete open.txt
check "delete an open file" [file exists open.txt] 0
close $f

puts ok
