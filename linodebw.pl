#!/usr/bin/perl -w

# linodebw.pl v0.3, (c) 1/24/07 Darxus@ChaosReigns.com, released under GPL v2 or above

# Monitors your linode bandwidth usage vs. your quota, reports actual
# bandwidth used, and estimated bandwidth used, both by month and by time
# period (3 hours by default) if you go over the threshold.  Also reports
# cost if you go over quota.
#
# Usage: ./linode.pl
# Runs continuously.  Run from init if you care about it not being up.
# You must modify the first three variables.
#
# local: total monthly bandwidth usage estimate based on data from /proc/net/dev over the last three hours
# month: total monthly bandwidth usage estimate based on linode xml over the current month
# period: total monthly bandwidth usage estimate based on linode xml over the last three hours
# used: actual total bandwidth used this month, from linode xml
#
# This must be run from an IP belonging to the user which is being queried.
#
# Do not assume anything this says is correct without verifying it yourself.
# Estimate based on the full month is incorrect for the first (incomplete)
# billing period.
#
# CHANGELOG
# v0.1 2007-01-24
# v0.2 2007-01-28 handles unavailability of linode xml
# v0.3 2007-02-02 resets "linode bandwidth monitoring errors"
# v0.4 2007-03-08 handle /proc/net/dev wrapping, and log quota
#
# BUGS:
# * for the estimation based on /proc/net/dev, the local timezone is used
#   instaed of Eastern (which linode uses) for calculation of the current
#   month used for calculation of days in a month used for calculating
#   gigabytes per month because localtime() doesn't allow specification of
#   a timezone.

$notify = 'darxus@chaosreigns.com'; # comma delimited list with no whitespace, comment out to prevent emailing
$user = 'darxus';
$logdir = "/home/darxus/linodebw"; # comment out this line if you don't want to log
#$threshold = 90;
#$threshold = 50; # percentage of quota at which you'd like to be emailed
#$threshold = 75; # percentage of quota at which you'd like to be emailed
$threshold = 200; # percentage of quota at which you'd like to be emailed
$price = 0.50; # cost per gigabyte over quota per month

# You are unlikely to need to modify anything below this line.
##############################################################

$url = "http://www.linode.com/members/info/?user=$user";
#$url = "http://www.linode.com/members/info/?user=$user-test";

use LWP::Simple;
use Date::Calc qw( Days_in_Month );
use Time::Local 'timelocal';
use Date::Parse 'str2time';

$delay = $ARGV[0] or $delay = 7200; # please don't set this lower, per linode

