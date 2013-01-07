#!/usr/bin/perl
# written by roelof@sensepost.com http://www.sensepost.com
# original name unicodecheck.pl
# Usage: wwwtype IP:port
# Only makes use of "Socket" library
# Roelof Temmingh 2000/10/21
#
# modified by guy@crypto.org.il
# TODO: add scans for multiple IPs

use Socket;
# --------------init
if ($#ARGV<0) {die "Usage: www-type.pl IP:port\n";}
($host,$port)=split(/:/,@ARGV[0]);
print "Testing $host:$port ...\n";
$target = inet_aton($host);
$flag=0;
my @results=sendraw("HEAD / HTTP/1.0\r\n\r\n");
foreach $line (@results){
if ($line =~ /Server/) {$flag=$line;}}
if ($flag eq "0") {print "Server type unknown.\n"; exit; }
print "$flag";
# ------------- Sendraw - thanx RFP rfp@wiretrip.net
sub sendraw {   # this saves the whole transaction anyway
        my ($pstr)=@_;
        socket(S,PF_INET,SOCK_STREAM,getprotobyname('tcp')||0) ||
                die("Socket problems\n");
        if(connect(S,pack "SnA4x8",2,$port,$target)){
                my @in;
                select(S);      $|=1;   print $pstr;
                while(<S>){ push @in, $_;}
                select(STDOUT); close(S); return @in;
        } else { die("Can't connect...\n"); }
}
# Spidermark: sensepostdata


