#!/usr/bin/perl -w
use strict;


print "Whats the domain? ";
	chomp (my $Domain = <STDIN>);
print "Gimme the cookie:\n";
	chomp (my $Cookie = <STDIN>);
$Cookie =~ s/Cookie: //g;
my @CookieFixup = split (/; /, $Cookie);

print "\n-=-=-=-=-Baked Cookie:-=-=-=-=-\n\n";
foreach (@CookieFixup) {
	print "Set-Cookie: $_; path=/; domain=.$Domain\n";
}
print "\n";
exit 0;
