#!/usr/bin/perl

$dir     = "/tmp/";
$file    = "test.cwl";
$file2   = "groovy.cwl";
$maxLogs = 5;

@tmp     = qw(205.171.0.1 205.171.0.2 205.171.0.3 205.171.0.4);

#logRotate ("$dir$file");
#logRotate ("$dir$file2");

sub logRotate {
  my $fName = shift;
  for (my $s=$maxLogs; $s--; $s >= 0 ) {
      my $oName = $s ? "$fName.$s" : $fName;
      my $nName = join(".",$fName,$s+1);
      rename $oName,$nName if -e $oName;
  } # end for
  system("touch $fName");
} # end logRotate

$_ = join(', ', @tmp);
print "\@tmp is: $_\n";
