#!/usr/bin/perl

$infile = "codered.64.fuckers";

open (INFILE, "<$infile") or die "Unable to open $infile: $!\n";

foreach ($line, INFILE) {
  my @ary = split ("\]\s", $line);
  foreach (@ary) {
    print "ary\[$i\]: $_\n";
  } # end foreach
  sleep 5;
}
close (INFILE);
