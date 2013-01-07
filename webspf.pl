#!/usr/bin/perl
#
# Web Spoof
# Pavel Aubuchon-Mendoza [admin@deviance.org][http://www.deviance.org]
#
# Summary: 
# Works as a normal command line web retrieval script,
# except will spoof the referer. This can be left to the script to do,
# or specified in the command line. This will bypass any kind of reference
# checking, in most cases. Will also screw up the REMOTE_HOST variable which
# some cgi scripts use, but the correct IP will of course be sent. Default
# broswer is Netscape 4.5 under Win95. This can be changed in the script.
#
# Usage:  - default output is standard out, to save to a file
#           you will need to redirect it, especially for  
#           binary/image files -
#
#  ./webspf.pl [file] <referer>
#
# Examples:
#
#  ./webspf.pl language.perl.com/info/software.html > software.html
#      - referer would be language.perl.com/info/index.html -
#
#  ./webspf.pl www.linux.org/images/logo/linuxorg.gif > penguin.gif
#      - referer would be www.linux.org/images/logo/index.html -
#
#  ./webspf.pl www.linux.org/ www.freebsd.org/whatever.html > index.html
#      - referer would be www.freebsd.org/whatever.html -
#
#
# 


use IO::Socket;

$loc = $ARGV[0];                             # www.a.com/test.html
$temp = reverse($loc);                       # lmth.tset/moc.a.www
$host = substr($temp,rindex($temp,"\/")+1);  # moc.a.www
$host = reverse($host);                      # www.a.com
$dir = substr($loc,index($loc,"\/"));        # /test.html

$referer = $ARGV[1];                         # <blank>
if($referer eq "") {                         # true
 $temp = substr($temp,index($temp,"\/")+1);  # /moc.a.www
 $temp = reverse($temp);                     # www.a.com/
 $referer = $temp . "index\.html";           # www.a.com/index.html
 }                                           # spoofed referer!

print STDERR "\nWebSpoof v1.0 : 12/18/1998\n";
print STDERR "Pavel Aubuchon-Mendoza + http://www.deviance.org\n\n";

$res = 0;
$handle = IO::Socket::INET->new(Proto => "tcp",
   PeerAddr => $host,
   PeerPort => 80) or $res = 1;
if($res eq 0) {
 $handle->autoflush(1);
 print STDERR "\[Connected to $host\]\n";
 print $handle "GET $dir HTTP/1.0\n";
 print $handle "Referer: $referer\n";
 print $handle "Connection: Close\n";
 print $handle "User-Agent: Mozilla\/4.5 [en] \(Win95\; I\)\n";
 print $handle "Host: $host\n";  
 print $handle "Accept: image\/gif\, image\/x-xbitmap\, image\/jpeg\, image\/pjpeg\, image\/png\, *\/*\n";
 print $handle "Accept-Encoding: gzip\n";
 print $handle "Accept-Language: en\n";
 print $handle "Accept-Charset: iso-8859-1\,\*\,utf-8\n\n";
 while($temp ne "") { # read some headers
  $temp = <$handle>;
  chop($temp);chop($temp);
  @sort = split(/:/,$temp);
  if(@sort[0] =~ /server/i)  { print STDERR " \[$temp\]\n"; }
  if(@sort[0] =~ /date/i)    { print STDERR " \[$temp\]\n"; }
  if(@sort[0] =~ /content/i) { print STDERR " \[$temp\]\n"; }
  }
 print STDERR "\[Recieving data\]\n"; 
 binmode(STDOUT);
 while(<$handle>) {
  print "$_";
  }
 close($handle);
 print STDERR "\[Connection Closed\]\n";
 } else { print STDERR "\[Could not connect to $host\]\n"; }
