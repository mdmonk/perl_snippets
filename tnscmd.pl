#!/usr/bin/perl
#
# tnscmd - a lame tool to prod the oracle tnslsnr process (1521/tcp)
# tested under Linux x86 & OpenBSD Sparc + perl5
#
# Initial cruft: jwa@jammed.com  5 Oct 2000
#
# $Id: tnscmd,v 1.3 2001/04/26 06:45:48 jwa Exp $
#
# see also: 
#    http://www.jammed.com/~jwa/hacks/security/tnscmd/tnscmd-doc.html
#    http://cve.mitre.org/cgi-bin/cvename.cgi?name=CAN-2000-0818 
#    http://otn.oracle.com/deploy/security/alerts.htm
#    http://xforce.iss.net/alerts/advise66.php 
#
# GPL'd, of course.  http://www.gnu.org/copyleft/gpl.html
#
# $Log: tnscmd,v $
# Revision 1.3  2001/04/26 06:45:48  jwa
# typo in url.  whoops.
#
# Revision 1.2  2001/04/26 06:42:17  jwa
# complete rewrite
#  - use IO::Socket instead of tcp_open
#  - got rid of pdump()
#  - put packet into @list and build it with pack()
#  - added --indent option
#
#

use IO::Socket;
use strict;		# a grumpy perl interpreter is your friend

select(STDOUT);$|=1;

#
# process arguments
#

my ($cmd) = $ARGV[0] if ($ARGV[0] !~ /^-/);
my ($arg);

while ($arg = shift @ARGV) {
	$main::hostname = shift @ARGV if ($arg eq "-h");
	$main::port = shift @ARGV if ($arg eq "-p");
	$main::logfile = shift @ARGV if ($arg eq "--logfile");
	$main::fakepacketsize = shift @ARGV if ($arg eq "--packetsize");
	$main::fakecmdsize = shift @ARGV if ($arg eq "--cmdsize");
	$main::indent = 1 if ($arg eq "--indent");
	$main::rawcmd = shift @ARGV if ($arg eq "--rawcmd");
	$main::rawout = shift @ARGV if ($arg eq "--rawout");
}

if ($main::hostname eq "") {
	print <<_EOF_;
usage: $0 [command] -h hostname
       where 'command' is something like ping, version, status, etc.  
       (default is ping)
       [-p port] - alternate TCP port to use (default is 1521)
       [--logfile logfile] - write raw packets to specified logfile
       [--indent] - indent & outdent on parens
       [--rawcmd command] - build your own CONNECT_DATA string
       [--cmdsize bytes] - fake TNS command size (reveals packet leakage)
_EOF_
	exit(0);
}

# with no commands, default to pinging port 1521

$cmd = "ping" if ($cmd eq "");
$main::port = 1521 if ($main::port eq ""); # 1541, 1521.. DBAs are so whimsical


#
# main
#

my ($command);

if (defined($main::rawcmd))
{
	$command = $main::rawcmd;
}
else
{	
	$command = "(CONNECT_DATA=(COMMAND=$cmd))";	
}


my $response = tnscmd($command);
viewtns($response);
exit(0);


#
# build the packet, open the socket, send the packet, return the response
#

sub tnscmd
{
	my ($command) = shift @_;
	my ($packetlen, $cmdlen);
	my ($clenH, $clenL, $plenH, $plenL);
	my ($i);

	print "sending $command to $main::hostname:$main::port\n";

	if ($main::fakecmdsize ne "") 
	{
		$cmdlen = $main::fakecmdsize;
		print "Faking command length to $cmdlen bytes\n";
	} 
	else 
	{	
		$cmdlen = length ($command);
	}

	$clenH = $cmdlen >> 8;
	$clenL = $cmdlen & 0xff;

	# calculate packet length

	if (defined($main::fakepacketsize)) 
	{
		print "Faking packet length to $main::fakepacketsize bytes\n";
		$packetlen = $main::fakepacketsize;
	} 
	else 
	{	
		$packetlen = length($command) + 58;	# "preamble" is 58 bytes
	}

	$plenH = $packetlen >> 8;
	$plenL = $packetlen & 0xff;

	$packetlen = length($command) + 58 if (defined($main::fakepacketsize));

	# decimal offset
	# 0:   packetlen_high packetlen_low 
	# 26:  cmdlen_high cmdlen_low
	# 58:  command

	# the packet.

	my (@packet) = (
		$plenH, $plenL, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 
		0x01, 0x36, 0x01, 0x2c, 0x00, 0x00, 0x08, 0x00,
		0x7f, 0xff, 0x7f, 0x08, 0x00, 0x00, 0x00, 0x01,
		$clenH, $clenL, 0x00, 0x3a, 0x00, 0x00, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00, 0x34, 0xe6, 0x00, 0x00,
		0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
		0x00, 0x00
		);


	for ($i=0;$i<length($command);$i++)	
	{
		push(@packet, ord(substr($command, $i, 1)));
	}	

	my ($sendbuf) = pack("C*", @packet);

	print "connect ";
	my ($tns_sock) = IO::Socket::INET->new( 
		PeerAddr => $main::hostname, 
		PeerPort => $main::port, 
		Proto => 'tcp', 
		Type => SOCK_STREAM, 
		Timeout => 30) || die "connect to $main::hostname failure: $!";
	$tns_sock->autoflush(1);

	print "\rwriting " . length($sendbuf) . " bytes\n";

	if (defined($main::logfile)) 
	{
		open(SEND, ">$main::logfile.send") || die "can't write $main::logfile.send: $!";
		print SEND $sendbuf || die "write to logfile failed: $!";
		close(SEND);
	}	

	my ($count) = syswrite($tns_sock, $sendbuf, length($sendbuf));

	if ($count != length($sendbuf))
	{
		print "only wrote $count bytes?!";
		exit 1;
	}	

	print "reading\n";

	# get fun data
	# 1st 12 bytes have some meaning which so far eludes me

	if (defined($main::logfile)) 
	{
		open(REC, ">$main::logfile.rec") || die "can't write $main::logfile.rec: $!";
	}	

	my ($buf, $recvbuf);

	# read until socket EOF
	while (sysread($tns_sock, $buf, 128))
	{
		print REC $buf if (defined($main::logfile));
		$recvbuf .= $buf;
	}
	close (REC) if (defined($main::logfile));
	close ($tns_sock);
	return $recvbuf;
}


sub viewtns
{
	my ($response) = shift @_;

	# should have a hexdump option . . .

	if ($main::raw)
	{
		print $response;
	} 
	else
	{
		$response =~ tr/\200-\377/\000-\177/;	# strip high bits
		$response =~ tr/\000-\027/\./;
		$response =~ tr/\177/\./;

		if ($main::indent)
		{
			parenify($response);
		} 
		else
		{
			print $response;
		}
		print "\n";
	}	
}	


sub parenify
{
	my ($buf) = shift @_;
	my ($i, $c);
	my ($indent, $o_indent);

	for ($i=0;$i<length($buf);$i++) 
	{
		$c = substr($buf, $i, 1);
		$indent++ if ($c eq "(");
		$indent-- if ($c eq ")");
		if ($indent != $o_indent)
		{
			print "\n" unless(substr($buf, $i+1, 1) eq "(");
			print "  " x $indent;
			$o_indent = $indent;
			undef $c;
		}	
		print $c;
	}
}	

