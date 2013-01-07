#####################################################################
# Program Name: domscan.pl
# Programmer:   Chuck Little
# Description:  This script gets the host domain for the machine
#               the script is running on then it "dumps" the domain
#               (table?) getting all host names, status', and their
#               IP address.....for each host in the table (?).
#
#               I think it does this on the Authoritative DNS server.
#####################################################################
use Net::Domain;
my $domain = Net::Domain::hostdomain();
open(NSL, "| nslookup > c:/temp/nsl.out") or die "Can't run nslookup: $!";
print NSL "ls $domain\n";
print NSL "exit\n";
close NSL;
open(NSL, "c:/temp/nsl.out") or die "Can't open nsl.out: $!";
my @hosts;
while (<NSL>) {
	my ($host, $ip) = /^\s*(\w+)\s*A\s*([0-9\.]*)/;
	push @hosts, [$host,$ip];
}
#####################################################################
