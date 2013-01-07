# getTime();
$fulltime = time();
print "Local time is: $fulltime\n"; 

sub getTime {
  (my $sec,my $min,my $hour,my $mday,my $mon,my $year,my $wday,my $yday,my $isdst) = localtime(time);
  $curtime = "$hour:$min:$sec";
  $mon = $mon + 1;
  $year = 1900 + $year;
  $curdate = "$mon/$mday/$year";
}
