#!/usr/bin/perl
# apache2dot.pl v0.15 (C) Darxus@ChaosReigns.com, released under the GPL
# Download from: http://www.chaosreigns.com/stats/apache2dot/
#
# Parses an apache log file into a directed graph file suitable
# for use with neato or dot, which are part of graphviz
# (http://www.research.att.com/sw/tools/graphviz/) like so:
#
# cat /var/log/apache/www.chaosreigns.com-access.log | ./apache2dot.pl yourdomain.com 2> /dev/null > apache.dot
# neato -Tps apache.dot > apache.ps
# gv apache.ps
#
# If you specify 1 doman name as an argument, only the path and filename of the
# referrer will be displayed.  
# If you specify 0 or more than 1 domains, the full url of referers will be displayed.
# Multiple domain names may be specified like so:
#
# cat /var/log/apache/www.chaosreigns.com-access.log | ./apache2dot.pl chaosreigns.com speechio.org 2> /dev/null > apache.dot
# neato -Tps -Gsplines=true -Gsep=.1 apache.dot > apache.ps
# convert apache.ps apache.jpg
#
# changelog:
# v0.2 2000-09-13 22:52 took lookfilename from the commandline
# v0.3 2000-09-13 22:54 take logfile directly from stdin
# v0.4 2000-09-18 15:50 un hardcode domain name (DOH)
#                       reported by: Matthew Harrell <mharrell@bittwiddlers.com>
# v0.5 2000-09-18 16:12 take the whole host name as an arg
# v0.6 2000-09-18 17:04 take any part of the hostname as an arg
# v0.7 2000-09-18 17:10 cleaned up hostname case desensitization
# v0.8 2000-09-18 17:40 take any number of hostnames as args (including 0)
# v0.9 2000-09-18 20:07 only strip hostnames if there's exactly 1 specified
# v0.10 Dec 12 19:01    darkness of lines is proportional to useage
#                       re-added missing leading / on internal referrers
# v0.11 Dec 12 22:56    Accounted for overlapping lines while shading
# v0.12 Dec 12 23:14    Don't store a count in %edge
# v0.15 Dec  2 2005     Show only top $maxcount edges
#                       Improved referer regex
#                       unsort edges since graphviz draws them nicer now
#
# todo:
# * imagemap
# * colorize nodes by # of hits

$maxedgecount = 40;

#print STDERR "arg count:$#ARGV:\n";
print "digraph \"apache log\" {\n";
while ($line = <STDIN>)
{
  #if ($line =~ m#([^ ]+) [^ ]+ [^ ]+ \[([^/]+)/([^/]+)/([^:]+)\:([^:]{2})\:[^:]{2}\:[^ ]{2} [^ ]{5}\] \"([^ ]+) ([^ ^?]+)[^ ]* ([^ ]+)\" ([^ ]+) [^ ]+ ?\"?([^"]*)\"? ?\"? ?([^"]*)\"?#)
  if ($line =~ m#([^ ]+) [^ ]+ [^ ]+ \[([^/]+)/([^/]+)/([^:]+)\:([^:]{2})\:[^:]{2}\:[^ ]{2} [^ ]{5}\] \"([^ ]+) ([^ ]+) ([^ ]+)\" ([^ ]+) [^ ]+ ?\"?([^"]*)\"? ?\"? ?([^"]*)\"?#)
  {

    $referrer = $10;
    next if $referrer eq '-';
    $file = $7;

    if (&ckmatch)
    {
      $referrer = "/".(split('/',$referrer,4))[3] if ($#ARGV == 0);
      $key = join(' ',($referrer,$file));
      $edge{"$referrer $file"}=1;
      $count{$key}++; 
      if ($count{$key} > $maxcount)
      {
        $maxcount = $count{$key};
      }
    } else {
      #print STDERR "Didn't match: $referrer\n";
    }
  } else {
    print STDERR "Didn't match regex: $line\n";
  }
}

$edgecount = 0;
#for $key (keys %edge)
for $key (sort {$count{$b} <=> $count{$a}} keys %count)
{
  $edgecount++;
  ($referrer,$file) = split(' ',$key);
  #$mycount = $count{join(' ',($referrer,$file))} ;
  $mycount = $count{$key} ;
  #next unless ($mycount >= 60);
  $color = scalar(1-$count{join(' ',($referrer,$file))}/$maxcount);
  #print $key." [style=bold,len=5,color=\"0,0,$color\",label=\"$color\"]\n";
  #print "\"$referrer\" -> \"$file\" [label=\"$color\",style=bold,len=5,color=\"0,0,$color\"]\n";
  #print "\"$referrer\" -> \"$file\" [style=bold,len=5,color=\"0,0,$color\"] # $mycount\n";
  print "\"$referrer\" -> \"$file\" [style=bold,len=2,color=\"0,0,$color\"]\n";
  last if ($edgecount >= $maxedgecount);
}

print "}\n";


sub ckmatch
{
#  print STDERR "arg count:$#ARGV:\n";
  return 1 if ($#ARGV == -1);
  for $element (@ARGV)
  {
    return 1 if ($referrer =~ m#^https?://[^\/]*$element/#i);
  }
  return 0;
}
