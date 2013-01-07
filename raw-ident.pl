#!/usr/bin/perl

# stand-alone raw wanna-be-ident daemon
# PoC by commport5

use pdump::Sniff;
die "usage: $0 <port>\n" unless @ARGV == 1;
$| = 1;
$tout = 10;
$dev = pdump::Sniff::lookupdev($tout);
$ip_addr = ${ifaddrlist()}{$dev};
$packet_tcp = new pdump::Sniff({tcp=>{}});
$filt_tcp = "ip proto \\tcp and dst port $ARGV[0]";
$pcap_tcp=$packet_tcp->pcapinit($dev,$filt_tcp,1500,60);
$offset_tcp = linkoffset($pcap_tcp);
if (fork) {
 loop $pcap_tcp, -1, \&check_tcp, \@packet_tcp;
}
sub check_tcp{
 $packet_tcp->bset($_[2], $offset_tcp);
 my $headers;
 my ($vers,$ihl,$tos,$tot,$id,$frg,$ttl,$pro,$chc,$saddr,$daddr,$sport,$dport,$seq,$aseq,$dof,$res1,$res2,$urg,$ack,$psh,$rst,$syn,$fin,$win,$chk,$data) =
 $packet_tcp->get({ip=>['version','ihl','tos','tot_len','id','frag_off','ttl','protocol','check','saddr','daddr'],tcp=>[
 'source','dest','seq','ack_seq','doff','res1','res2','urg','ack','psh','rst','syn','fin','window','check','data']});
 if ($urg) {
  $headers .= "U";
 }
 if ($ack) {
  $headers .= "A";
 }
 if ($psh) {
  $headers .= "P";
 }
 if ($rst) {
  $headers .= "R";
 }
 if ($syn) {
  $headers .= "S";
 }
 if ($fin) {
  $headers .= "F";
 }
 unless ($headers) {
  $headers = ".";
 }
 $sname = &ip2dot($saddr);
 $dname = &ip2dot($daddr);
 if ($headers eq "S" and !$sent) {
  $rand = rand;
  $rand =~ s/^0\.(\d{9}).*?$/$1/;
  $a = new pdump::Sniff;
  $a->set({ip => {
  saddr => $dname,
  daddr => $sname }, tcp => {
  dest => $sport,
  source => $dport,
  seq => $rand,
  ack_seq => ($seq - 1),
  ack => 1,
  syn => 1 }});
  $a->send;
  $sent = 1;
 }
 if ($headers eq "P" and $sent == 1) {
  $ndata = "$data : USERID : UNIX :cp5\n";
  $a = new pdump::Sniff;
  $a->set({ip => {
  saddr => $dname,
  daddr => $sname }, tcp => {
  dest => $sport,
  source => $dport,
  seq => $aseq,
  ack_seq => ($seq - length($data)),
  ack => 1 }});
  $a->send;
  $a = new pdump::Sniff;
  $a->set({ip => {
  saddr => $dname,
  daddr => $sname }, tcp => {
  dest => $sport,
  source => $dport,
  seq => $aseq,
  ack_seq => ($seq - length($data)),
  ack => 1,
  psh => 1,
  data => $ndata }});
  $a->send;
  $a = new pdump::Sniff;
  $a->set({ip => {
  saddr => $dname,
  daddr => $sname }, tcp => {
  dest => $sport,
  source => $dport,
  seq => ($aseq - length($ndata)),
  ack_seq => ($seq - length($data)),
  ack => 1,
  fin => 1 }});
  $a->send;
  $sent = 2;
 }
 if ($headers eq "F" and $sent == 2) {
  $a = new pdump::Sniff;
  $a->set({ip => {
  saddr => $dname,
  daddr => $sname }, tcp => {
  dest => $sport,
  source => $dport,
  seq => $aseq,
  ack_seq => ($seq - 1),
  ack => 1,
  fin => 1 }});
  $a->send;
  $sent = 3;
 }
 if ($headers eq "F" and $sent == 3) {
  $a = new pdump::Sniff;
  $a->set({ip => {
  saddr => $dname,
  daddr => $sname }, tcp => {
  dest => $sport,
  source => $dport,
  seq => $aseq,
  ack_seq => ($seq - 1),
  ack => 1 }});
  $a->send;
  $sent = 0;
 }
}
sub ip2name {
 my $addr = shift;
 (gethostbyaddr(pack("N",$addr),AF_INET))[0] || ip2dot($addr);
}
sub ip2dot {
 sprintf("%u.%u.%u.%u",unpack "C4", pack "N1", shift);
}
