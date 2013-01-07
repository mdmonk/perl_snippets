#!/usr/bin/perl

$status=`/etc/rc.d/init.d/sendmail status`;

unless ($status =~ /running/i) {
  $date=`/bin/date`;
  chomp($date);
  print "As of: $date\nSendmail appears to have stopped....restarting...\n\n";
  `/etc/rc.d/init.d/sendmail restart`;
}
#else {
#  print "Sendmail appears to be Ok. Status is:\n  $status\n\n";
#} # end
