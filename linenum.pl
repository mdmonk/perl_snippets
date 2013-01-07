#!/usr/bin/perl
########################################################
# 
# Take an input file, and outputs it as a file with
# line numbers.
########################################################
print "Enter the file you want line numbered: ";
$filename1=<STDIN>;
print "Enter the filename you want this stored in: ";
$filename2=<STDIN>;
chomp($filename1);
chomp($filename2);
open(FILE,"$filename1") || die "Can not open $filename1: $!";
open(OUT,">$filename2") || die "Can not open $filename2: $!";
$num = 1;
while (<FILE>)
    {
      print OUT "$num: $_";
#      print "$num: $_";
      $num++;
    }
print "\n$filename1 linenumbered and outputted to $filename2.\n";
print "Total lines: " . --$num . "\n";
close FILE;
close OUT;
