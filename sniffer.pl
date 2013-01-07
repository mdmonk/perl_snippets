#!/usr/bin/perl

$LIMIT = shift || 5000;

$|=1;
open (STDIN,"/usr/sbin/tcpdump -lnx -s 1024 dst port 80 |");
while (<>) {
    if (/^\S/) {
	last unless $LIMIT--;
	while ($packet=~/(GET|POST|WWW-Authenticate|Authorization).+/g)  {
	    print "$client -> $host\t$&\n";
	}
	undef $client; undef $host; undef $packet;
	($client,$host) = /(\d+\.\d+\.\d+\.\d+).+ > (\d+\.\d+\.\d+\.\d+)/
	    if /P \d+:\d+\((\d+)\)/ && $1 > 0;
    }
    next unless $client && $host;
    s/\s+//;
    s/([0-9a-f]{2})\s?/chr(hex($1))/eg;
    tr/\x1F-\x7E\r\n//cd;
    $packet .= $_;
}
