#!/usr/bin/perl
########################################
#
########################################

@addrs    = qw(100 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120);
$ip       = "192.168.0.";
@proto    = qw(TCP UDP);
@ports    = qw(4444 5555 6666 7777 8888);
$IPCHAINS = "/sbin/ipchains";

foreach $lastOct (@addrs) {
   my $fullIP = $ip . $lastOct;
   chomp ($fullIP);
   foreach $nPort (@ports) {
	  chomp ($nPort);
	  print "Setting rule for IP: $fullIP; port: $nPort\n";
      `$IPCHAINS -A OUTPUT -p tcp -s 0/0 -d $fullIP/24 $nPort -j DENY -l`;
      `$IPCHAINS -A OUTPUT -p udp -s 0/0 -d $fullIP/24 $nPort -j DENY -l`;
   } # end foreach
} # end foreach
