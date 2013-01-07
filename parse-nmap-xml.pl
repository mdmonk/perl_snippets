#!/usr/bin/perl -w

#
# Simple program to demonstrate the use of the Perl module to parse
# NMAP XML output files.
#
# Author: Kyle Haugsness - SANS Internet Storm Center
#
# Give the XML file as the only program argument
#

use strict;
use Nmap::Parser;           # Magic is here
use Socket qw [inet_aton];  # Used for sorting IP addresses

my $np = new Nmap::Parser;
my $tot_hosts_up = 0;
my $tot_services_tcp = 0;
my @ips_unsorted;           # An array containing IP addresses to sort
my @ips_sorted;             # An array containing IP addresses that are sorted


# Parse the input XML file
$np->parsefile("$ARGV[0]");

# Get an array of all hosts that are alive
my @hosts = $np->all_hosts("up");

# Enumerate the array and implement the search logic
foreach my $host_obj (@hosts) {

    # Get the IP address of the current host
    my $addr = $host_obj->addr();

    # Get a list of open TCP ports for this host
    my @tcp_ports = $host_obj->tcp_open_ports();
    my $port1_flag = 0;  my $port2_flag = 0;

    # Enumerate the open TCP ports and look for the ones to match
    foreach my $tcp_port (@tcp_ports) {
        if ($tcp_port == 445) {        # criteria 1
            $port1_flag = 1;
        } elsif ($tcp_port == 139) {   # criteria 2
            $port2_flag = 1;
        }
        $tot_services_tcp++;
    }
    if ($port1_flag == 1 && $port2_flag == 1) {
        # Save this IP address for sorting/output later
        push(@ips_unsorted, $addr);
    }
    $tot_hosts_up++;
}

# Sort the array of hosts that match the criteria
@ips_sorted = sort { inet_aton($a) cmp inet_aton($b) } @ips_unsorted;

print "#\n";
print "# Total hosts up: $tot_hosts_up\n";
print "# Total TCP services open: $tot_services_tcp\n#\n";
print "# List of IP addresses with TCP 139 & 445 open:\n";
foreach (@ips_sorted) {
  print "$_\n";
}
