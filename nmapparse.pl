#! /usr/bin/perl

use Nmap::Parser;
use Getopt::Std;

#
# Declare some variables
#
my $svc;
my $host;
my $port;
my $hostname;
my $ip_addr;

#
# Do the usage stuff and get options
# 
print "nmapparse.pl - ( paul\@pauldotcom.com )\n",('-'x50),"\n\n";
	
getopts('hi:');

die "Usage: $0 [-i <hosts>]\n"
	unless ($opt_i);

#
# Create the parser object
#
my $np = new Nmap::Parser;

#
# Execute Nmap Scan
#
$np->parsescan('/usr/bin/nmap','-sV -p 80,443', $opt_i);

#
# Get the host information
#
for my $host ($np->all_hosts()){

  if ($host->tcp_port_count){

	$ip_addr  = $host->addr;
	$hostname  = $host->hostname;

	print(
        	'Hostname  : '.$hostname."\n",
       		'Address   : '.$ip_addr."\n",
	);

	for my $port ($host->tcp_open_ports){

   		my $svc = $host->tcp_service($port);
        	print('Service  :  ',$port,' ('.$svc->name.') ',$svc->product,' ',$svc->version,' ',$svc->extrainfo,"\n");
    	}
	print("-------------------------------------\n");
  }
}
