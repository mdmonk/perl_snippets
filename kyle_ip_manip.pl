###!/usr/bin/perl -w
#!/usr/bin/perl

#
# Explode IP subnets into addresses (one per line) - Kyle Haugsness
#
# Change log:
#    07/11/2002 - KWH; initial script
#
# The purpose of this to take a subnet address in CIDR notation
# and print all the valid host addresses in the range
#
# Todo:
#  1. handle output to files better (using a command-line option)
#  2.
#
# There are several different modules on CPAN that provide IPv4 address
# manipulation.  The one that I chose for this task is NetAddr::IP.
# The Network::IPv4Addr module is useful in checking sanity of the
# command-line args.  There is also Net::CIDR module, but I didn't use it.
#

# Be specific about variable declaration scope
use strict;

# Load modules
use Network::IPv4Addr qw(ipv4_parse);  # Do sanity checking on command line args
use NetAddr::IP;  # Use this to enumerate valid hosts in a given CIDR block


################################
#  Variable Initialization
################################

my $ip_addr;        # IP address
my $mask;           # CIDR mask
my $ip;             # IP and CIDR mask structure manipulated by NetAddr::IP
my @scrubbed_args;  # Array of sanity-checked arguments
my $count = 0;      # count


################################
#  Subroutines
################################

# This function prints all the host addresses when given an IP/CIDR
sub print_ips {

  # Declare a new IP/CIDR structure with the first command line arg
  $ip = new NetAddr::IP "$_";

  # Use the NetAddr::IP method to return all valid host addresses in this block
  #  This method doesn't return network or broadcast addresses;
  #  also, it returns hosts in the format 10.7.1.1/32
  my @hosts = $ip->hostenum();

  # Enumerate the array and print only the IP addresses
  foreach (@hosts) {
    ($ip_addr, $mask) =  split(/\//, $_, 0);
    print "$ip_addr\n";
  }

}


################################
#  Main Script
################################

# Determine if there are enough arguments
die "Usage:  $0 <IP/CIDR> ...\n  CIDR = /18 or /255.255.240.0\n" if (@ARGV < 1);

# Scrub all the command line arguments using ipv4_parse
foreach (@ARGV) {

  # Trap error with eval
  eval { ($ip_addr, $mask) = ipv4_parse($_) };

  # If there was an error in the eval, warn and skip to the next argument
  if ($@) {
    warn "Invalid CIDR notation:  $_\n";
    next;   # Proceed to the next loop; don't increment counter
  }

  # The arguments are sane, so join the IP address and mask back together again
  $scrubbed_args[$count] = join("/", $ip_addr, $mask);
  $count += 1;

}


# Do the work -> pass each IP/CIDR string into the function to display each
#  valid host in that network
foreach (@scrubbed_args) {
  &print_ips($_);
}

