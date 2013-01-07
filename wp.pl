#!/usr/bin/perl
######################################################
# Program Name: wp.pl
# Programmer: Chuck Little
# Desc:
#   This script collects the Snow Report from 
#   Winter Park.
######################################################
# Check for command line arguments.
if ($ARGV[0] eq "-h") {
  print "\n-- Utility to collect the Snow Report from Winter Park --\n";
  print "Usage:  perl wp.pl\n\n";
  exit;
}

$VERSION = "1.0.0";

$debug = 0;  # 0 is Debugging off, 1 is Debugging on.
$lynxcmd = "lynx -dump";
$dir = "/tmp/";
$rmcmd = "rm -f";

#our work-file
$outwp = "snow.out";
$length = 0;

if (-e "$dir$outwp") {
  system("$rmcmd $dir$outwp");
}

$header = "*WP Snow Report*";
getWP();

1;
# end main
##################
# Subroutines
#######################
# getWP
#  - Get Snow Report from
#    Winter Park.
#######################
sub getWP {
  if ($debug) {
    print "Gathering WP Snow Report...\n";
  }
  @wp=`$lynxcmd http://www.skiwinterpark.com/terrain/SnowReport.html`;
  open OUT, ">$dir$outwp";
  print OUT "$header\n";
  foreach $line (@wp) {
    if($line =~ /^\s+New Snow in/) {
      $line =~ s/^\s+//;
      print OUT "*"."$line";
    }
  }
  close OUT;
} # end getWP
