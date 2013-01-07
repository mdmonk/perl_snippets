#!/usr/bin/perl	

use URI::Escape;
my $Escape=uri_escape($ARGV[0]);
my $Unescape=uri_unescape($ARGV[0]);

print "\nCleaned Up: $Unescape\n\nUrl Encoded: $Escape\n";

