#!/usr/bin/env perl

open (GEN, "<wcmc-memberlist-sorted.txt") || die ("cannot open memberlist.txt");
open (SEA, "<wcmc-mailinglist-sorted.txt") || die ("cannot open mailinglist.txt");

undef $/;

$gen = <GEN>;
$sea = <SEA>;
@gen = split /\n/, $gen;
@sea = split /\n/, $sea;

for $a (@gen) {
	chomp($a);
	@result = grep/^\Q$a\E$/, @sea;
	push (@final , @result);
}

for $b (@final) {
	print "$b\n";
}
# print "Search string that matches against general data:\t@final";
