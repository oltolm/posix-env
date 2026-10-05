# File::Spec with Win32 semantics (drive letters, case-insensitive) but '/'
# separators, as the native POSIX environment spells paths.
package File::Spec::Slash;
use strict;
use File::Spec;
use File::Spec::Win32;
our @ISA = ('File::Spec::Win32');
sub slashes { map { defined $_ ? join('/', split(/\\/, $_, -1)) : $_ } @_ }
for my $f (qw(canonpath catdir catfile catpath rel2abs abs2rel tmpdir rootdir devnull)) {
  my $orig = File::Spec::Win32->can($f);
  no strict 'refs';
  *{"File::Spec::Slash::$f"} = sub { my @r = slashes($orig->(@_)); wantarray ? @r : $r[0] };
}
@File::Spec::ISA = ('File::Spec::Slash');
1;
