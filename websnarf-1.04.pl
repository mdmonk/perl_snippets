#!/usr/bin/perl -w
#
# websnarf
#
# written by :	Stephen J. Friedl
#		Software Consultant
#		steve@unixwiz.net
#		2001-08-01 -- placed into the public domain
#
#	================================================================
#	NOTE: this program was written in three hours, and the consultant
#	clock was not running. Sorry if it looks a bit rushed.
#	================================================================
#
#	This program listens on port 80 -- for as many interfaces as are
#	found on the system -- and captures all the web requests. It was
#	prompted by the Code Red worm breakout, and we put this on a
#	Linux machine on an external subnet to watch. We typically have
#	the machine listen on all the IPs we can find, and by capturing
#	the probe we can figure out how far the worm is spreading.
#
#	We listen on port 80 for any connections, read one line of input
#	the represents the GET (or PUT or HEAD or whatever), and record
#	all of this to the standard output before closing the connection.
#	We never speak to the other end.
#
# COMMAND LINE
# ------------
#
# --port=##	Listen on port ## instead of 80. This is mainly only
#		good for developers making sure we've not broken something
#		while testing on a "live" system.
#
# --timeout=##	Wait for at most ## seconds for input from the remote end.
#		Longer timeouts will capture a bit more traffic over slow
#		links, but it will hold up the rest of the program.
#
# --log=FILE	Append to the given file. The info saved there is also
#		*always* written to the standard output, but this insures
#		that we have a record even if the program is restarted.
#
# --max=##	max length of captured request is ## characters. Most URL
#		fetches are small ("GET / HTTP/1.0") but the Code Red
#		ones are quite large. We don't care to record much more
#		than one line's worth.
#
# --save=DIR	save /all/ headers into separate files in DIR. This is not
#		a very good mechanism (but was easy to implement). It fills
#		up a directory quickly: don't use --save=.  !
#
# --apache      put logs in Apache format (should be the default)
#
# --version     show current version number
#

use strict;
use IO::Socket;
use IO::Select;

my $version = "1.04";

autoflush STDOUT 1;		# no buffering to the standard output

my $Debug     = 0;
my $logfile   = "";
my $port      = 80;		# TCP only
my $alarmtime = 5;		# seconds
my $maxline   = 40;		# max length of the line
my $savedir   = "";
my $apache    = 0;		# --apache

my @MONTHS = (
	'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
	'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
);
	
foreach ( @ARGV )
{
	if ( m/^--help/ )			# --help
	{
		print STDERR <<EOF;
usage: $0 [options]

--timeout=<n>   wait at most <n> seconds on a read (default $alarmtime)
--log=FILE      append output to FILE (default stdout only)
--port=<n>      listen on TCP port <n> (default $port/tcp)
--max=<n>       save at most <n> chars of request (default $maxline chars)
--save=DIR      save all incoming headers into DIR
--debug         turn on a bit of debugging (mainly for developers)
--apache        logs are in Apache style
--version       show version info

--help          show this listing 
EOF

		exit 1;
	}
	elsif ( m/^--log=(.+)/ )			# --log=FILE
	{
		$logfile = $1;
	}
	elsif ( m/^--port=(\d+)/ )			# --port=##
	{
		$port = $1;
	}
	elsif ( m/^--timeout=(\d+)/ )			# --timeout=##
	{
		$alarmtime = $1;
	}
	elsif ( m/^--max=(\d+)/ )			# --max=##
	{
		$maxline = $1;
	}
	elsif ( m/^--save=(.+)/ )			# --save=DIR
	{
		$savedir = $1;
	}
	elsif ( m/^--debug/ )				# --debug
	{
		$Debug = 1;
	}
	elsif ( m/^--apache/ )				# --apache
	{
		$apache = 1;
	}
	elsif ( m/^--version/ or m/^-V/ )		# --version
	{
		print STDERR "websnarf v$version -- http://www.unixwiz.net/tools/websnarf.html\n";
		exit 0;
	}
	else
	{
		die "ERROR: {$_} is invalid cmdline param (try --help)\n";
	}
}

# -----------------------------------------------------------------------
# CREATE LOGFILE
#
# ... but only if requested with --log=FILE
#

if ( $logfile )
{
	if ( not open(LOG, ">>$logfile") )
	{
		die "ERROR: cannot create logfile $logfile [$!]\n";
	}

	autoflush LOG 1;

	print LOG "# Now listening on port $port\n";
}

