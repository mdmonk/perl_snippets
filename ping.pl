#!/usr/bin/perl

use pdump::Sniff;
use Net::Ping;

die "usage: $0 <host>\n" unless @ARGV == 1;
$| = 1;
$tout = 10;
$host = $ARGV[0];
$dev = pdump::Sniff::lookupdev($tout);
$ip = ${ifaddrlist()}{$dev};
$packet_tcp = new pdump::Sniff({tcp=>{}});
$filt_tcp = "ip proto \\tcp and src host $host and dst host $ip";
$pcap_tcp = $packet_tcp->pcapinit($dev, $filt_tcp, 1500, 60, 0);
$offset_tcp = linkoffset($pcap_tcp);
$p = Net::Ping->new("icmp");
if ($p->ping($host, 2)) {
 die "ICMP reply from $host recieved, host is up\n";
}
$p->close();
print "No ICMP reply...testing TCP\n";
if ($fork1 = fork) {
 &send;
}
if ($fork2 = fork) {
 loop $pcap_tcp, -1, \&check_tcp, \@packet_tcp;
}
sub check_tcp{
 print "TCP reply from $host recieved, host is up\n";
 kill(9, $fork1);
 die "\n";
}
sub send {
 sleep 3;
 foreach (1 .. 65535) {
  $a = new pdump::Sniff;
  $a->set({
   ip => {
        saddr => $ip,
        daddr => $host,
        },
   tcp => {
        dest => $_,
        source => 1337,
        seq => 31337,
        syn => 1,
        },
  });
  $a->send;
 }
 die "No TCP reply...host seems to not be up\n";
}
