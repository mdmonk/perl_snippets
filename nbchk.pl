#!/usr/bin/perl
################################################################################
# NBChk v0.1 by h1kari                                                         #
################################################################################
# [http://www.nfsg.org] (Nightfall Security Group)                             #
# Usage: nbchk.pl <-c<config_file>><[-n<network>][-f<file>][-s<host>]>[-r]     #
# Network Syntax: <xxx.xxx.xxx[.[<min>-]<max>]>                                #
# Simple vulnerability scanning program that checks certain ports for certain  #
# strings within banners. Can also be configured to execute a command and then #
# parse the output. You can specify for it to scan a class c network, hosts    #
# from a file, or a single host.                                               #
#                                                                              #
################################################################################
# Config Syntax: <port=<port> inc='<data>'> [cmd='<command>']                  #
################################################################################
#                                                                              #
# e.g., to check all of the first 16 computers on a class c subnet for qpop on #
#       port 110 and if they are using iis for their webserver on port 80, you #
#       can do the following:                                                  #
#  $ echo "port=110 inc='qpop'                                                 #
#  > port=80 inc='iis' cmd='HEAD / HTTP/1.1\nConnection: close\nHost: nfsg.org #
#  \n\n'" > config                                                             #
#  $ chmod 755 nbchk.pl                                                        #
#  $ ./nbchk.pl -c config -n 192.168.0.16                                      #
#                                                                              #
#  note: you can use 192.168.0.16-32 to scan from 16 to 32, or 192.168.0 to    #
#        scan the whole subnet.                                                #
#                                                                              #
################################################################################
# Options                                        # Description                 #
################################################################################
my($maxreadlen)=256;                             # max number of chars to read #
my($childnum)  =10;                              # number of children to spawn #
my($timeout)   =5;                               # number of tries before exit #
my($ver)       ='0.1';                           # just for easy verison ctrl  #
################################################################################

my(%opt,@hosts,@ports,@incs,@cmds);
my($i)=0;

use strict;
use Getopt::Std;
use Socket;
use FileHandle;

$SIG{'ALRM'}=sub { };

getopts("c:n:f:s:r",\%opt);

if(!$opt{'c'}) {
 print "-"x71 .
  "\nNBChk v$ver by h1kari [http://www.nfsg.org] (Nightfall Security Group)\n".
  "-"x71 ."\n".
  "Usage: nbchk.pl <-c<config_file>><[-n<network>][-f<file>][-s<host>]>[-r]\n".
  "                 -c: specifies the configuration file to use.\n".
  "                 -n: specifies the class c network to scan.\n".
  "                 -f: specifies a file of hosts to scan.\n".
  "                 -s: specifies a single host to scan.\n".
  "                 -r: specifies to try to resolve the ip addresses.\n\n";
 exit }

open CNF, "<$opt{'c'}";
if($opt{'n'}) { my(@net); my($min,$max)=(0,255);
 (($opt{'n'}=~/^([0-9]+)\.([0-9]+)\.([0-9]+)\.?([0-9\-]+)?$/) &&
  ($1>=0 && $1<=255) && ($2>=0 && $2<=255) && ($3>=0 && $3<=255)) ||
  die "Invalid network host address..\n"; @net=($1,$2,$3);
 if($4 && $4=~/^([0-9]+)\-?([0-9]+)?$/) {
  if($2) { $min=$1; $max=$2 }
  else { $max=$1 } }
 for($min..$max) { push @hosts, join '.', @net, $_ } }
elsif($opt{'f'}) {
 open IN, "<$opt{'f'}" || die "Invalid hosts file..\n";
 while(<IN>) { $_=~s/\n//g; push @hosts, $_ } close IN }
elsif($opt{'s'}) { @hosts=$opt{'s'} }
else { die "You must specify a host to scan..\n" }

while(<CNF>) {
 if($_=~/^port=([0-9]+)\s+inc='([^']+)'([^\n]*)$/i) {
  $ports[$i]=$1; $incs[$i]=$2;
  print "Config: using $ports[$i] to find '$incs[$i]'";
  if($3=~/^\s+cmd='([^']+)'$/i) { $cmds[$i]=$1; $cmds[$i]=~s/\\n/\n/g;
   print " with '$cmds[$i]'" }
  $i++ } print "..\n" }
close CNF;

map { my($j)=0; my($ip_addr); my($host)=$_;
 $ip_addr=gethostbyname $host || die "Unknown remote host $host..\n";
 for(0..$i) {
  if($j>=$childnum && ($j=0)) { while(wait!=-1) { wait } }
  if(!fork) { connectto($ip_addr,$_) } $j++ } } (@hosts);
while(wait!=-1) { wait }

sub connectto { my($j)=0; my($line); my($ip_addr,$num)=@_;
 $SIG{'ALRM'}='DEFAULT';
 alarm 1;
 socket SOCK, PF_INET, SOCK_STREAM, getprotobyname "tcp" ||
  die "Cannot create socket..\n";
 autoflush SOCK;
 if(connect(SOCK,sockaddr_in($ports[$num],$ip_addr))) {
  alarm 0; sleep 2;
  while(1) {
   alarm 5; sleep 1;
   if($cmds[$num]) { print SOCK $cmds[$num] }
   sysread SOCK, $line, $maxreadlen;
   ((length($line)==0 && $j>0) || $j==$timeout) && exit; $j++;
   if($line=~/$incs[$num]/i) {
    print rslvhost($ip_addr) .":$ports[$num]\n";
    exit } } }
 close SOCK; exit }

sub rslvhost { my($name); my($host)=$_[0];
 if($opt{'r'}) { $name=gethostbyaddr($host,AF_INET) }
 if(!$name) { $name=join '.', unpack('C4',$host) } return($name) }

exit;
