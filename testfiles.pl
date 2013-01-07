#!/usr/bin/env perl

use List::Compare;
use strict;
my $mailinglist="wcmc-mailinglist-sorted.txt";
my $memberlist="wcmc-memberlist-sorted.txt";

open (F, "$memberlist")||die("$memberlist File cannot open\n");
open (S, "$mailinglist")||die("$mailinglist File cannot open\n");
my @a=<F>;
my @b=<S>;
my $lcma = List::Compare->new(\@a, \@b);
print "Extra present in $mailinglist:\n";
print $lcma->get_complement ,"\n"; # extra present in the second array 
print "Extra present in $memberlist:\n";
print $lcma->get_unique ,"\n"; # extra present in the First array
