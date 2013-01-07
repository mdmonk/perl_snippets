#!/usr/bin/perl -w
################################################################
# Program Name: timesync.pl
# Programmer:   Chuck.
# Description:  This script syncronizes your Win32 machine with
#               the time server.
################################################################
# For a list of available time servers see:
# http://www.eecis.udel.edu/~mills/ntp/clock2.htm
#
# For a web site that provides the local time for
# time syncing:
#   http://www.timeanddate.com/worldclock/city.html?n=64
#   will give you Chicago.
# You can parse the html output for the date/time.
################################################################
use strict;
use IO::Socket;
use File::Basename;

# format required by Unix or MKS date is: mmddhhmmyy.ss
# mm - month
# dd - day
# hh - hour
# mm - minute
# yy - last two digits of year
# ss - seconds
my $date_format = "%02d%02d%02d%02d%02d\.%02d";

my $date_prog = 'date';

# unix date program
# my $date_prog = '/usr/bin/date';

my $date;
my $datestr;
my $mydebug = defined($ENV{'MYDEBUG'}) ? $ENV{'MYDEBUG'} : 0;
my $myname;
my @PerlExtensions = ('.pl','.plx','.cgi');
# my $server = 'bitsy.mit.edu';
my $server = (shift or 'bitsy.mit.edu');

my $timeout = 15;
my $usage;
my $new_time_str;

$myname = basename($0, @PerlExtensions);
$usage = "usage: $myname timeserver";

if ($mydebug) { print "Making date/time request from '$server'\n"; }
$date = getTime($server);
if (not(defined($date))) { die "no date returned from $server\n"; }
if ($mydebug) { print "\$date=!$date!\n"; }

my ($sec, $min, $hour, $mday, $mon, $year) = localtime($date);
$year += 1900;
$year = $year - (int($year/100) * 100);

$datestr = sprintf($date_format, ++$mon, $mday, $hour, $min, $year, $sec);

if ($mydebug) {
	print "\$datestr:!$datestr!\n";
}

(length($mon) == 2) ||
	($mon = 0 . $mon);
(length($mday) == 2) ||
	($mday = 0 . $mday);
(length($hour) == 2) ||
	($hour = 0 . $hour);
(length($min) == 2) ||
	($min = 0 . $min);
(length($year) == 2) ||
	($year = 0 . $year);
(length($sec) == 2) ||
	($sec = 0 . $sec);

$new_time_str = "$hour:" . "$min:" . "$sec";
print "\nNew time: $hour:$min:$sec\n";

`time $new_time_str`;
exit;

sub getTime {
	my ($server) = @_;
	my @date;
	my $mydebug = (defined($ENV{'MYDEBUG'}) && (int($ENV{'MYDEBUG'}) == 9)) ? 1 : 0;
	my $remote;
	my $timeout = 30;

	if ($mydebug) { print "Attempting connection to !$server!\n"; }
	$remote = IO::Socket::INET->new(
		'PeerAddr' => $server,
		'PeerPort'	=> 'time(37)',
		'Proto'		=> 'tcp',
		'TimeOut'	=> $timeout)
		|| die "ntp: Can't connect to $server, $!";
	if ($mydebug) { print "connected to !$server!\n"; }

	@date = <$remote>;
	close($remote);
	if (not(defined(@date))) { return; }
	my $result = unpack("N", join("",@date));
	if ($mydebug) { print "\$result=!$result!\n"; }
	return($result - 2208988800);
};
