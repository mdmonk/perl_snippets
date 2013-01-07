#!/usr/bin/perl -w

use strict;
my $song;
my $lastSong = "";
my @songs;
my $DEBUG = 0;

if (scalar(@ARGV) == 0) {
    print "USAGE: $0 <filename>\n";
    print "The <filename> must be generated from iTunes' \"Export Song List\" function.\n";
    exit 1;
}

{
    # The exported file uses the Mac file delimeter.
    local $/ = "\r";
    my $file = shift;
    open(F, "$file") || die "Cannot open file '$file'.\n";
    @songs = <F>;
    close(F);
}

# Take off header row.
my $header = shift @songs;
if ($DEBUG) {
    # If you set $DEBUG, you'll see what each of the header fields are.
    # You can use this set which of the fields to use when determing dupes
    # (in the "map" statement a few lines down).
    my @header = split("\t", $header);
    for (my $i = 0; $i < $#header; $i++) {
	print "Field $i:\t$header[$i]\n";
    }
    print "\n";
}

# Consider four of the fields (Artist, Name, Album, Size) for the duplication calculation.
# If you set $DEBUG, some code above will print out what each of the header fields are,
# and then you can pick any fields to be included in the duplicate calculation here.
@songs = map { my @fields = split("\t"); "$fields[1]\t$fields[0]\t$fields[3]\t$fields[6]" } @songs;

@songs = sort(@songs);

foreach $song (@songs) {
    print "Looking at $song.\n" if ($DEBUG);
    if ($song eq $lastSong) {
	print "Duplicate: $song.\n";
    }
    else {
	$lastSong = $song;
    }
}
