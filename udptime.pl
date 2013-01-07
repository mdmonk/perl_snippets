use strict;
use IO::Socket;
use Sys::Hostname;

my (@listfile);
@listfile = @ARGV;

if (length(@listfile) == 0) { @listfile = (hostname()); }
getremotetime(@listfile);

sub getremotetime {

	# declare all variables
	my ($count, $hisiaddr, $hispaddr, $histime, $histime2, 
		$host, $iaddr, $paddr, $port, $proto, 
		$rin, $rout, $rtime, $SECS_OF_70_YEARS, 
		@list, $listfile, @aNTP);
	@list = @_;  # get list of hosts to get time from

	$SECS_OF_70_YEARS = 2208988800;  # since time is in secs since 1970

	$paddr = inet_aton(hostname());	# who am i

	$proto = getprotobyname('udp');		# my protocol
	$port = getservbyname('ntp', 'udp');	# service

	# $port = getservbyname('ntp', 'udp');	# alternative service

	$paddr = sockaddr_in(0, $iaddr);	# packed addr representation

	# create udp socket and bind
	socket(SOCKET, PF_INET, SOCK_DGRAM, $proto) or die "socket: $!\n";
	bind(SOCKET, $paddr) or die "bind: $!\n";

	# $| = 1;
	print "local time: " . localtime() . "\n";

	print "checking hosts ...\n";
	$count = 0;
	for $host (@list) {
		print "host name $host ...\n";  $count++;
		$hispaddr = sockaddr_in($port, inet_aton($host));
		defined(send(SOCKET, 0, 0, $hispaddr)) or die "send $host: $!\n";

		if ($count >= 1) { last; }
	}

	$rin = "";
#	vec($rin, fileno(SOCKET), 1) = 1;

	# Stuff to ensure that the socket is ready for reading
	#  before we try to accept stuff from it
#	while ($count && select($rout=$rin, undef, undef, 10.0)) {
		print "waiting for responses [10]...\n";
		$rtime = " " x 500; # create a buffer to receive data to
		($hispaddr = recv(SOCKET, $rtime, 500, 0)) or die "recv: $!\n";
		($port, $hisiaddr) = sockaddr_in($hispaddr);
		$host = gethostbyaddr($hisiaddr, AF_INET);
		
#		@aNTP = unpack("CCCb8I32I32I32I64I64I64I64", $rtime);
#		@aNTP = unpack("b2b3b3b8b8b8b32b32b32b64b64b64b64", $rtime);
		@aNTP = unpack("B2B3B3B8B8B8B32B32B32B64B64B64B64", $rtime);
		for (@aNTP) {
			print $_ . ";" . unpack("N", pack("B64", substr("0"x64 . $_, -64))) . "\n";
		}

		$count--;
#	}

}
