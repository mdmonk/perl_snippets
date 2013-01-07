#!/usr/bin/perl
# change carriage return(^M) in a file to null 

@files=@ARGV;

foreach (<@files>) {
  $myfile=$_;

  if (-e $myfile) {
    $^I=".org";
    @ARGV=("$myfile");
    while (<>) {
      s/\015//;
      print;
    }
    print "$myfile\n";
  }
}

