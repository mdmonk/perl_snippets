#!/usr/bin/perl -w
# $Id$

use strict;

my $pattern = "<img [^>]*>";

my @images;
my $temp;

while (<>) {
	while (/$pattern/i) {
		$temp = $&;
		push(@images,$temp);
		$_ =~ s/$temp//;
	}
}

print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print "<html><head></head>\n<body bgcolor=\"white\">\n";
foreach (@images) {
	($temp = $_) =~ s/^.*src="([^"]*)".*$/$1/;
	print "<dl>\n<dt>$temp</dt>\n<dd>$_</dd>\n</dl>\n";
}
print "</body></html>\n";