while (1)
{
  $text = '';
  $mail = 0;
  undef $error;
  print "\n";


  undef $total;
  undef $year;
  undef $month;
  undef $linodetime;

#  $linodetime = time;
  $content = get($url);
  for $line (split("\n",$content))
  {
    #print "line:$line\n";
    if ($line =~m#<max_avail>(\d+)</max_avail>#) {
      $quota = $1;
      $quotagb = $quota / 1024 / 1024 / 1024;
    }

    if ($line =~ m#<total_bytes>(\d+)</total_bytes>#) {
      $total = $1;
     # print "total:$total\n";
    }

    if ($line =~ m#<year>(\d+)</year>#) {
      $year = $1;
    }

    if ($line =~ m#<month>(\d+)</month>#) {
      $month = $1;
    }

    if ($line =~ m#<DateTimeStamp>(.*)</DateTimeStamp>#) {
      $linodetime = str2time($1);
    }


  }


  if ( (defined($year) and defined($month)) and (!defined($oldmonth) or $month != $oldmonth or !defined($oldyear) or $year != $oldyear) ) {
    #print "year/month: $year/$month\n";
    $days = Days_in_Month($year,$month);
    #print "days:$days\n";
    undef $oldtotal;
  }


  if (defined($quota) and defined($total) and defined($year) and defined($month) and defined($linodetime)) {
  
    
    $text .= "total bytes used this month:$total, quota: $quotagb gB, time from linode: $linodetime\n";
    $usedgb = $total / 1024 / 1024 / 1024;
    $usedpercent = $total * 100 / $quota;
    if ($usedpercent > 100) {
      $cost = ($usedgb - $quotagb) * $price;
    } else {
      $cost = 0;
    }
    $text .= "actual used $usedgb gB, $usedpercent% of $quotagb, extra bandwidth cost: \$$cost\n";
    $mail = $usedpercent if ($usedpercent >= $threshold and $usedpercent > $mail);
    if (defined($logdir)) {
      open OUT, ">>$logdir/linode.used.log" or print STDERR "Couldn't write to $logdir/linode.used.log: $!\n";
      print OUT "$linodetime $usedgb\n";
      close OUT;
    }
    open OUT, ">>$logdir/linode.quota.log" or print STDERR "Couldn't write to $logdir/linode.quota.log: $!\n";
    print OUT "$linodetime $quotagb\n";
    close OUT;
  
    $monthstart = timelocal(0,0,0,1,$month-1,$year);
    $monthseconds = $linodetime - $monthstart;
    $bytespersecond = $total / $monthseconds;
    $monthbytespermonth = $bytespersecond * $days * 86400;
    $monthgigabytespermonth = $monthbytespermonth / 1024 / 1024 / 1024;
    $monthpercent = $monthbytespermonth * 100 / $quota;
    if ($monthpercent > 100) {
      $cost = ($monthgigabytespermonth - $quotagb) * $price;
    } else {
      $cost = 0;
    }
    $text .= "est. from current month: $monthgigabytespermonth gB/m, $monthpercent% of $quotagb gb, extra bandwidth cost: \$$cost\n";
    $mail = $monthpercent if ($monthpercent >= $threshold and $monthpercent > $mail);
    if (defined($logdir)) {
      open OUT, ">>$logdir/linode.month.log" or print STDERR "Couldn't write to $logdir/linode.month.log: $!\n";
      print OUT "$linodetime $monthgigabytespermonth\n";
      close OUT;
    }
  
  
    if (defined($oldtotal)) {
      $elapsed = $linodetime - $oldlinodetime;
      $bytes = $total - $oldtotal;
      $bytespersecond = $bytes / $elapsed;
      $bytespermonth = $bytespersecond * $days * 86400;
      $ratepercent = $bytespermonth * 100 / $quota;
      $rategigabytespermonth = $bytespersecond * $days * 86400 / 1024 / 1024 / 1024;
      
      if ($ratepercent > 100) {
        $cost = ($rategigabytespermonth - $quotagb) * $price;
      } else {
        $cost = 0;
      }
  
      $text .= "est. calculated from last time sample: $rategigabytespermonth gB/m, $ratepercent% of $quotagb gb, extra bandwidth cost: \$$cost\n";
      $mail = $ratepercent if ($ratepercent >= $threshold and $ratepercent > $mail);
      if (defined($logdir)) {
        open OUT, ">>$logdir/linode.period.log" or print STDERR "Couldn't write to $logdir/linode.period.log: $!\n";
        print OUT "$linodetime $rategigabytespermonth\n";
        close OUT;
      }
    }
    $oldtotal = $total;
    $oldyear = $year;
    $oldmonth = $month;
    $oldlinodetime = $linodetime;
    $total = 0;
  } else {
    $text .= "Failed to retrieve XML.\n";
    $error++;
  }


  undef $localtotal;
  $localtime = time;
  open(IN,"</proc/net/dev") or print STDERR "Couldn't read /procnet/dev: $!\n";
  <IN>; # skip first two lines
  <IN>;
  while ($line = <IN>) {
    ($dev,$data) = split(/:/,$line);
    $dev =~ s/\s*//g;

    ($rx,$tx) = (split(' ',$data))[0,8];

    $localtotal += $rx + $tx unless ($dev eq 'lo');
  }
  close IN;
#  print "QUOTA IS HARDCODED\n";
#  $quota = 80530636800;
#  $quotagb = 75;
  if (defined($quota) and defined($localtotal)) { 
    if (defined($oldlocaltime)) {
      ($month,$year) = (localtime($localtime))[4,5];
      $month++;
      $year += 1900;
#      print "month/year:$month/$year\n";
      $days = Days_in_Month($year,$month);
      $elapsed = $localtime - $oldlocaltime;
      $bytes = $localtotal - $oldlocaltotal;
      $bytespersecond = $bytes / $elapsed;
      $gigabytespermonth = $bytespersecond * $days * 86400 / 1024 / 1024 / 1024;
      $percent = $gigabytespermonth * 100 / $quotagb;
      if ($percent > 100) {
        $cost = ($gigabytespermonth - $quotagb) * $price;
      } else {
        $cost = 0;
      }
      if ($gigabytespermonth < 0) {
        $text .= "Local counter wrapped, not calculating this time.\n";
      } else {
        $text .= "est. from local data for current period: $gigabytespermonth gB/m, $percent% of $quotagb gb, extra bandwidth cost: \$$cost\n";
      }
      $mail = $percent if ($percent >= $threshold and $percent > $mail);
      if (defined($logdir) and $gigabytespermonth >= 0) {
        open OUT, ">>$logdir/linode.local.log" or print STDERR "Couldn't write to $logdir/linode.local.log: $!\n";
        print OUT "$localtime $gigabytespermonth\n";
        close OUT;
      }
    }
    $oldlocaltime = $localtime;
    $oldlocaltotal = $localtotal;
  } else {
    $text .= "Missing either quota or /proc/net/dev data.\n";
    $error++;
  }


  print $text;
  if ($mail > 0 and defined($notify)) {
    `/bin/echo '$text' | /usr/bin/mail -s \"linode bandwidth usage at $mail% of quota\" $notify`;
    print "sent alert to $notify\n";
  }
  if (defined($error) and $error > 0 and defined($notify)) {
    `/bin/echo '$text' | /usr/bin/mail -s \"linode bandwidth monitoring error\" $notify`;
    print "sent error to $notify\n";
  }

  sleep $delay;
} 
