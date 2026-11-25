use strict;
use warnings;
use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex);
use File::Basename qw(dirname);
use File::Copy qw(copy);
use File::Find ();
use File::Path qw(make_path);
use File::Spec ();
use File::Temp qw(tempdir);
use FindBin ();
use Test::More;

my $program = abs_path(shift // "$FindBin::Bin/../posix-env-prepare");
die "Set TEMP to a writable temporary directory\n" unless $ENV{TEMP};
my $scratch = tempdir('posix-env-prepare-test-XXXXXXXX', DIR => $ENV{TEMP}, CLEANUP => 1);

sub read_file {
    open my $fh, '<:raw', $_[0] or die "$_[0]: $!";
    local $/;
    return <$fh>;
}
sub write_file {
    my ($path, $text) = @_;
    make_path(dirname($path));
    open my $fh, '>:raw', $path or die "$path: $!";
    print {$fh} $text or die "$path: $!";
    close $fh or die "$path: $!";
}
sub fixture {
    my ($project, $name) = @_;
    my $from = "$FindBin::Bin/fixtures/$project";
    my $to = "$scratch/$name";
    File::Find::find({ no_chdir => 1, wanted => sub {
        return unless -f $File::Find::name;
        my $relative = File::Spec->abs2rel($File::Find::name, $from);
        write_file("$to/$relative", read_file($File::Find::name));
    }}, $from);
    return $to;
}
sub snapshot {
    my ($dir) = @_;
    my %hashes;
    File::Find::find({ no_chdir => 1, wanted => sub {
        return unless -f $File::Find::name;
        my $relative = File::Spec->abs2rel($File::Find::name, $dir);
        $hashes{$relative} = sha256_hex(read_file($File::Find::name));
    }}, $dir);
    return \%hashes;
}
sub run_prepare {
    my (@args) = @_;
    open my $pipe, '-|', $^X, $program, @args or die "Cannot start prepare: $!";
    local $/;
    my $output = <$pipe>;
    close $pipe;
    return ($? >> 8, $output);
}

sub run_shell {
    my ($script) = @_;
    my $path = "$scratch/behavior.sh";
    write_file($path, $script);
    open my $pipe, '-|', ($ENV{CONFIG_SHELL} || 'sh'), $path or die "Cannot start shell: $!";
    local $/;
    my $output = <$pipe>;
    close $pipe;
    return ($? >> 8, $output);
}

my ($status, $output) = run_prepare('--help');
is($status, 0, 'help succeeds');
like($output, qr/--dry-run/, 'help describes dry run');
($status, $output) = run_prepare('--version');
is($status, 0, 'version succeeds');
like($output, qr/posix-env-prepare 0\.1\.0/, 'tool version');

for my $project (qw(gcc binutils)) {
    my $tree = fixture($project, "$project source with spaces");
    write_file("$tree/unrelated.txt", "keep\r\n\x1a\0\xff");
    # A bundled dependency also carries its own copies of the build tools.
    write_file("$tree/dependency/ltmain.sh", read_file("$tree/ltmain.sh"));
    my $before = snapshot($tree);
    ($status, $output) = run_prepare('--dry-run', $tree);
    is($status, 0, "$project dry run succeeds");
    like($output, qr/\($project [0-9]/, "$project detected from source version file");
    is_deeply(snapshot($tree), $before, "$project dry run preserves every byte");
    ($status, $output) = run_prepare($tree);
    is($status, 0, "$project preparation succeeds");
    like($output, qr/dependency\/ltmain\.sh/, 'bundled Libtool processed');
    my $lt = read_file("$tree/ltmain.sh");
    like($lt, qr/find_executable \(_pgmptr\)/, 'wrapper finds its executable');
    like($lt, qr/GetFinalPathNameByHandleA/, 'wrapper follows Windows symlinks');
    unlike($lt, qr/cmd \/\/c/, 'native path conversion avoids MSYS command syntax');
    like($lt, qr/fixture tail: preserve this/, 'unrelated text survives');
    is(read_file("$tree/unrelated.txt"), "keep\r\n\x1a\0\xff", 'unrelated binary file untouched');
    like(read_file("$tree/config/po.m4"), qr/\[A-Za-z\]:/, 'gettext macro accepts drive paths');
    like(read_file("$tree/configure"), qr/\[A-Za-z\]:/, 'generated configure accepts drive paths');
    if ($project eq 'gcc') {
        like(read_file("$tree/libgcc/Makefile.in"), qr/SHLIB_DLLDIR=\//, 'libgcc DLL copied to build directory');
        unlike(read_file("$tree/libgcc/Makefile.in"), qr/bindir=|toolexeclibdir=/, 'libgcc install-leaf overrides only SHLIB_DLLDIR');
        like(read_file("$tree/gcc/testsuite/lib/target-libpath.exp"), qr/set sep ";"/, 'native test PATH separator');
        like(read_file("$tree/gcc/testsuite/lib/gcc-defs.exp"), qr/set libgcc_s "libgcc_s\.a"/, 'test driver locates MinGW import library');
        for my $file (qw(configure.ac configure)) {
            my $text = read_file("$tree/gcc/$file");
            unlike($text, qr/set dummy \$\w+; test -x/, "gcc/$file tests no bare tool name");
            is(scalar(() = $text =~ /\*\/\* \| \*\\\\\*\) test -x/g), 4, "gcc/$file tests only tool paths");
        }
        # The build directory holds the nm exec-tool wrapper.  The bare name
        # passed by the top-level Makefile must be searched for in PATH.
        my ($condition) = read_file("$tree/gcc/configure") =~ /^elif (\( set dummy \$NM_FOR_TARGET\b.*?\)); then$/ms;
        ok(defined $condition, 'nm probe found in gcc/configure');
        make_path("$scratch/nm-probe");
        write_file("$scratch/nm-probe/nm", "#! /bin/sh\nexec nm \"\$\@\"\n");
        ($status, $output) = run_shell(<<SH);
cd '$scratch/nm-probe' || exit 1
for NM_FOR_TARGET in 'nm  ' "\$PWD/nm"; do
  if $condition; then echo direct; else echo search; fi
done
SH
        is($output, "search\ndirect\n", 'nm probe searches PATH for a bare name and takes a path directly');
    } else {
        like(read_file("$tree/ld/testsuite/config/default.exp"), qr/^\tliblto_plugin\.dll$/m, 'native LTO plugin discovered');
        like(read_file("$tree/ld/testsuite/ld-bootstrap/bootstrap.exp"), qr/!\[istarget "\*-\*-mingw\*"\]/, 'bootstrap omits libdl on MinGW');
    }
    my $prepared = snapshot($tree);
    ($status, $output) = run_prepare($tree);
    is($status, 0, "$project second run succeeds");
    like($output, qr/already applied:/, 'already applied patches reported');
    like($output, qr/^0 file\(s\) changed\./m, 'second run changes nothing');
    is_deeply(snapshot($tree), $prepared, 'second run preserves every byte');

    # Regenerating one file must not require a stamp file to be removed.
    write_file("$tree/configure", read_file("$FindBin::Bin/fixtures/$project/configure"));
    ($status, $output) = run_prepare($tree);
    is($status, 0, 'regenerated configure can be prepared again');
    is_deeply(snapshot($tree), $prepared, 'regenerated file restored to prepared content');

    if ($project eq 'gcc') {
        # Rename the functions so brush's existing compatibility substitutions
        # cannot hide a defect in the source changes made by prepare.
        my $functions = read_file("$tree/ltmain.sh");
        $functions =~ s/^(func_normal_abspath|func_to_host_path|func_to_host_pathlist|func_emit_cwrapperexe_src)(?= \(\))/test_$1/gm;
        my $preamble = <<'SH';
ECHO=echo
SED=sed
host=x86_64-w64-mingw32
build=$host
pathcar='s,^/\([^/]*\).*$,\1,'
pathcdr='s,^/[^/]*,,'
removedotparts='s,/\./,/,g'
collapseslashes='s@/\{1,\}@/@g'
finalslash='s,/*$,/,'
func_dirname () { func_dirname_result=${1%/*}; }
func_stripname () {
  func_stripname_result=$3
  test -z "$1" || func_stripname_result=${func_stripname_result#"$1"}
  test -z "$2" || func_stripname_result=${func_stripname_result%"$2"}
  :
}
func_emit_wrapper () { :; }
func_append () { eval "$1=\$$1\$2"; }
SH
        my $calls = <<'SH';
test_func_normal_abspath 'C:/one/../two'
printf '%s\n' "$func_normal_abspath_result"
test_func_to_host_path 'C:/one'
printf '%s\n' "$func_to_host_path_result"
test_func_to_host_pathlist 'C:/one:D:/two'
printf '%s\n' "$func_to_host_pathlist_result"
SH
        ($status, $output) = run_shell($preamble . $functions . $calls);
        is($status, 0, 'prepared path functions run without brush substitutions');
        is($output, "C:/two\nC:\\\\one\nC:\\\\one;D:\\\\two\n", 'drive letters and path-list separators survive conversion');
        ($status, $output) = run_shell($preamble . $functions . "test_func_emit_cwrapperexe_src\n");
        is($status, 0, 'prepared wrapper generator runs without brush substitutions');
        like($output, qr/find_executable \(_pgmptr\)/, 'emitted C uses the executable path');
        my $unc_test = <<'C';
if (strncmp (final, "\\\\?\\UNC\\", 8) == 0)
C
        ok(index($output, $unc_test) >= 0, 'emitted C preserves the UNC prefix escapes');
    }
}

my $conflict = fixture('gcc', 'conflict');
my $modified = read_file("$conflict/gcc/testsuite/lib/target-libpath.exp");
$modified =~ s/setenv PATH "\$ld_library_path:\$orig_path"/setenv PATH "local customization"/ or die 'fixture drift';
write_file("$conflict/gcc/testsuite/lib/target-libpath.exp", $modified);
my $before = snapshot($conflict);
($status, $output) = run_prepare($conflict);
isnt($status, 0, 'modified project patch context is rejected');
is_deeply(snapshot($conflict), $before, 'late conflict prevents all writes');
($status, $output) = run_prepare('--dry-run', $conflict);
isnt($status, 0, 'dry run detects the same conflict');
is_deeply(snapshot($conflict), $before, 'conflicting dry run changes nothing');

my $unknown = fixture('binutils', 'unknown-libtool');
$modified = read_file("$unknown/ltmain.sh");
$modified =~ s/func_normal_abspath_tpath=\$1/func_normal_abspath_tpath=custom/ or die 'fixture drift';
write_file("$unknown/ltmain.sh", $modified);
$before = snapshot($unknown);
($status, $output) = run_prepare($unknown);
isnt($status, 0, 'unrecognized Libtool implementation is rejected');
is_deeply(snapshot($unknown), $before, 'unknown Libtool prevents all writes');

my $ambiguous = fixture('gcc', 'ambiguous');
$modified = read_file("$ambiguous/ltmain.sh");
write_file("$ambiguous/ltmain.sh", $modified . $modified);
$before = snapshot($ambiguous);
($status, $output) = run_prepare($ambiguous);
isnt($status, 0, 'ambiguous repeated context rejected');
is_deeply(snapshot($ambiguous), $before, 'ambiguous context prevents all writes');


my $readonly = fixture('gcc', 'readonly');
chmod 0444, "$readonly/libgcc/Makefile.in" or die $!;
$before = snapshot($readonly);
($status, $output) = run_prepare($readonly);
isnt($status, 0, 'unwritable target rejected before writing');
is_deeply(snapshot($readonly), $before, 'unwritable target prevents all writes');
chmod 0644, "$readonly/libgcc/Makefile.in" or die $!;

my $crlf = fixture('gcc', 'crlf');
for my $relative (keys %{snapshot($crlf)}) {
    my $text = read_file("$crlf/$relative");
    $text =~ s/\r\n/\n/g;
    $text =~ s/\n/\r\n/g;
    write_file("$crlf/$relative", $text);
}
($status, $output) = run_prepare($crlf);
is($status, 0, 'CRLF source files supported');
unlike(read_file("$crlf/ltmain.sh"), qr/(?<!\r)\n/, 'CRLF preserved in changed files');
($status, $output) = run_prepare($crlf);
is($status, 0, 'CRLF second run succeeds');
like($output, qr/^0 file\(s\) changed\./m, 'CRLF second run changes nothing');

my $mixed = fixture('gcc', 'mixed-endings');
$modified = read_file("$mixed/ltmain.sh");
$modified =~ s/\n/\r\n/;
write_file("$mixed/ltmain.sh", $modified);
$before = snapshot($mixed);
($status, $output) = run_prepare($mixed);
isnt($status, 0, 'mixed line endings rejected');
is_deeply(snapshot($mixed), $before, 'mixed line endings prevent all writes');

my $generic = fixture('gcc', 'generic');
($status, $output) = run_prepare('--project=generic', $generic);
is($status, 0, 'explicit generic mode succeeds');
is(read_file("$generic/libgcc/Makefile.in"), read_file("$FindBin::Bin/fixtures/gcc/libgcc/Makefile.in"), 'generic mode leaves project files alone');
($status, $output) = run_prepare('--project=binutils', $generic);
isnt($status, 0, 'incorrect explicit project rejected');

my $empty = "$scratch/empty";
make_path($empty);
($status, $output) = run_prepare($empty);
isnt($status, 0, 'unrecognized empty directory is not reported as prepared');
($status, $output) = run_prepare("$scratch/missing");
isnt($status, 0, 'missing directory rejected');
($status, $output) = run_prepare('--project=unknown', $empty);
isnt($status, 0, 'unknown project rejected');

my $links = fixture('gcc', 'links');
my $external = "$scratch/external-ltmain.sh";
write_file($external, read_file("$links/ltmain.sh"));
SKIP: {
    my $ok = eval { symlink($external, "$links/extra/ltmain.sh") };
    # The parent must exist for Windows CreateSymbolicLink.
    if (!$ok) {
        make_path("$links/extra");
        $ok = eval { symlink($external, "$links/extra/ltmain.sh") };
    }
    skip 'symbolic links unavailable', 3 unless $ok;
    my $external_before = read_file($external);
    ($status, $output) = run_prepare($links);
    is($status, 0, 'source symlink skipped during discovery');
    is(read_file($external), $external_before, 'symlink target remains untouched');
    unlink "$links/gcc/BASE-VER" or die $!;
    symlink($external, "$links/gcc/BASE-VER") or die $!;
    ($status, $output) = run_prepare($links);
    isnt($status, 0, 'explicit project metadata symlink rejected');
}

done_testing();
