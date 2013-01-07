#!/usr/bin/perl
my $Ascii = shift || die "Usage: $0 <string>\n";
	$Ascii =~ s/[^a-fA-F0-9]//gi;
#print "Char: $Ascii\n";
#my $Ascii =~ s/00//gi;
#my $Ascii =~ s/ //gi;
#print $Ascii;
my $Hex = pack "H*", $Ascii;
print "$Hex\n";

exit 0;