# -----------------------------------------------------------------------
# Create the socket to listen on. It's a fatal error if we cannot listen
# on port 80, the most common reasons being (a) we're not root or
# (b) something else is already listening on that. Is Apache running?
#
my $Socket = IO::Socket::INET->new(
		LocalPort => $port,
		Type      => SOCK_STREAM,
		Reuse     => 1,
		Listen    => 1 );

if ( not defined $Socket )
{
	die "ERROR: cannot listen on port 80: [$!]\n";
}

print "websnarf v$version listening on port $port (timeout=$alarmtime secs)\n";

my $timeout = 0;
my $client  = undef;

while ( $client = $Socket->accept() )
{
	#----------------------------------------------------------------
	# We immediately need to note who the local and remote IP addresses
	# are, because once we start the read we may find that our socket
	# gets closed by a timeout. Save them now for easier reference.
	#

	my $local_ip  = $client->sockhost();		# our own IP address
	my $remote_ip = $client->peerhost();		# other guys' IP address

	print "--> accepted connection from $remote_ip\n"	if $Debug;


	#----------------------------------------------------------------
	# GO READ
	#
	# We want to read the entire request from the other end, but with
	# a smart timeout that means we don't get hung if the other end
	# disappears. We read everything into the long $request variable,
	# and we stop when we get a timeout -or- we see the CR/LF at the
	# end of the line.
	#

	my $request = "";		# full long big request
	my $nreads    = 0;		# number of read loops
	my $tmout     = $alarmtime;	# timeout value

	my $sel = IO::Select->new($client);

	while ( $sel->can_read($tmout) )
	{
		$nreads++;

		my $offset = length($request);

		print "  client ready to read, now reading\n"	if $Debug;

		my $n = sysread($client, $request, 9999, $offset);
		
		if ( $Debug )
		{
			printf("  got read #%d of [%d]\n", $nreads, $n);

			my $dline = $request;

			$dline =~ s/\r/<CR>/g;
			$dline =~ s/\n/<LF>/g;

			print "  [$dline]\n";
		}

		last if $request =~ m/\r\n\r\n$/;
	}

	if ( $Debug )
	{
		printf "  Finished read loop: request = %d bytes (%d reads)\n",
			length $request,
			$nreads;
	}

	my $display = "";

	if ( $nreads == 0 )
	{
		$display = '[timeout]';
	}
	elsif ( length $request == 0 )
	{
		$display = '[empty]';
	}
	else
	{
		$display = $request;

		$display =~ s/[\r\n].*$//s;		# dump all but first line
	}

	$display =~ s/\s+$//;		# dump trailing white

	my $logline = "";

	if ( $apache )
	{
		my $timestamp = apache_timestamp();

		my @INFO = ();

		push @INFO, $remote_ip;		# host name of remote
		push @INFO, "-";		# identd info
		push @INFO, "-";		# authuser
		push @INFO, "[$timestamp]";	# date/time of request
		push @INFO, "\"$display\"";	# display info
		push @INFO, "404";		# status
		push @INFO, 100;		# bytes returned (a lie!)

		$logline = join(" ", @INFO);
	}
	else
	{
		my $timestamp = std_timestamp();

		$logline = sprintf("%s %-15s -> %-15s: %s\n",
			$timestamp,		# current time
			$remote_ip,		# remote IP address
			$local_ip,		# our own IP address
			$display);		# request itself
	}

	$logline .= "\n";

	print $logline;			# stdout

	print LOG $logline			if $logfile;

	$client->close()		if defined $client;

	#----------------------------------------------------------------
	# If we're saving the actual snapshots, do so now.
	#
	if ( $savedir )
	{
		my $fname = "$savedir/$remote_ip-$local_ip";

		if ( not open(SNAP, ">$fname") )
		{
			print "ERROR: cannot save to $fname (saving disabled)\n";

			undef $savedir;
			next;
		}

		print SNAP $request;

		close SNAP;
	}
}

#
# apache_timestamp
#
#	Return the current time (GMT!) in Apache logfile format.
#


sub apache_timestamp {

	my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime;

	return sprintf("%02d/%s/%04d:%02d:%02d:%02d -0000",
		$mday,			# Day
		$MONTHS[ $mon ],	# Month
		$year + 1900,		# YYYY
		$hour, $min, $sec );
}

sub std_timestamp {

	my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime;

	return sprintf("%02d/%02d %02d:%02d:%02d",
		$mon + 1,
		$mday,
		$hour,
		$min,
		$sec );
}
