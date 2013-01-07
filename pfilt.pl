#!/usr/bin/perl

# This code is being released under GNU liscence
# The code was hacked by Royans K Tharakan rkt@pobox.com
# This is alpha version 0.001 :)
# date 9th March 2000

use Net::RawIP qw(:pcap);
require 'getopts.pl';
Getopts('m:q:w:t:h:s:d');

$|=1;

## This is a network snooper... 

$dev='ppp0';
$ip_addr=${ifaddrlist()}{$dev};

$packet_udp=new Net::RawIP({udp=>{}});
$packet_tcp=new Net::RawIP({tcp=>{}});
$packet_icmp=new Net::RawIP({icmp=>{}});

$filt_udp="ip proto \\udp";
$filt_tcp="ip proto \\tcp";
$filt_icmp="ip proto \\icmp";

$pcap_tcp=$packet_tcp->pcapinit($dev,$filt_tcp,1500,60);
$pcap_udp=$packet_udp->pcapinit($dev,$filt_udp,1500,60);
$pcap_icmp=$packet_icmp->pcapinit($dev,$filt_icmp,1500,60);

$offset_tcp = linkoffset($pcap_tcp);
$offset_udp = linkoffset($pcap_udp);
$offset_icmp = linkoffset($pcap_icmp);

if (fork){ loop $pcap_tcp,-1,\&check_tcp,\@packet_tcp;} 
if (fork){ loop $pcap_udp,-1,\&check_udp,\@packet_udp;}
if (fork){ loop $pcap_icmp,-1,\&check_icmp,\@packet_icmp;}

sub check_tcp{
my $time = timem();
$packet_tcp->bset($_[2],$offset_tcp);
$proto=$packet_tcp->proto;
my ($saddr,$daddr,$sport,$dport,$urg,$ack,$psh,$rst,$syn,$fin,$data)=
$packet_tcp->get({ip=>['saddr','daddr'],tcp=>['source','dest','urg','ack','psh','rst','syn','fin','data']});
print "T "; 
if ($urg) {print "U"};
if ($ack) {print "A"};
if ($psh) {print "P"};
if ($rst) {print "R"};
if ($syn) {print "S"};
if ($fin) {print "F"};
#print " tos=$tos window=$window";
if ($saddr > $daddr)
	{
	print "\t",ip2name($saddr), ":$sport \t -> \t",ip2name($daddr),":$dport ";
	}
else
	{
	print "\t",ip2name($daddr), ":$dport \t <- \t",ip2name($saddr),":$sport ";
	}

print "\n";
printf "$data \n";
}

sub check_udp{
my $time = timem();
$packet_udp->bset($_[2],$offset_udp);
my $proto=$packet_udp->proto;
my ($saddr,$daddr,$sport,$dport)=$packet_udp->get({ip=>['saddr','daddr'],udp=>['source','dest']});
print "U ",ip2name($saddr), ":$sport \t -> \t",ip2name($daddr),":$dport \n";
}

sub check_icmp{
my $time = timem();
$packet_icmp->bset($_[2],$offset_icmp);
$proto=$packet_icmp->proto;
my ($saddr,$daddr,$sport,$dport)=$packet_icmp->get({ip=>['saddr','daddr'],udp=>['source','dest']});
print "I ",ip2name($saddr), ":$sport \t -> \t",ip2name($daddr),":$dport \n";
}

sub ip2name {
my $addr = shift;
(gethostbyaddr(pack("N",$addr),AF_INET))[0] || ip2dot($addr);
}

sub ip2dot {
sprintf("%u.%u.%u.%u",unpack "C4", pack "N1", shift);
}



