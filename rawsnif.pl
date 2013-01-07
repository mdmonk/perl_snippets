#!/usr/bin/perl
################################################################################
# RawSnif v0.8 by David Hulton, for Perl with Net::RawIP mods.                 #
################################################################################
# [http://www.nfsg.org] (Nightfall Security Group)                             #
# Usage: rawsnif.pl [-c<config_file>][-d<device>][-o<outfile>][-e][-r][-n][-h] #
# Net::RawIP libpcap based packet sniffer for Linux/*BSD systems.              #
# Defaults to sniff ports 21, 110, and 143, but can be configured by           #
# creating a config file and running ./rawsnif.pl -c <config_file> where       #
# port numbers are preceded by dst= or src= to designate destination or        #
# source. You may also add additional arguments afterwards to print only       #
# certain lines of data, such as dst=21 inc=USER, would only print lines       #
# captured on port 21 which include the words "USER". You can also use and/or  #
# statements by separating the criteria with a |. You may also use exc= which  #
# will only print lines not containing the information specified. A new option #
# is that you may also specify a ip or host address in the dst= or src= and I  #
# have also added reverse dns lookup on ip addresses for the output which can  #
# be activated by using the -r option. One last thing that I have added as of  #
# v0.8 is the -e command which will allow you to print everything on the       #
# network.                                                                     #
#                                                                              #
################################################################################
# Config Syntax: <<dst|src>=<port|address:port>> [inc=data] [exc=data]         #
################################################################################
#                                                                              #
# e.g., if you want to only log ftp and pop3 logins and passwords to 'log'     #
#       from nfsg.org but also everything on port 25:                          #
#  $ echo "dst=nfsg.org:21 inc=USER|PASS                                       #
#  > dst=nfsg.org:110 inc=USER|PASS                                            #
#  > dst=25" > config                                                          #
#  $ su                                                                        #
#  Password:                                                                   #
#  # chmod 755 rawsnif.pl                                                      #
#  # ./rawsnif.pl -c config -o log                                             #
#                                                                              #
################################################################################
# Optional Configuration Settings                                # Descriptions#
################################################################################
my($psize)=1024;                                                 # Buffer Size #
my($ptout)=64;                                                   # Timeout     #
my($ip)=20;                                                      # iphdr size  #
                                                                 # filter      #
my($pfil)="tcp and ( dst port 21 or dst port 110 or dst port 143 )";           #
################################################################################

my($p,@p,%s,%d,$pdev,$psck,$offset,$pckt,%opt);

use Net::RawIP;
use Socket;
use sigtrap 'handler',\&close_pcap,'normal-signals';
use FileHandle;
use Getopt::Std;

getopts("c:d:o:ernh",\%opt);

($opt{'h'}) &&
(print "-"x75,
       "\nRawSnif v0.8 by David Hulton, for Perl with Net::RawIP mods.\n",
       "[http://www.nfsg.org] (Nightfall Security Group)\n",
       "-"x75,"\n",
       "Usage: rawsnif.pl [-c<config_file>][-d<device>][-o<outfile>][-e]",
       "[-r][-n][-h]\n",
       "                   -c: specifies the configuration file to use\n",
       "                   -d: specifies the device to capture packets on\n",
       "                   -o: specifies an output file for captured data\n",
       "                   -e: specifies a filter that prints everything\n",
       "                   -r: specifies to resolve addresses to hostnames\n",
       "                   -n: specifies to only print connect/disconnect\n",
       "                   -h: shows this help message\n\n") && (exit(1));

(defined($opt{'c'})) && (&parse_config);
(defined($opt{'d'})) && ($pdev=$opt{'d'}) ||
 ($pdev=Net::RawIP::lookupdev($ptout));
if(defined($opt{'o'})) { open(OUT,">$opt{'o'}") or
 die "Logfile: Unable to Open '$opt{'o'}'..\n"; autoflush OUT; 
 print "Logfile: Found, Using '$opt{'o'}'..\n" } 
($opt{'e'}) && ($pfil='tcp') &&
 (print "Warning: Printing Everything on the Network..\n");
print "Filter: $pfil..\n";

die "Error: No Suitable Network Device Found..\n" if (!$pdev);
print "Device Found: $pdev..\n";
$p=new Net::RawIP({ip=>{},tcp=>{}});
$psck=$p->pcapinit($pdev,$pfil,$psize,$ptout);
$offset=Net::RawIP::linkoffset($psck);
die "Error: Link Offset Not Supported..\n" if (!$offset);
print "Link Offset: $offset..\n";
loop $psck,-1,\&parse,@p;

