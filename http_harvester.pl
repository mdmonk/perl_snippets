#!/usr/bin/perl

# Version 1.0
# Might or might not work for you. Worked for me. I've used it only once, though...
# Just don't bother me please. Fix it. I'm too busy with other things.

use strict;
use IO::Socket;
$|=1;

use vars qw($MAX $TIMEOUT $proc $wait);

# number of concurrent processes
$MAX = 6;

# how long to wait for whole 'communication' exchange (connect/read/close)?
# in seconds, of course...
$TIMEOUT = 6;

# define the range (c class - if you need something else... well, add it)
my $range = $ARGV[0] || die "Usage  : $0 <C class range> [port number]\nExample: $0 192.168.1\n";

# just in case someone really likes dot at the end
$range =~ s/\.$//g;

# define the port (or use 80)
my $port = ($ARGV[1]) ? ($ARGV[1]) : 80;

# close the STDERR - we don't want to see IO::Socket errors (well, we won't see any other errors either... damn :)
close(STDERR);

# loop from 0-255 (c class)
my $ip;
for $ip (0..255)
{
	check("$range.$ip");
}

sleep $TIMEOUT; # lazy to find out how to wait for all processes to finish :)
print "\n\n-- Finished\n";
exit;

sub check {

	my $target = shift;

	# I'm not sure anymore if this is needed - as Perl is progressing, I'm getting more lost...
	$SIG{'ALRM'} = sub { exit; };

	my $child = fork();
	if ($child > 0)
	{
		$SIG{CHLD} = 'IGNORE';
		$proc++;
		
		if ($proc >= $MAX)
		{
			$wait = wait();
			if ($wait > 0)
			{
				$proc--;
			}
		}
		next;
	}
	elsif (undef $child)
	{
		print "*** Ouch - fork() problem\n";
	}
	else
	{
		# heh, 'progress bar'? ;)
		printf "\rTrying: %20s", $target;

		alarm($TIMEOUT);

		my $sock = IO::Socket::INET->new(
			Proto		=> 'tcp',
			PeerPort	=> $port,
			PeerAddr	=> "$target"
			) || die;
		
		$sock->autoflush(1);
		
		print $sock "HEAD / HTTP/1.0\r\n\r\n"; # some crappy servers need it this way
		while (<$sock>)
		{
			(printf "\r%20s - $_", $target) if ($_ =~ /^Server:/);
		}
		
		close($sock);
		alarm(0);
		
		exit;
	}

}
