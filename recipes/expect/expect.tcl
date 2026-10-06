# Expect for native Windows, on pipes instead of pseudo-terminals.
#
# Implements the Expect 5.45 commands that DejaGnu and the GCC and binutils
# testsuites use: spawn (programs and -open/-leaveopen channels), expect
# with -re/-gl/-ex patterns and the timeout/eof/default/full_buffer
# keywords, expect_before/expect_after, exp_continue, send and send_*,
# close, wait, exp_pid, log_file, log_user, match_max, timestamp, trap.
# A spawned program's stdin is a pipe, its stdout and stderr one pipe;
# CRLF in its output reads as LF.  There is no terminal: interact,
# fork, disconnect and overlay are not available.
#
# Expect's scoping rules hold: spawn_id and timeout are read from the
# caller's scope, then the global one; spawn and expect write spawn_id and
# expect_out in the caller's scope.

package require Tcl 8.6
package provide Expect 5.45.4

namespace eval ::exp {
    # Spawn ids: exp0 is the user (stdin and stdout), exp2 stderr.
    variable next 4
    # Per spawn id: channel, process ids, buffer, end of file seen, kind
    # (spawn: a process of ours; open: a channel to close; leaveopen: a
    # channel left open), closed by close, match_max, wait status.
    variable chan
    variable pids
    variable buf
    variable eof
    variable kind
    variable closed
    variable max
    variable status
    variable saved
    array set chan {}
    array set pids {}
    array set buf {}
    array set eof {}
    array set kind {}
    array set closed {}
    array set max {}
    array set status {}
    array set saved {}

    variable defaultMax 2000
    variable logUser 1
    variable logChan {}
    variable logOwned 0
    variable before {}
    variable after {}
    variable wake {}
    variable traps
    array set traps {}
    variable exitHandlers {}
    variable internal 0
}

# --- Spawn ids ---------------------------------------------------------

proc ::exp::NewId {ch k pidList} {
    variable next
    set id exp$next
    incr next
    set ::exp::chan($id) $ch
    set ::exp::pids($id) $pidList
    set ::exp::buf($id) {}
    set ::exp::eof($id) 0
    set ::exp::kind($id) $k
    set ::exp::closed($id) 0
    set ::exp::max($id) $::exp::defaultMax
    return $id
}

proc ::exp::Forget {id} {
    foreach v {chan pids buf eof kind closed max status saved} {
        unset -nocomplain ::exp::${v}($id)
    }
}

# The value of variable NAME as Expect reads it: from the scope at LEVEL,
# else the global one, else DEFAULT.
proc ::exp::Lookup {level name {default {}}} {
    upvar #$level $name v
    if {[info exists v]} {
        return $v
    }
    if {[info exists ::$name]} {
        return [set ::$name]
    }
    return $default
}

proc ::exp::CurrentId {level} {
    set id [Lookup $level spawn_id]
    if {$id eq {}} {
        error "no spawn id: spawn a process first or use -i"
    }
    return $id
}

# A spawn id that may be read: open, not closed.
proc ::exp::CheckOpen {id} {
    if {![info exists ::exp::chan($id)] || $::exp::closed($id)} {
        error "spawn id $id not open"
    }
}

# The spawn ids of an -i argument: a list of ids, or the name of a global
# variable holding one (indirect spawn ids).
proc ::exp::ResolveIds {spec} {
    set ids {}
    foreach id $spec {
        if {![info exists ::exp::chan($id)] && [info exists ::$id]
                && ![string match exp* $id]} {
            lappend ids {*}[set ::$id]
        } else {
            lappend ids $id
        }
    }
    return $ids
}

proc ::exp::UserChan {} {
    if {![info exists ::exp::chan(exp0)]} {
        set ::exp::chan(exp0) stdin
        set ::exp::pids(exp0) {}
        set ::exp::buf(exp0) {}
        set ::exp::eof(exp0) 0
        set ::exp::kind(exp0) user
        set ::exp::closed(exp0) 0
        set ::exp::max(exp0) $::exp::defaultMax
        fconfigure stdin -blocking 0
    }
}

# --- Logging -----------------------------------------------------------

proc ::exp::Log {s} {
    variable logChan
    if {$logChan ne {}} {
        puts -nonewline $logChan $s
        flush $logChan
    }
}

# Output of spawned processes and spawn's echo: to stdout if log_user is
# on, and to the log file.
proc ::exp::LogUser {s} {
    variable logUser
    if {$logUser} {
        puts -nonewline stdout $s
        flush stdout
    }
    Log $s
}

