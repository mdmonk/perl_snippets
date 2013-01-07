#!/usr/bin/perl
my $Hex = shift || die "Usage: $0 <string>\n";
my $Ascii = unpack 'H*', $Hex;

print "$Ascii\n";

exit 0;
