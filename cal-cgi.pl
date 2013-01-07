use Time::Local;

my @mons = ('January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December');
my @wdays = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');

# test data, acquire the month/year yourself using a form or arg or ??

@args = ('11/1998', '12/1998', '1/1999');

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

print "Content-Type: text/html\n\n";
print "<HTML>\n";
print "<BODY>\n";

foreach (@args) {
        do_month (split '/', $_);
}

print "</BODY>\n";
print "</HTML>\n";
exit 0;

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub do_month {
        my ($month, $year) = @_;
        my (@cal) = (' ') x 42;

my $epoch = timelocal 0, 0, 0, 1, $month - 1, $year;
my $base = 0;

for (1 .. 31) {
        #($sec,$min,$hour,$mday,$mon-1,$year-1900,$wday-1,$yday-1,$isdst)
        ($m, $d, $w) = (localtime $epoch)[4,3,6];
        print "m=$m d=$d\n" if $debug;
        $base = $w if $_ == 1;
        last if $m != $month - 1;
        $cal[$base + $d - 1] = $d;
        printf "%s %u, %u\n", $mons[$m], $d, $year if $debug;
        $epoch += 86400;
}

print "<TABLE BORDER=2>\n";
print "<TR>\n";
print "<TH COLSPAN=7 BORDER=1>\n";
printf "%s&nbsp;%s\n", $mons[$month - 1], $year;
print "</TH>\n";
print "</TR>\n";
print "<TR>\n";
for ($ii = 0; $ii < 7; $ii++) {
        printf "%s&nbsp;%s&nbsp;%s\n", "<TH BORDER=1>", $wdays[$ii], "</TH>";
}
print "</TR>\n";

for ($ii = 0; $ii < 6; $ii++) {
        print "<TR>\n";
        for ($jj = 0; $jj < 7; $jj++) {
                print "<TD ALIGN=CENTER BORDER=1>\n";
                if ($cal[$ii * 7 + $jj] =~ /\d/) {
                        printf "%2u ", $cal[$ii * 7 + $jj];
                } else {
                        printf "   ";
                }
                print "</TD>\n";
        }
        print "</TR>\n";
}
print "</TABLE>\n";

} # endsub

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

__END__

