getTime();
print "Current time is: $curtime\n";
print "Current date is: $curdate\n";
$mytime = time();
print "Seconds since the epoch is: $mytime\n";

sub getTime {
  (my $sec,my $min,my $hour,my $mday,my $mon,my $year,my $wday,my $yday,my $isdst) = localtime(time);
  $curtime = "$hour:$min:$sec";
  $mon = $mon + 1;
  $year = $year + 1900;
  $curdate = "$mon/$mday/$year";
} # end getTime
