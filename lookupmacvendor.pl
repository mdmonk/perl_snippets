#!/usr/bin/perl

my %cards;
my %ips;

open(ARP,"arp -an|") || die "Couldn't open arp table: $!\n";

print "Looking up OUIs.";
while(<ARP>) {
 chomp;
 my $addr = $_;
 my $ip = $_;
 $addr =~ s/.* ([\d\w]+:[\d\w]+:[\d\w]+):.*/$1/;
 $addr =~ s/\b([\d\w])\b/0$1/g;
 $addr =~ s/:/-/g;
 next unless $addr =~ /..-..-../;

 $ip =~ s/.*?(\d+\.\d+\.\d+\.\d+).*/$1/;
 print ".";
 $cards{$addr}||=`curl -sd 'x=$addr' http://standards.ieee.org/cgi-bin/ouisearch`;
 ($cards{$addr} =~ /Sorry!/) && ($cards{$addr} = "Unknown OUI: $addr");
 $ips{$ip} = $addr;
}
print "\n";
for(keys(%ips)) {
 # recommended fix from the web site. -CL
 $cards{$ips{$_}} =~ s/.*.hex.\s+([\w\s\,\.-]+)\n.*/$1/s;
# $cards{$ips{$_}} =~ s/.*.hex.\s+([\w\s\,\.]+)\n.*/$1/s;
 print "$_ -> $cards{$ips{$_}}\n";
}