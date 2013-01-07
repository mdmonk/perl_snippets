#!/usr/bin/perl -w
use strict;

use MIME::Base64;
$SIG{INT} = "CTLBreak";

if (! $ARGV[0]) {die "You should give me a base64 encoded string\n";}

my $Decoded = decode_base64($ARGV[0]);

print "The string says: $Decoded\n";

exit 0;

sub CTLBreak{ die "Dude, nextime just wait for this shit to finish!\n"; }
