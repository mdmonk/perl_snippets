#!/usr/bin/perl

##Quickly hacked together script to pull the groups a user belongs to based on a 
##text file or single name. 

if (! $ARGV[0]) { die "Please supply me with a file with users or a users name to lookup.\n"; }


my @Users;
my $SMBAcct="denws4scout%9E_pu=rEZEwR";
my $ADServer="10.71.247.77";

open (Inf, "<$ARGV[0]") or @Users = "$ARGV[0]";
	unless (@Users) { @Users = <Inf>; }
close (Inf);


foreach (@Users) {
	chomp;
	$Lookup = `net -U \'$SMBAcct\' -S $ADServer user info $_`;
	$Lookup =~ s/\n/ /g;
	print "$_:$Lookup\n";
}

