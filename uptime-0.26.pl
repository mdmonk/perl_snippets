#! perl -w
# use strict; # eval doesn't work with use strict !?
# see POD documentation at end

=head1 NAME

uptime.pl - Uptime for Windows. Version 0.26.

=cut

$^O eq "MSWin32" || die "Sorry, this works only on Windows for now\n";

my $max_results = 5; # if we have to use tick counts

my $VERSION = 0.26;

my $debug = $ENV{'QUERY_STRING'} || $ARGV[0];
print "$0 version $VERSION\n" if $debug;
print "Debug mode on\n" if $debug;
print "Perl version $]\n" if $debug;

BEGIN {
	# HTTP headers if needed
	local $^W = 0;
	print "$ENV{'SERVER_PROTOCOL'}/200 OK\n" if $ENV{'PERLXS'} eq "PerlIS";
	print "Content-type text/plain\n\n" if $ENV{'SERVER_PROTOCOL'};
}

my ($several, @uptimes);

if (Win32::IsWinNT()) {
	print "Windows NT\n\n" if $debug;
	push @uptimes, (&event_log || &tick_counts);
	print "eval error: $@\n" if $@ && $debug;
}
else {
	print "Windows 9x\n\n" if $debug;
	push @uptimes, (&system_da0 || &tick_counts);
}

sub tick_counts {
	print "Counting ticks\n" if $debug;
	my @ticks;
	my $ticks = Win32::GetTickCount() > 0
    	      ? Win32::GetTickCount()
        	  : Win32::GetTickCount() + 2**32;
	my $seconds = $ticks/1000;
	for (1..$max_results-1) {
		push @ticks, time()-$seconds;
		$seconds += 2**32/1000;
	}
	return @ticks, time()-$seconds;
}

sub system_da0 {
	my $file = "$ENV{'WINDIR'}\\system.da0";
	print "Checking $file\n" if $debug;
	my $stat = (stat $file)[9]; 
	print "Could not stat $file ($!)\n" if $debug && !$stat;
	return $stat || undef;
}

sub event_log {
	my $result = eval '
        local $^W = 0;
		use Win32::EventLog;
		my ($EventLog, $first, $count, $event, %data);
		Win32::EventLog::Open($EventLog , "System", "") || die ("EventLog Open() failed");
		$EventLog->GetOldest($first) || die ("EventLog GetOldest() failed");
		$EventLog->GetNumber($count) || die ("EventLog GetNumber() failed");
		print "Event log first=$first, count=$count\n" if $debug;

		$EventLog->Read((EVENTLOG_SEEK_READ | EVENTLOG_BACKWARDS_READ),$first+$count,$event);

		for $i (0 .. $first+$count-1) {
			$EventLog->Read((EVENTLOG_SEQUENTIAL_READ|EVENTLOG_BACKWARDS_READ),0,$event)
				 || die ("EventLog Read() failed at event $i");
                               
			%data = %{$event};
			$data{"EventID"} = $data{"EventID"} & 0xffff;

		    next unless $data{"EventID"} == 6005;
    		print "Found event 6005\n" if $debug;
			return $data{"TimeGenerated"};
			print "This script is broken: it should never reach this line\n";
		}
		return undef;
	';
	if ($@) {
		print "Eval error: $@\n";
		return undef;
	}
	else {
		return $result;
	}
}

$several = @uptimes - 1;
foreach (@uptimes) {
	print "up ", &time2days($_), " (since ", scalar localtime($_), ")\n";
	print "or:\n" if $several;
}

print "... but who would believe that anyway?...\n" if $several;

sub time2days {
	print "converting $_[0]\n" if $debug;
	my $days = (time() - $_[0])/(24*60*60);
	my $hours = ($days - int($days)) * 24;
	my $minutes = ($hours - int($hours)) * 60;
	my $day_st = $days >= 2 ? 'days' : 'day';
	return sprintf("%0d $day_st %02d:%02d", $days, $hours, $minutes);
}

__END__

=head1 SYNOPSIS

perl uptime.pl [debug]

=head1 DESCRIPTION

Report machine uptime on Windows systems.

This script attempts to report the system uptime in a format similar
to the Unix uptime command. It only reports uptime, not users or
load statistics.

On NT it uses the event log. The event log service itself writes an
entry to it when it starts (ID 6005).

On Win95 it gets the create time of the system.da0 file (the system.dat
backup file which is recreated at system start).

If eihter of these methods fail (like on Win98), it uses the system tick 
counts. Since these can only hold about 49.7 days, it returns a list of 
possible uptimes, limited to C<$max_results> (5 by default). (Have you ever 
seen a Windows system up for more than 200 days? ;-) If yes, set 
C<$max_results> to a higher value).

The script can be used in CGI. It will print the needed headers automatically.

The latest version should always be available at
http://alma.ch/perl/scripts/uptime.pl

=head1 OPTIONS

If given any argument (at the command line or as a CGI argument), it is
considered as a 'debug' or 'verbose' option, and additional stuff is printed.

=head1 FEATURES (aka BUGS)

On NT, the uptime will be wrong if you restarted the event log service.

If you have a low limit on your event log file size or logged events, and
your system has been up for a long time, the event may not be available
anymore. The script will then use tick counts.

On Win95, the uptime will be wrong if the create time of your system.da0 file
is not the same as when your system booted. I don't see what could cause this
unless you overwrite the file, but there may be special cases. Let me know if
you find any.

On Win98, there seems to be no way other than tick counts. Let me know if you
find something better.

=head1 SCRIPT CATEGORIES

Win32

=head1 OSNAMES

MSWin32

=head1 AUTHOR

Milivoj Ivkovic <mi@alma.ch>. Others welcome to extend it to more
operating systems which don't have an uptime command.

=head1 COPYRIGHT

Copyright Milivoj Ivkovic, 1999. Same license as Perl itself.

=head1 README

Report machine uptime on Windows systems. Version 0.26. Nothing new since 
v. 0.25, except the addition of this Readme, to improve the listing on CPAN.

=cut
