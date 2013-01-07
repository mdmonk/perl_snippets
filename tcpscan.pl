#!/usr/bin/perl
# This is a simple script that scans a machine for reachable TCP ports.
# usage : tcpscan <hostname> [maxtcp]
# Apr 96 Rob J Meijer  rmeijer@xs4all.nl
#

$|=1;
$tghost=$ARGV[0];
if ($#ARGV>0)
{
   $maxprt=$ARGV[1];
}
else
{
   $maxprt=1500;
}
$AF_INET=2;
$SOCK_STREAM=1;
$sockaddr='S n a4 x8';
chop ($hostname='hostname');
($name,$aliases,$proto)=getprotobyname('tcp');
foreach $port (1 .. $maxprt)
{
 ($name,$aliases,$port)=getservbyname($port,'tcp')
   unless $port=~ /^\d+$/;;
 ($name,$aliases,$type,$len,$thisaddr)=gethostbyname($hostname);
 ($name,$aliases,$type,$len,$thataddr)=gethostbyname($tghost);
 $this=pack($sockaddr,$AF_INET,0,$thisaddr);
 $that=pack($sockaddr,$AF_INET,$port,$thataddr);
 if ($thataddr eq "")
 {
  die   "non existing host";
 }
 if (socket(S,$AF_INET,$SOCK_STREAM,$proto))
 {
 }
 else
 {
  die $!;
 }
 if (bind(S,$this))
 {
 }
 else
 {
  die $!;
 }
 if (connect(S,$that))
 {
   ($srv_name,$srv_aliases,$srv_port,$srv_proto)=getservbyport($port,'tcp');
   print "\r$port  $srv_name\n";
   close(S);
 }
 else
 {
  print "\r($port)";
 }
}
print "\r               \n";