proc ::exp::Diag {s} {
    variable internal
    if {$internal} {
        puts stderr $s
    }
}

# --- Reading -----------------------------------------------------------

proc ::exp::Read {id} {
    set ch $::exp::chan($id)
    if {[catch {read $ch} data]} {
        set data {}
        set ::exp::eof($id) 1
    }
    if {$data ne {}} {
        append ::exp::buf($id) $data
        if {$::exp::kind($id) ne "user"} {
            LogUser $data
        }
    }
    if {[eof $ch]} {
        set ::exp::eof($id) 1
    }
    if {$::exp::eof($id)} {
        catch {fileevent $ch readable {}}
    }
    set ::exp::wake data
}

# Waits until one of IDS has data or end of file, or MS milliseconds have
# passed (forever if negative).  Returns "data" or "timeout".
proc ::exp::WaitFor {ids ms} {
    variable wake
    set wake {}
    set watched {}
    foreach id $ids {
        if {!$::exp::eof($id)} {
            fileevent $::exp::chan($id) readable [list ::exp::Read $id]
            lappend watched $id
        }
    }
    if {![llength $watched]} {
        return data
    }
    if {$ms >= 0} {
        set timer [after $ms {set ::exp::wake timeout}]
    }
    vwait ::exp::wake
    if {[info exists timer]} {
        after cancel $timer
    }
    foreach id $watched {
        if {[info exists ::exp::chan($id)]} {
            catch {fileevent $::exp::chan($id) readable {}}
        }
    }
    return $wake
}

# --- Pattern lists -----------------------------------------------------

# Expect's rule for a single argument: it is a list of patterns and
# actions if a newline comes before its first non-blank character.
proc ::exp::OneArgBraced {s} {
    return [regexp {^[ \t\r]*\n} $s]
}

