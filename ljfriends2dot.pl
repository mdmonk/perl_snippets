#!/usr/bin/perl -w

# ljfriends2dot.pl, (c) 2004 Darxus@ChaosReigns.com, released under the GPL.
# 10/13/04 v0.10 initial release
#
# Outputs a .dot datafile which you should be able to graph with
# springgraph or graphviz (neato/dot).
#
# Usage:
# # ./ljfriends2dot.pl darxus > ljfriends.dot
# # cat ljfriends.dot | ./springgraph.pl > ljfriends.png
#
# The $cachedir variable below must me modified to point to a directory
# you can write to.
#
# http://www.chaosreigns.com/code/ljfriends2dot/
# http://www.chaosreigns.com/code/springgraph/
# http://www.research.att.com/sw/tools/graphviz/

$cachedir='/home/darxus/ljfriends';

$base = 'http://www.livejournal.com/misc/fdata.bml?user=';
$user = $ARGV[0];
$firstuser = $user;

use File::Path qw(mkpath);

undef $/; #don't break input on newlines

unless ($user) {
  die "Must specify lj username as commandline argument.\n";
}

use LWP::RobotUA
$ua = new LWP::RobotUA 'http://www.chaosreigns.com/code/ljfriends2dot/ v0.10', 'darxus@chaosreigns.com';
$ua->delay(0);

push @users,$user;
$queued{$user}=1;
$processed=0;

while (@users) {
  $user = shift @users;
  undef $content;
  if (-d "${cachedir}/${base}${user}") {
    opendir (CACHE,"${cachedir}/${base}${user}");
    $lastfile = 0;
    $latest = 0;
    for $file (readdir(CACHE)) {
      next if ($file eq '.' or $file eq '..');
      if ($file > $lastfile) {
        $latest = $file;
      }
    }
    closedir CACHE;
    if ($latest >= time - 864000) {
      open (INPUT,"${cachedir}/${base}${user}/$latest");
      print STDERR "Using fresh cache: ${base}${user}\n";
      $content = <INPUT>;
    } else {
      print STDERR "Stale cache: ${base}${user}\n";
    }
  } else {
    mkpath "${cachedir}/${base}${user}", 0, 0700 or die "Couldn't create cache directory $cachedir: $!\n";
    #`mkdir -p ${cachedir}/${base}${user}`;
  }
  
  unless (defined($content)) {
    print STDERR "Retrieving new data: ${base}${user}\n";
    $request = HTTP::Request->new('GET', "${base}${user}");
    $response = $ua->request($request);
    $content = $response->content;
    open OUTPUT, ">${cachedir}/${base}${user}/tmp";
    print OUTPUT $content;
    close OUTPUT;
    rename "${cachedir}/${base}${user}/tmp", "${cachedir}/${base}${user}/" . time;
  }

  for $line (split("\n",$content)) {
    if ($line =~ m#^> (.*)#) {
      $newuser = $1;
      $friendsof{$user}{$newuser}++;
      if ($user eq $firstuser) {
        unless ($queued{$newuser}) {
          push @users,$newuser;
          $queued{$newuser}=1;
        }
      }
    }
  }

  $processed++;
  print STDERR "processed: $processed, queued: " . scalar($#users +1) . "\n";
}

print "digraph \"\" {\n";

for $user (sort keys %friendsof) {
#  next if $user eq $firstuser;
  print "$user -> {";
  for $newuser (%{$friendsof{$user}}) {
    if (defined $friendsof{$firstuser}{$newuser} and  $friendsof{$firstuser}{$newuser} > 0) {
      print " $newuser";
    }
  }
  print " }\n";
}

print "}\n";
