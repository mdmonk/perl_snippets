#####################################################
# Program Name: ls-l.pl
#
# Desc:  This script emulates the Unix "ls -l"
#
#####################################################

$dir = '.';		# test

&ls (1, $dir);

sub ls {	# void = ls (BOOL $recurse, STRING $dir)
        my ($recurse, $dir) = @_;
        my (@files) = @_;
        my (@dirs);

opendir DIR, $dir or die "opendir: $!\n";
@files = grep !/^\.+$/, readdir DIR;
closedir DIR;

my @mons = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
  'Oct', 'Nov', 'Dec');

print "\n$dir:\n" if $recurse;
print "total ", scalar @files, "\n";
foreach (sort @files) {

        @stat = stat "$dir/$_";
        push (@dirs, $_) if -d _;
        my $perms = sprintf "%s%s%s%s%s%s%s---",
          -d _ ? 'd' : (-l "$dir/$_" ? 'l' : (-p _ ? 'p' : '-')),
          -r _ ? 'r' : '-', -w _ ? 'w' : '-', -x _ ? 'x' : '-',
          -R _ ? 'r' : '-', -W _ ? 'w' : '-', -X _ ? 'x' : '-',
        my $links = $stat[3];
        my $user = $stat[4];
        my $group = $stat[5];
        my $size = -s "$dir/$_";
        my $mod = $stat[9];
        my $date = '';
        my @date = localtime $mod;
        if (time - $mod > 6 * 30 * 86400) {
                # 'Dec 10  1998';
                $date = sprintf "%s %2u  %04u", $mons[$date[4]], $date[3],
                  $date[5] + 1900;
        } else {
                # 'Dec 10 12:34';
                $date = sprintf "%s %2u %02u:%02u", $mons[$date[4]],
                  $date[3], $date[2], $date[1],
        }
        printf "%s %3u %-8u %-8u %8u %-11s %s\n", $perms, $links,
          $user, $group, $size, $date, $_;
}
return if ! $recurse;
foreach (sort @dirs) { &ls (1, "$dir/$_"); }

}

__END__