sub parse_config {
 if(open(IN,"<$opt{'c'}")) { my($h,$ds);
  print "Config: Found, Using '$opt{'c'}'..\n";
  $d{'i'}=0; $s{'i'}=0;
  while(<IN>) { my($line)=$_;
   (($line=~/dst=/) && ($h=\%d) && ($ds="dst") && ($d{'i'}++)) ||
   (($line=~/src=/) && ($h=\%s) && ($ds="src") && ($s{'i'}++));
   if($line=~/$ds=([\w\.\-]+)/) {
    if($1=~/([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)/) { my($num,@addr);
     @addr=($1,$2,$3,$4);
     foreach $num (@addr) { die "Error: IP address ($1.$2.$3.$4) in config",
      " file ($opt{'c'}) is invalid..\n" if ($num>255) }
     $$h{"ip$$h{'i'}"}="$1.$2.$3.$4" }
    elsif($line=~/$ds=([a-z\-\.]+)/) { my(@addrs);
     if(@addrs=gethostbyname($1)) { my(@ip);
      @ip=unpack('CCCC',$addrs[4]); $$h{"ip$$h{'i'}"}=join('.',@ip) }
     else { die "Error: Cannot resolve hostname ($1)." } }
    elsif($line=~/$ds=([0-9]+)/) {
     ($1>65535) && (die "Error: Specified port ($1) in config file ($opt{'c'})",
      " is invalid..\n") ||
      ($$h{"port$$h{'i'}"}=$1) }
    else {
     die "Error: Unable to determine type of statement ($ds=) in config file",
      " ($opt{'c'})..\n" } }
   else { next }
   ((!$$h{"port$$h{'i'}"}) && $line=~/:([0-9]+)/) &&
    (($1>65535) && (die "Error: Specified port ($1) in config file ($opt{'c'})",
    " is invalid..\n") || ($$h{"port$$h{'i'}"}=$1));
   ($line=~/inc=(\S+)/) && ($$h{"inc$$h{'i'}"}=$1);
   ($line=~/exc=(\S+)/) && ($$h{"exc$$h{'i'}"}=$1) }
  $pfil="tcp and ( ";
  &write_filter('s','src');
  ($s{'i'}>0 && $d{'i'}>0) && ($pfil.="or ");
  &write_filter('d','dst');
  $pfil.="\)";
  close(IN) }
 else { print "Config: Unable to Open, Using Defaults..\n" } }

sub write_filter { my($h,$i); 
 eval("\$h=\\%$_[0]");
 for($i=1;$i<($$h{'i'}+1);$i++) {
  ($$h{"ip$i"} || $$h{"port$i"}) && ($pfil.="\( ");
  ($$h{"ip$i"}) && ($pfil.="$_[1] host $$h{\"ip$i\"} ");
  ($$h{"ip$i"} && $$h{"port$i"}) && ($pfil.="and ");
  ($$h{"port$i"}) && ($pfil.="$_[1] port $$h{\"port$i\"} ");
  ($$h{"ip$i"} || $$h{"port$i"}) && ($pfil.="\) ");
  ($i!=$$h{'i'}) && ($pfil.="or ") } }

sub parse {
 $pckt=$_[2];
 $flags=unpack("B8",substr($pckt,$offset+$ip+13,1));
 (((substr($flags,6,1)=='1') && &getinfo('Connected ')) ||
 ((substr($flags,7,1)=='1') && &getinfo('Disconnect')));
 (!$opt{'n'}) && &print_data }

sub getinfo { my(%pd)=&getpckt;
 ($opt{'r'}) && 
  (print_out("\r$_[0] -> ",
   "$pd{'shost'}:$pd{'sport'} --> $pd{'dhost'}:$pd{'dport'}\n")) ||
  (print_out("\r$_[0] -> ",
   "$pd{'saddr'}:$pd{'sport'} --> $pd{'daddr'}:$pd{'dport'}\n")) }

sub getpckt { my(%pd,@saddr,@daddr,@shost,@dhost,$flags);
 if($opt{'r'}) {
  (@shost=gethostbyaddr(substr($pckt,$offset+12,4),AF_INET));
  ($pd{'shost'}=$shost[0]);
  (@dhost=gethostbyaddr(substr($pckt,$offset+16,4),AF_INET));
  ($pd{'dhost'}=$dhost[0]) }
 @saddr=unpack("CCCC",substr($pckt,$offset+12,4));
 $pd{'saddr'}=join('.',@saddr);
 (defined($pd{'shost'})) || ($pd{'shost'}=$pd{'saddr'});
 @daddr=unpack("CCCC",substr($pckt,$offset+16,4));
 $pd{'daddr'}=join('.',@daddr);
 (defined($pd{'dhost'})) || ($pd{'dhost'}=$pd{'daddr'});
 $pd{'sport'}=unpack("nn",substr($pckt,$offset+$ip,4));
 $pd{'dport'}=unpack("nn",substr($pckt,$offset+$ip+2,4));
 return(%pd) }

sub print_data { my($tdata,$data);
 $tdata=(substr($pckt,$offset+$ip+
 (unpack("C",(substr($pckt,$offset+$ip+12,1)))/4)));
 ((!$opt{'c'}) && &print_out($tdata)) ||
  (($data=&checkdata('s',$tdata)) && &print_out($data)) ||
  (($data=&checkdata('d',$tdata)) && &print_out($data)) }

sub checkdata { my($h,%pd,$tdata,$i);
 eval("\$h=\\%$_[0]"); %pd=&getpckt; $tdata=$_[1];
 for($i=1;$i<($$h{'i'}+1);$i++) {
  if((($pd{"$_[0]addr"} eq $$h{"ip$i"}) && ($pd{"$_[0]port"} eq $$h{"port$i"}))
  || ((!$$h{"ip$i"}) && ($pd{"$_[0]port"} eq $$h{"port$i"})) ||
  ((!$$h{"port$i"}) && ($pd{"$_[0]addr"} eq $$h{"ip$i"}))) {
   if($$h{"exc$i"}) { ($tdata!~/($$h{"exc$i"})/i) && return($tdata) }
   elsif($$h{"inc$i"}) { ($tdata=~/($$h{"inc$i"})/i) && return($tdata) }
   else { return($tdata) } } } }

sub print_out { (defined($opt{'o'})) && (print OUT "@_"); print "@_" }

sub close_pcap { (defined($opt{'o'})) && (close(OUT)); exit(1) }
