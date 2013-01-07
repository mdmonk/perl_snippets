#!/usr/bin/perl
######################################################
# Program Name: sd_collect.pl
# Programmer: Chuck Little
# Desc:
#   This script collects the headlines from 
#   Slashdot.org and Freshmeat.net, puts 
#   them in a file, and page us with the 
#   headlines.
# TO DO:
#   - Need to be able to split file if larger than 
#     250 characters; and page person with both 
#     parts of the file.
######################################################
# Check for command line arguments.
unless ($#ARGV == 0) {
  print "\n-- Utility to collect data from Slashdot and Freshmeat --\n";
  print "Usage:  perl sd_collect.pl <-s/-f/-b>\n";
  print "(-s for Slashdot, -f for Freshmeat, -b for both)\n";
}
if ($ARGV[0] ne "-s" && $ARGV[0] ne "-f" && $ARGV[0] ne "-b") {
  die "Incorrect command line switch! Type sd_collect.pl with no switches for usage.\n";
}  

# directory to work in on Win32 systems:
# $dir = "c:\\tmp\\output\\";
# $rmcmd = "del";
# $lynxcmd = "d:\\apps\\lynx\\lynx.exe -cfg=d:\\apps\\lynx\\lynx.cfg -dump";
# on unix boxes:
# $dir = "/home/$ENV{"LOGNAME"}/paging/output/";
$lynxcmd = "lynx -dump";
$dir = "/tmp/output/";
$rmcmd = "rm -f";

#our work-file
$outsd = "articles.out";
$outfm = "fresh.out";
$length = 0;
# $userid = $ARGV[1];
# $passwd = $ARGV[2];

if (-e "$dir$outsd") {
  system("$rmcmd $dir$outsd");
}
if (-e "$dir$outfm") {
  system("$rmcmd $dir$outfm");
}

if ($ARGV[0] eq "-s") {
  $header = "*Slashdot News*";
  getSlash();
  print "Length of SD output: $length\n";
} elsif ($ARGV[0] eq "-f") {
  $header = "*Freshmeat News*";
  getFM();
  print "Length of FM output: $length\n";
} elsif ($ARGV[0] eq "-b") {
  $header = "*Slashdot News*";
  getSlash();
  print "Length of SD output: $length\n";
  $header = "*Freshmeat News*";
  getFM();
  print "Length of FM output: $length\n";
}
1;
# end main
##################
# Subroutines
#######################
# getSlash
#  - Get articles from
#    Slashdot
#######################
sub getSlash {
  print "Gathering Slashdot Articles...\n";
  $data=0; # variable to signify that we are into the article portion of the file "ultramode.txt".
  $g2g=0;  # Good2Go. means ok to write out the article title.
#  @sd=`lynx -dump http://slashdot.org/ultramode.txt`;
  @sd=`$lynxcmd http://slashdot.org/ultramode.txt`;
  open OUT, ">$dir$outsd";
  print OUT "$header\n";
  $length = $length + length($header);
  foreach $line (@sd) {
    if($line =~ /^%%/) {
      $data=1;
      $g2g = 1;
    } elsif($data && $g2g && $line !~ /^\n/) {
      print OUT "*"."$line";
      $g2g = 0;
      $length = $length + length($line) + length("*");
    }
  }
  close OUT;
} # end getSlash
######################
# getFM
#  - Get info from FM
######################
sub getFM {
  print "Gathering Freshmeat Info...\n";
#  @fm=`lynx -dump http://files.freshmeat.net/freshmeat/recentnews.txt`;
  @fm=`$lynxcmd http://files.freshmeat.net/freshmeat/recentnews.txt`;
  open FOUT, ">$dir$outfm";
  print FOUT "$header\n";
  $length = $length + length($header);
  foreach $line2 (@fm) {
    print FOUT "*"."$line2";
    $length = $length + length($line) + length("*");
    shift (@fm);
    shift (@fm);
  }
  close FOUT;
} # end getFM