# The words of a braced pattern list, as Expect takes them: each command
# in it (a line, with continuations) is parsed as Tcl command words in the
# scope at LEVEL, so "-i $spawn_id" is substituted while braced actions
# stay as they are.  Comment lines are skipped.
proc ::exp::BracedWords {level body} {
    set words {}
    set chunk {}
    foreach line [split $body \n] {
        append chunk $line \n
        if {![info complete $chunk]} {
            continue
        }
        set chunk [string trim $chunk]
        if {$chunk ne {} && [string index $chunk 0] ne "#"} {
            lappend words {*}[uplevel #$level "::list $chunk"]
        }
        set chunk {}
    }
    if {[string trim $chunk] ne {}} {
        error "missing close-brace in pattern list"
    }
    return $words
}

# Parses expect's arguments into cases: dicts with type (re gl ex timeout
# eof full_buffer null), pattern, body, ids, nocase, notransfer, indices.
# Returns {cases timeout}; timeout is empty unless -timeout was given.
proc ::exp::Parse {level arglist {defaultIds {}}} {
    if {[llength $arglist] == 1 && [OneArgBraced [lindex $arglist 0]]} {
        set arglist [BracedWords $level [lindex $arglist 0]]
    } elseif {[llength $arglist] == 2 && [lindex $arglist 0] eq "-brace"} {
        set arglist [BracedWords $level [lindex $arglist 1]]
    }
    set cases {}
    set timeout {}
    set ids $defaultIds
    set idsGiven 0
    set type {}
    set nocase 0
    set notransfer 0
    set indices 0
    set n [llength $arglist]
    for {set i 0} {$i < $n} {incr i} {
        set a [lindex $arglist $i]
        if {$type eq {}} {
            switch -exact -- $a {
                -re - -gl - -ex {
                    set type [string range $a 1 end]
                    continue
                }
                -nocase { set nocase 1; continue }
                -notransfer { set notransfer 1; continue }
                -indices { set indices 1; continue }
                -i {
                    set ids [ResolveIds [lindex $arglist [incr i]]]
                    set idsGiven 1
                    continue
                }
                -timeout {
                    set timeout [lindex $arglist [incr i]]
                    continue
                }
                -brace - -nobrace - -iread - -iwrite - -noindirect -
                -continue_timer {
                    continue
                }
                -- {
                    set type gl
                    continue
                }
                timeout - eof - full_buffer - null - default {
                    set ktype $a
                    set pattern {}
                }
                default {
                    if {[string match -* $a]} {
                        error "bad flag \"$a\": must be -re, -gl, -ex,\
                                -nocase, -notransfer, -indices, -i,\
                                -timeout or --"
                    }
                    set ktype gl
                    set pattern $a
                }
            }
        } else {
            set ktype $type
            set pattern $a
        }
        set body [lindex $arglist [incr i]]
        if {$ids eq {} && !$idsGiven && $ktype ne "timeout"} {
            set ids [CurrentId $level]
        }
        foreach t [expr {$ktype eq "default" ? {timeout eof} : [list $ktype]}] {
            lappend cases [dict create type $t pattern $pattern body $body \
                    ids $ids nocase $nocase notransfer $notransfer \
                    indices $indices]
        }
        set type {}
        set nocase 0
        set notransfer 0
        set indices 0
    }
    return [list $cases $timeout]
}

# --- Matching ----------------------------------------------------------

# Expect's glob match: unanchored unless the pattern starts with ^ or ends
# with $; the earliest match, the shortest from there (a trailing * takes
# the rest).  Returns {start end} or {}.
proc ::exp::GlobMatch {pattern s nocase} {
    set opt [expr {$nocase ? {-nocase} : {}}]
    set atStart 0
    set atEnd 0
    if {[string index $pattern 0] eq "^"} {
        set atStart 1
        set pattern [string range $pattern 1 end]
    }
    if {[string index $pattern end] eq "\$"
            && [string index $pattern end-1] ne "\\"} {
        set atEnd 1
        set pattern [string range $pattern 0 end-1]
    }
    set head [expr {$atStart ? {} : {*}}]
    set tail [expr {$atEnd ? {} : {*}}]
    if {![string match {*}$opt $head$pattern$tail $s]} {
        return {}
    }
    set len [string length $s]
    set greedy [expr {$atEnd || ([string index $pattern end] eq "*"
            && [string index $pattern end-1] ne "\\")}]
    set lastStart [expr {$atStart ? 0 : $len}]
    for {set b 0} {$b <= $lastStart} {incr b} {
        set rest [string range $s $b end]
        if {![string match {*}$opt $pattern$tail $rest]} {
            continue
        }
        if {$greedy} {
            if {[string match {*}$opt $pattern $rest]} {
                return [list $b [expr {$len - 1}]]
            }
            continue
        }
        for {set e [expr {$b - 1}]} {$e < $len} {incr e} {
            if {[string match {*}$opt $pattern [string range $s $b $e]]} {
                return [list $b $e]
            }
        }
    }
    return {}
}

# Tries CASE against the buffer of ID.  On a match, returns a dict with
# the matched range and the strings and indices for expect_out.
proc ::exp::TryCase {case id} {
    set s $::exp::buf($id)
    set pattern [dict get $case pattern]
    set nocase [dict get $case nocase]
    switch -- [dict get $case type] {
        re {
            set opts [list -indices -inline]
            if {$nocase} {
                lappend opts -nocase
            }
            if {[catch {regexp {*}$opts -- $pattern $s} m]} {
                error "bad regular expression \"$pattern\": $m"
            }
            if {![llength $m]} {
                return {}
            }
            return [list range [lindex $m 0] groups [lrange $m 0 9]]
        }
        gl {
            set r [GlobMatch $pattern $s $nocase]
            if {$r eq {}} {
                return {}
            }
            return [list range $r groups [list $r]]
        }
        ex {
            if {$nocase} {
                set b [string first [string tolower $pattern] \
                        [string tolower $s]]
            } else {
                set b [string first $pattern $s]
            }
            if {$b < 0} {
                return {}
            }
            set r [list $b [expr {$b + [string length $pattern] - 1}]]
            return [list range $r groups [list $r]]
        }
    }
    return {}
}

# Sets expect_out (in the scope at LEVEL) for a pattern match and takes
# the matched text out of the buffer.
proc ::exp::RecordMatch {level case id m} {
    upvar #$level expect_out out
    set s $::exp::buf($id)
    set n 0
    foreach r [dict get $m groups] {
        lassign $r b e
        set out($n,string) [expr {$b < 0 ? {} : [string range $s $b $e]}]
        if {[dict get $case indices]} {
            set out($n,start) $b
            set out($n,end) $e
        }
        incr n
    }
    set end [lindex [dict get $m range] 1]
    set out(buffer) [string range $s 0 $end]
    set out(spawn_id) $id
    if {![dict get $case notransfer]} {
        set ::exp::buf($id) [string range $s [expr {$end + 1}] end]
    }
}

# Sets expect_out for eof and full_buffer: the whole buffer.
proc ::exp::RecordAll {level id} {
    upvar #$level expect_out out
    set out(buffer) $::exp::buf($id)
    set out(spawn_id) $id
    set ::exp::buf($id) {}
}

proc ::exp::Expect {level arglist {only {}}} {
    variable before
    variable after
    lassign [Parse $level $arglist $only] cases timeout
    if {$timeout eq {}} {
        set timeout [Lookup $level timeout 10]
    }
    if {![string is double -strict $timeout]} {
        error "expected a number for timeout but got \"$timeout\""
    }
    # The spawn ids to watch, and the cases that apply to them.
    set ids {}
    foreach c $cases {
        foreach id [dict get $c ids] {
            if {$id ni $ids} {
                lappend ids $id
            }
        }
    }
    if {![llength $cases] && $only ne {}} {
        set ids $only
    }
    if {![llength $ids]} {
        set ids [list [CurrentId $level]]
    }
    foreach id $ids {
        if {$id eq "exp0"} {
            UserChan
        }
        CheckOpen $id
    }
    set all {}
    foreach c [concat $before $cases $after] {
        set cids {}
        foreach id [dict get $c ids] {
            if {$id in $ids} {
                lappend cids $id
            }
        }
        if {[llength $cids] || [dict get $c type] eq "timeout"} {
            lappend all [dict replace $c ids $cids]
        }
    }

    set start [clock milliseconds]
    while 1 {
        set hit {}
        # Patterns, in order, against each id's buffer.
        foreach c $all {
            set type [dict get $c type]
            if {$type ni {re gl ex}} {
                continue
            }
            foreach id [dict get $c ids] {
                set m [TryCase $c $id]
                if {$m ne {}} {
                    Diag "expect: \"[dict get $c pattern]\" matched on $id"
                    RecordMatch $level $c $id $m
                    set hit $c
                    break
                }
            }
            if {$hit ne {}} {
                break
            }
        }
        # A full buffer: full_buffer, or the oldest half goes.
        if {$hit eq {}} {
            foreach id $ids {
                if {[string length $::exp::buf($id)] > 2 * $::exp::max($id)} {
                    foreach c $all {
                        if {[dict get $c type] eq "full_buffer"
                                && $id in [dict get $c ids]} {
                            RecordAll $level $id
                            set hit $c
                            break
                        }
                    }
                    if {$hit ne {}} {
                        break
                    }
                    set ::exp::buf($id) \
                            [string range $::exp::buf($id) end-[expr {$::exp::max($id) - 1}] end]
                }
            }
        }
        # End of file on an id.
        if {$hit eq {}} {
            foreach id $ids {
                if {!$::exp::eof($id)} {
                    continue
                }
                foreach c $all {
                    if {[dict get $c type] eq "eof" && $id in [dict get $c ids]} {
                        RecordAll $level $id
                        set hit $c
                        break
                    }
                }
                if {$hit eq {}} {
                    # No eof pattern: expect returns.
                    upvar #$level expect_out out
                    set out(buffer) $::exp::buf($id)
                    set out(spawn_id) $id
                    set ::exp::buf($id) {}
                    return {}
                }
                break
            }
        }
        # Time out.
        if {$hit eq {}} {
            if {$timeout < 0} {
                set left -1
            } else {
                set left [expr {int($start + $timeout * 1000
                        - [clock milliseconds])}]
            }
            if {$timeout >= 0 && $left <= 0} {
                foreach c $all {
                    if {[dict get $c type] eq "timeout"} {
                        set hit $c
                        break
                    }
                }
                if {$hit eq {}} {
                    return {}
                }
            } else {
                WaitFor $ids $left
                continue
            }
        }

        set body [dict get $hit body]
        if {$body eq {}} {
            return {}
        }
        set code [catch {uplevel #$level $body} result opts]
        switch -- $code {
            0 {
                return $result
            }
            101 {
                # exp_continue
                set start [clock milliseconds]
                continue
            }
            102 {
                # exp_continue -continue_timer
                continue
            }
            default {
                # Out of ::exp::Expect and the expect command that called it.
                dict incr opts -level 2
                return -options $opts $result
            }
        }
    }
}

# --- Commands ----------------------------------------------------------

proc expect {args} {
    ::exp::Expect [expr {[info level] - 1}] $args
}

proc expect_user {args} {
    ::exp::Expect [expr {[info level] - 1}] $args exp0
}

proc expect_tty {args} {
    ::exp::Expect [expr {[info level] - 1}] $args exp0
}

proc exp_continue {args} {
    if {"-continue_timer" in $args} {
        return -code 102
    }
    return -code 101
}

# expect_before and expect_after: patterns tried before and after those
# of every expect on their spawn ids.  Without patterns, the ones of the
# given ids are removed.
proc ::exp::BeforeAfter {which level arglist} {
    if {[lindex $arglist 0] eq "-info"} {
        return {}
    }
    set ids {}
    if {[lindex $arglist 0] eq "-i"} {
        set ids [ResolveIds [lindex $arglist 1]]
        set rest [lrange $arglist 2 end]
    } else {
        catch {set ids [list [CurrentId $level]]}
        set rest $arglist
    }
    if {[llength $rest] == 1 && [OneArgBraced [lindex $rest 0]]} {
        set rest [BracedWords $level [lindex $rest 0]]
    }
    # Drop the old cases for these ids.
    set kept {}
    foreach c [set ::exp::$which] {
        set left {}
        foreach id [dict get $c ids] {
            if {$id ni $ids} {
                lappend left $id
            }
        }
        if {[llength $left] || ([dict get $c type] eq "timeout"
                && ![llength $rest])} {
            lappend kept [dict replace $c ids $left]
        }
    }
    if {[llength $rest]} {
        lassign [Parse $level [list -i $ids {*}$rest]] cases
        # Bodies run in the scope of the expect that matches them; they
        # are usually commands with no local variables.
        lappend kept {*}$cases
    }
    set ::exp::$which $kept
    return {}
}

proc expect_before {args} {
    ::exp::BeforeAfter before [expr {[info level] - 1}] $args
}

proc expect_after {args} {
    ::exp::BeforeAfter after [expr {[info level] - 1}] $args
}

proc spawn {args} {
    set level [expr {[info level] - 1}]
    set echo 1
    set ch {}
    set k spawn
    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        switch -exact -- $a {
            -noecho { set echo 0 }
            -console - -nottycopy - -nottyinit - -pty {}
            -ignore { incr i }
            -open { set ch [lindex $args [incr i]]; set k open }
            -leaveopen { set ch [lindex $args [incr i]]; set k leaveopen }
            -- { incr i; break }
            default { break }
        }
        incr i
    }
    set cmd [lrange $args $i end]
    if {$echo} {
        ::exp::LogUser "spawn [join $args]\n"
    }
    if {$ch ne {}} {
        if {[catch {pid $ch} pidList]} {
            set pidList {}
        }
        # The channel's own settings come back when the spawn id is
        # closed: its owner may still read it or close it blocking (and
        # get the pipeline's status).
        set saved {}
        foreach opt {-blocking -buffering -translation -eofchar} {
            lappend saved $opt [fconfigure $ch $opt]
        }
        fconfigure $ch -blocking 0 -buffering none -translation {crlf lf} \
                -eofchar {}
        set id [::exp::NewId $ch $k $pidList]
        set ::exp::saved($id) $saved
        set result 0
    } else {
        if {![llength $cmd]} {
            error "usage: spawn ?options? program ?args?"
        }
        if {[catch {open |[list {*}$cmd 2>@1] r+} ch]} {
            # As a forked child that cannot exec: the message is the
            # program's output, and it exits with status 255.
            set id [::exp::NewId {} spawn {}]
            set ::exp::buf($id) "$ch\n"
            set ::exp::eof($id) 1
            set ::exp::status($id) [list 0 $id 0 255]
            set result 0
        } else {
            fconfigure $ch -blocking 0 -buffering none \
                    -translation {crlf lf} -eofchar {} \
                    -encoding [encoding system]
            set id [::exp::NewId $ch spawn [pid $ch]]
            set result [lindex [pid $ch] 0]
        }
    }
    upvar #$level spawn_id sid
    set sid $id
    return $result
}

proc ::exp::OptionI {level arglist} {
    set id {}
    set rest {}
    for {set i 0} {$i < [llength $arglist]} {incr i} {
        set a [lindex $arglist $i]
        if {$a eq "-i"} {
            set id [lindex $arglist [incr i]]
        } else {
            lappend rest $a
        }
    }
    if {$id eq {}} {
        set id [CurrentId $level]
    }
    return [list $id $rest]
}

# The string argument of send and send_*: the last one, after the options
# (an argument after -- is never an option).
proc ::exp::SendArgs {arglist} {
    set id {}
    for {set i 0} {$i < [llength $arglist]} {incr i} {
        set a [lindex $arglist $i]
        switch -exact -- $a {
            -i { set id [lindex $arglist [incr i]] }
            -s - -h - -raw - -null - -break {}
            -- { incr i; break }
            default { break }
        }
    }
    return [list $id [join [lrange $arglist $i end]]]
}

proc send {args} {
    lassign [::exp::SendArgs $args] id s
    if {$id eq {}} {
        set id [::exp::CurrentId [expr {[info level] - 1}]]
    }
    switch -- $id {
        exp0 - exp1 {
            puts -nonewline stdout $s
            flush stdout
            return
        }
        exp2 {
            puts -nonewline stderr $s
            flush stderr
            return
        }
    }
    ::exp::CheckOpen $id
    set ch $::exp::chan($id)
    if {$ch eq {}} {
        error "write(spawn_id=$id): broken pipe"
    }
    if {[catch {puts -nonewline $ch $s; flush $ch} msg]} {
        error "write(spawn_id=$id): $msg"
    }
    return
}

proc send_user {args} {
    lassign [::exp::SendArgs $args] id s
    puts -nonewline stdout $s
    flush stdout
    ::exp::Log $s
}

proc send_error {args} {
    lassign [::exp::SendArgs $args] id s
    puts -nonewline stderr $s
    flush stderr
    ::exp::Log $s
}

proc send_log {args} {
    lassign [::exp::SendArgs $args] id s
    ::exp::Log $s
}

proc send_tty {args} {
    lassign [::exp::SendArgs $args] id s
    puts -nonewline stdout $s
    flush stdout
}

# Expect's close: with -i or no arguments it closes a spawn id; anything
# else is Tcl's close.
rename close ::exp::tclClose
proc close {args} {
    set level [expr {[info level] - 1}]
    if {[llength $args] && [lindex $args 0] ni {-i -slave -onexec}} {
        return [uplevel 1 [list ::exp::tclClose {*}$args]]
    }
    lassign [::exp::OptionI $level $args] id
    if {$id eq {}} {
        error "no spawn id"
    }
    ::exp::CheckOpen $id
    ::exp::CloseId $id
    return {}
}

# Closes the connection to ID.  A spawned program's stdin is closed (it
# sees end of file); its output is read and dropped in the background
# until it exits, so that it cannot block on a full pipe, and wait
# collects its status.
proc ::exp::CloseId {id} {
    set ::exp::closed($id) 1
    set ch $::exp::chan($id)
    set ::exp::buf($id) {}
    if {$ch eq {}} {
        return
    }
    catch {fileevent $ch readable {}}
    switch -- $::exp::kind($id) {
        spawn {
            catch {chan close $ch write}
            if {$::exp::eof($id)} {
                Reap $id
            } else {
                fileevent $ch readable [list ::exp::Drain $id]
            }
        }
        open {
            catch {::exp::tclClose $ch}
            set ::exp::chan($id) {}
        }
        leaveopen {
            catch {fconfigure $ch {*}$::exp::saved($id)}
            set ::exp::chan($id) {}
        }
    }
}

proc ::exp::Drain {id} {
    set ch $::exp::chan($id)
    if {[catch {read $ch}] || [eof $ch]} {
        Reap $id
    }
}

# Closes a spawned program's channel and records its wait status:
# {pid id 0 status} or {pid id 0 0 CHILDKILLED SIGNAL message}.
proc ::exp::Reap {id} {
    set ch $::exp::chan($id)
    if {$ch eq {}} {
        return
    }
    set pid [lindex $::exp::pids($id) 0]
    catch {fileevent $ch readable {}}
    fconfigure $ch -blocking 1
    catch {read $ch}
    set code [catch {::exp::tclClose $ch} msg opts]
    set ::exp::chan($id) {}
    set st [list $pid $id 0 0]
    if {$code} {
        set ec [dict get $opts -errorcode]
        switch -- [lindex $ec 0] {
            CHILDSTATUS {
                set st [list $pid $id 0 [lindex $ec 2]]
            }
            CHILDKILLED {
                set st [list $pid $id 0 0 CHILDKILLED [lindex $ec 2] \
                        [lindex $ec 3]]
            }
            POSIX {
                set st [list $pid $id -1 [lindex $ec 1]]
            }
        }
    }
    set ::exp::status($id) $st
}

proc wait {args} {
    set level [expr {[info level] - 1}]
    set nowait [expr {"-nowait" in $args}]
    set args [lsearch -all -inline -not -exact $args -nowait]
    lassign [::exp::OptionI $level $args] id
    if {![info exists ::exp::chan($id)]} {
        error "no such spawn id: $id"
    }
    if {$::exp::kind($id) ne "spawn"} {
        set st [list -1 $id 0 0]
        ::exp::Forget $id
        return $st
    }
    if {!$::exp::closed($id)} {
        ::exp::CloseId $id
    }
    if {![info exists ::exp::status($id)]} {
        if {$nowait} {
            return [list [lindex $::exp::pids($id) 0] $id 0 0]
        }
        ::exp::Reap $id
    }
    set st $::exp::status($id)
    if {[llength $st] == 4 && [lindex $st 0] eq {}} {
        set st [lreplace $st 0 0 0]
    }
    ::exp::Forget $id
    return $st
}

proc exp_pid {args} {
    lassign [::exp::OptionI [expr {[info level] - 1}] $args] id
    if {![info exists ::exp::pids($id)]} {
        error "no such spawn id: $id"
    }
    set pid [lindex $::exp::pids($id) 0]
    return [expr {$pid eq {} ? 0 : $pid}]
}

# Kills the processes of spawn id ID (or PID, a process id) and their
# children: there are no signals or process groups on Windows.
proc exp_kill {args} {
    set level [expr {[info level] - 1}]
    set pidList {}
    if {[llength $args] == 1 && [string is integer -strict [lindex $args 0]]} {
        set pidList $args
    } else {
        lassign [::exp::OptionI $level $args] id
        if {[info exists ::exp::pids($id)]} {
            set pidList $::exp::pids($id)
        }
    }
    foreach pid $pidList {
        catch {exec taskkill /F /T /PID $pid >NUL 2>NUL}
    }
    return {}
}

proc exp_open {args} {
    set leave [expr {"-leaveopen" in $args}]
    set args [lsearch -all -inline -not -exact $args -leaveopen]
    lassign [::exp::OptionI [expr {[info level] - 1}] $args] id
    ::exp::CheckOpen $id
    set ch $::exp::chan($id)
    fconfigure $ch -blocking 1
    if {!$leave} {
        ::exp::Forget $id
    }
    return $ch
}

proc log_file {args} {
    variable ::exp::logChan
    set append 1
    set file {}
    set ch {}
    set leave 0
    for {set i 0} {$i < [llength $args]} {incr i} {
        set a [lindex $args $i]
        switch -exact -- $a {
            -a {}
            -noappend { set append 0 }
            -info {
                return [expr {$::exp::logChan eq {} ? {} : $::exp::logChan}]
            }
            -open { set ch [lindex $args [incr i]] }
            -leaveopen { set ch [lindex $args [incr i]]; set leave 1 }
            default { set file $a }
        }
    }
    if {$::exp::logChan ne {} && $::exp::logOwned} {
        catch {::exp::tclClose $::exp::logChan}
    }
    set ::exp::logChan {}
    set ::exp::logOwned 0
    if {$ch ne {}} {
        set ::exp::logChan $ch
        set ::exp::logOwned [expr {!$leave}]
    } elseif {$file ne {}} {
        set ::exp::logChan [open $file [expr {$append ? "a" : "w"}]]
        set ::exp::logOwned 1
    }
    return {}
}

proc log_user {args} {
    if {[lindex $args 0] eq "-info" || ![llength $args]} {
        return $::exp::logUser
    }
    set old $::exp::logUser
    set ::exp::logUser [expr {[lindex $args 0] ? 1 : 0}]
    return $old
}

proc match_max {args} {
    set dflt 0
    set id {}
    set size {}
    for {set i 0} {$i < [llength $args]} {incr i} {
        set a [lindex $args $i]
        switch -exact -- $a {
            -d { set dflt 1 }
            -i { set id [lindex $args [incr i]] }
            default { set size $a }
        }
    }
    if {$dflt} {
        if {$size eq {}} {
            return $::exp::defaultMax
        }
        set ::exp::defaultMax $size
        return {}
    }
    if {$id eq {}} {
        set id [::exp::Lookup [expr {[info level] - 1}] spawn_id]
    }
    if {$id eq {} || ![info exists ::exp::max($id)]} {
        if {$size eq {}} {
            return $::exp::defaultMax
        }
        set ::exp::defaultMax $size
        return {}
    }
    if {$size eq {}} {
        return $::exp::max($id)
    }
    set ::exp::max($id) $size
    return {}
}

proc exp_internal {args} {
    set args [lsearch -all -inline -not -exact $args -info]
    if {[lindex $args 0] eq "-f"} {
        set args [lrange $args 2 end]
    }
    if {[llength $args]} {
        set ::exp::internal [expr {[lindex $args end] ? 1 : 0}]
    }
    return $::exp::internal
}

proc timestamp {args} {
    set seconds [clock seconds]
    set format {}
    set gmt 0
    for {set i 0} {$i < [llength $args]} {incr i} {
        switch -exact -- [lindex $args $i] {
            -seconds { set seconds [lindex $args [incr i]] }
            -format { set format [lindex $args [incr i]] }
            -gmt { set gmt 1 }
        }
    }
    if {$format eq {}} {
        return $seconds
    }
    return [clock format $seconds -format $format -gmt $gmt]
}

# trap: actions are recorded, but no signal reaches them (Windows has
# none to deliver; Ctrl-C ends the program).
proc trap {args} {
    set opts {}
    while {[string match -* [lindex $args 0]]} {
        lappend opts [lindex $args 0]
        set args [lrange $args 1 end]
    }
    if {"-name" in $opts || "-number" in $opts} {
        return {}
    }
    if {"-max" in $opts} {
        return 65
    }
    if {[llength $args] == 1} {
        set sig [lindex $args 0]
        return [expr {[info exists ::exp::traps($sig)] ? $::exp::traps($sig) : {}}]
    }
    lassign $args action sigs
    foreach sig $sigs {
        set ::exp::traps($sig) $action
    }
    return {}
}

proc sleep {seconds} {
    after [expr {int($seconds * 1000)}]
}

proc exp_version {args} {
    return 5.45.4
}

proc strace {args} {
    return {}
}

proc debug {args} {
    return 0
}

proc stty {args} {
    return {}
}

proc remove_nulls {args} {
    return 0
}

proc parity {args} {
    return 0
}

# system: runs its arguments as a shell command line.
proc system {args} {
    set code [catch {exec sh -c [join $args] >@stdout 2>@stderr <@stdin} \
            msg opts]
    if {$code} {
        set ec [dict get $opts -errorcode]
        if {[lindex $ec 0] eq "CHILDSTATUS"} {
            return [lindex $ec 2]
        }
        return -options $opts $msg
    }
    return 0
}

foreach cmd {interact fork disconnect overlay interpreter inter_return} {
    proc $cmd {args} [list error "$cmd is not available on Windows"]
}

# exit: runs the -onexit handlers, closes the log, then exits.
rename exit ::exp::tclExit
proc exit {args} {
    set noexit 0
    for {set i 0} {$i < [llength $args]} {incr i} {
        switch -exact -- [lindex $args $i] {
            -onexit {
                if {$i + 1 < [llength $args]} {
                    lappend ::exp::exitHandlers [lindex $args [incr i]]
                    return {}
                }
                return [join $::exp::exitHandlers \n]
            }
            -noexit { set noexit 1 }
            default { break }
        }
    }
    set status [expr {$i < [llength $args] ? [lindex $args $i] : 0}]
    foreach h $::exp::exitHandlers {
        catch {uplevel #0 $h}
    }
    if {$noexit} {
        return {}
    }
    if {$::exp::logChan ne {} && $::exp::logOwned} {
        catch {::exp::tclClose $::exp::logChan}
    }
    ::exp::tclExit $status
}

# The exp_ names of all commands.
foreach cmd {spawn expect expect_before expect_after expect_user expect_tty
        send send_user send_error send_log send_tty close wait exp_pid
        log_file log_user match_max timestamp trap sleep strace debug stty
        remove_nulls parity system interact fork disconnect overlay
        interpreter inter_return exit} {
    interp alias {} exp_$cmd {} $cmd
}
interp alias {} exp_exp_internal {} exp_internal

# Expect starts with a global timeout of 10 seconds; DejaGnu reads it.
if {![info exists ::timeout]} {
    set ::timeout 10
}
set ::user_spawn_id exp0
set ::error_spawn_id exp2
set ::tty_spawn_id exp0
set ::any_spawn_id exp_any
if {![info exists ::exp_library]} {
    set ::exp_library [file dirname [info script]]
}
set ::exp_exec_library $::exp_library
