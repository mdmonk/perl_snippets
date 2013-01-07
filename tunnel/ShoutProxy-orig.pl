#!/usr/bin/perl
########################################################################
# Program Name:  ShoutProxy.pl
# Programmer(s): Ranger Rick and Maddog Monk
#
# Usage
#  ShoutProxy.pl <email alias> <proxy passwd> [ http://address:port ] 
#
# Explanation:
#  - This script acts as a forwarding proxy. 
#
#########################################################################
use IO::Socket;
use MIME::Base64;

$| = 1;

$logname = $ARGV[0];
$passwd = $ARGV[1];
$loc = $ARGV[2];
$loc = "http://www.loudfactory.com:8000/" if ($loc eq "");

print STDOUT <<END;

-----------------------------------------------------------------------------
ShoutCast Proxy
-----------------------------------------------------------------------------
  Usage: "ShoutProxy <id> <password> [ <address> ]"
     ex: "ShoutProxy MYID MyPassword http://www.loudfactory.com:8000/"

         *NOTE* Address not required. If blank, defaults to Loudfactory.

END

exit "Error: insufficient command line args!\n" if ($ARGV[1] eq "");

$host = "proxy.example.com";
$res = 0;

LOOP:

print STDOUT "[ ] Listening on port 8080\n";

$handle = IO::Socket::INET->new(Proto => "tcp",
          PeerAddr => $host,
          PeerPort => 8000) or $res = 1;

$incoming = IO::Socket::INET->new(
            Proto => "tcp",
            Listen => 1,
            LocalPort => 8080,
            Reuse => 1) or $res = 1;

while($incoming_connect = $incoming->accept()) {
  print STDOUT "[!] Connection!\n";
  $handle->autoflush(1);
  $incoming_connect->autoflush(1);
  print STDOUT "[*] Connected to Proxy\n";
  print $handle "GET $loc HTTP/1.0\n";
  print $handle "Connection: Close\n";
  print $handle "User-Agent: Mozilla\/4.5 [en] \(Win95\; I\)\n";
  print $handle "Accept: image\/gif\, image\/x-xbitmap\, image\/jpeg\, image\/pjpeg\, image\/png\, *\/*\n";
  print $handle "Accept-Encoding: gzip\n";
  print $handle "Accept-Language: en\n";
  print $handle "Proxy-Authorization: Basic " . MIME::Base64::encode("$logname:$passwd", '') . "\n";
  print $handle "Accept-Charset: iso-8859-1\,\*\,utf-8\n\n";
  while($temp ne "") { # read some headers
    $temp = <$handle>;
    chop($temp);chop($temp);
    @sort = split(/:/,$temp);
  }
  print STDOUT "[>] Receiving Data...\n"; 
  while(<$handle>) {
    $temp = $_;
    $incoming_connect->send($temp) || ($exitFlag = 1);
    if ($exitFlag == 1) {
      $exitFlag = 0;
      print STDOUT "[X] Closing Connection.\n\n";
      close($handle);
      close($incoming_connect);
      goto LOOP;
    }
  }
  close($handle);
  close($incoming_connect);
  print STDERR "\[Connection Closed\]\n";
};
