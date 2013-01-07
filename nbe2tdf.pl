#!/usr/bin/perl -w
use strict;

if (! $ARGV[0]) { die ("Need to give me an input file.\n"); }
if (! $ARGV[1]) { die ("Need to give me a target file.\n"); }

our (@NessyNBE, @Split, @RiskLevel, @OutputTdf);
my $IgnoreID = "10.71.144.3-11018|10165|11138|10898|10900|10915|10940|18405|10680|10758";

open (InFile, "<$ARGV[0]") || die ("Unable to open input file.\n");
	@NessyNBE = <InFile>;
close (InFile);

foreach (@NessyNBE) {
		s/ \| / /g;
                s/\\n/ /g;
	if ($_ =~ /Risk [Ff]actor ? ?: ? ?(Medium|High|Critical)/i) {
		s/Solution ? ?: ?/\| Possible Solution: /g;
		s/Risk [Ff]actor ? ?: ? ?/\|/g;
                my @Split = split (/\|/, $_);
                my @RiskLevel = split (/ /, $Split[8] || "  Needs-Fixed");
                if ("$Split[2]-$Split[4]" !~ "$IgnoreID") {
                push (@OutputTdf, "$Split[2]\t$Split[3] - $Split[6]\t$Split[7]\t$RiskLevel[0]");
                }
        }
}

if (@OutputTdf) {
	open (OutFile, ">$ARGV[1]") || die ("Unable to open TDF output file.\n");
		foreach (@OutputTdf) {
	        	print (OutFile "$_\n");
		}
	close (OutFile);
}
else { print ("No high/critical results found.\n"); }

exit 0;
