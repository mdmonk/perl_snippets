#!/usr/bin/perl
#
# Splits a certficate file with multiple entries up into
# one certificate perl file
#
# Artistic License
#
# v0.0.1         Nick Burch <nick@tirian.magd.ox.ac.uk>
#

my $filename = shift;
unless($filename) {
  die("Usage:\n  cert-split.pl <certificate-file>\n");
}

open INP, "<$filename" or die("Unable to load \"$filename\"\n");

my $ifile = "";
my $thisfile = "";
while(<INP>) { 
   $ifile .= $_; 
   $thisfile .= $_;
   if($_ =~ /^\-+END(\s\w+)?\sCERTIFICATE\-+$/) {
      print "Found a complete certificate:\n";
      print `echo "$thisfile" | openssl x509 -noout -issuer -subject`;
      print "\n";
      print "What file should this be saved to?\n";

      my $fname = <>;

      open CERT, ">$fname";
      print CERT $thisfile;
      close CERT;

      $thisfile = "";

      print "Certificate saved\n\n";
   }
}
close INP;

print "Completed\n";
