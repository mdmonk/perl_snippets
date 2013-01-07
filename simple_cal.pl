#!/usr/bin/perl -w

use strict;
use Calendar::Simple;

my @months = qw(January February March April May June July August September October November December);

my $mon = shift || (localtime)[4] + 1;
my $yr = shift || ((localtime)[5] + 1900);

my @month = calendar($mon, $yr);

print "\n$months[$mon -1] $yr\n\n";
print "Su Mo Tu We Th Fr Sa\n";
foreach (@month) {
  print map { $_ ? sprintf "%2d ", $_ : '   ' } @$_;
  print "\n";
}

