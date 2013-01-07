#!/usr/bin/perl

# by samy [commport5@lucidx.com]
# requires pdump::Sniff - http://secure.lucidx.com/pdump-devel.tar.gz [pdump.lucidx.com/pdump.tar.gz but it's older]

use pdump::Sniff;
use Tk;
$mdb = MainWindow->new();
@iphdr = qw(version ihl tos tot_len id frag_off ttl protocol check saddr daddr);
@tcphdr = qw(source dest seq ack_seq doff res1 res2 urg ack psh rst syn fin window check urg_ptr data);
@udphdr = qw(source dest len check data);
@icmphdr = qw(type code check gateway id sequence unused mtu data);
$mdb->title(" Raw Packet Injector");
$status = $mdb->Label(-width => 30, -relief => "sunken", -bd => 1);
$status->pack(-side => "bottom", -fill => "y", -padx => 2, -pady => 1);
$mhead = $mdb->Frame(-relief => 'ridge', -borderwidth => 2)->pack(-fill => 'x', -anchor => 'nw', -side => 'top');
$mright = $mdb->Frame(-relief => 'ridge', -borderwidth => 2)->pack(-fill => 'x', -anchor => 'ne', -side => 'right');
$mright->Label(-text => 'Packet Type')->pack(-fill => 'x', -anchor => 'nw', -side => 'top');
@typerad = ('TCP', 'UDP', 'ICMP');
for my $type (0 .. 2) {
 $mright->Radiobutton(-text => "$typerad[$type]", -variable => \$dbtype, anchor => 'w', -relief => 'flat', -value => $type)->pack(-side => 'top');
}
$mright->Label(-text => "\nPackets")->pack;
$speed = $mright->Entry(-borderwidth => 2, -width => 8)->pack;
$speed->insert('end', "1");
$mright->Label(-text => "\n")->pack;
$mright->Button(-text => "TCP Headers", -command => \&tcph)->pack;
$mright->Button(-text => "UDP Headers", -command => \&udph)->pack;
$mright->Button(-text => "ICMP Headers", -command => \&icmph)->pack;
$mw1 = $mdb->Frame()->pack(-side => 'left', -pady => 2, -padx => 15);
$mw1->Label(-text => "IP Headers\n", -anchor => 'e')->pack;
foreach (0 .. 20) {
 if ($iphdr[$_]) {
  $x{$_} = $mw1->Frame();
  $x{$_}->pack(-pady => '2', -anchor => 'e');
  $tmp = $x{$_}->Label(-text => $iphdr[$_], -anchor => 'e');
  $t = "ip_$iphdr[$_]";
  ${$t} = $x{$_}->Entry(-width => '17', -relief => 'sunken')->pack(-side => 'right');
  $tmp->pack(-side => 'right');
 }
}
$balloon = $mdb->Balloon(-statusbar => $status);
$btnok = $mhead->Button(-text => 'Send');
$btnok->configure(-command => \&write);
$btnok->pack(-side => 'left', -padx => '2');
$balloon->attach($btnok, -balloonmsg => "Send packet(s)", -statusmsg => "Send packet(s)");
$btnsave = $mhead->Button(-text => 'Information');
$btnsave->configure(-command => \&info);
$btnsave->pack(-side => 'left', -padx => '2');
$balloon->attach($btnsave, -balloonmsg => "Valuable Information", -statusmsg => "Information on this program");
$btncancel = $mhead->Button(-text => 'Exit', -command => [$mdb,'destroy']);
$btncancel->pack(-side => 'left', -padx => '2');
$balloon->attach($btncancel, -balloonmsg => "Exit Program", -statusmsg => "Exit Program");
MainLoop;
sub write {
 my (%ttcp, %tip, %ip, %tcp, %udp, %icmp, %ticmp, %tudp);
 foreach (@tcphdr) {
  $t = "tcp_$_";
  if (${$t}) {
   $ttcp{$_} = ${$t};
  }
 }
 foreach (@iphdr) {
  $t = "ip_$_";
  if (${$t}) {
   $tip{$_} = get ${$t};
  }
 }
 foreach (keys(%tip)) {
  if ($tip{$_}) {
   $ip{$_} = $tip{$_};
  }
 }
 foreach (keys(%ttcp)) {
  if ($ttcp{$_}) {
   $tcp{$_} = $ttcp{$_};
  }
 }
 foreach (@udphdr) {
  $t = "udp_$_";
  if (${$t}) {
   $tudp{$_} = ${$t};
  }
 }
 foreach (keys(%tudp)) {
  if ($tudp{$_}) {
   $udp{$_} = $tudp{$_};
  }
 }
 foreach (@icmphdr) {
  $t = "icmp_$_";
  if (${$t}) {
   $ticmp{$_} = ${$t};
  }
 }
 foreach (keys(%ticmp)) {
  if ($ticmp{$_}) {
   $icmp{$_} = $ticmp{$_};
  }
 }
 $sp = get $speed;
 foreach (1 .. $sp) {
  $a = new pdump::Sniff;
  if ($dbtype == 0) {
   $a->set({ip => { %ip }, tcp => { %tcp }});
  }
  elsif ($dbtype == 1) {
   $a->set({ip => { %ip }, udp => { %udp }});
  }
  elsif ($dbtype == 2) {
   $a->set({ip => { %ip }, icmp => { %icmp }});
  }
  $a->send;
 }
}
sub info {
 my $top2 = $mdb->Toplevel;
 $top2->Label(-text => "\n         Perl/Tk Raw Packet Injecting Utility         \n      by samy [CommPort5\@LucidX.com]      \n")->pack;
}
sub tcph {
 $f = $mdb->DialogBox(-title => "TCP Headers", -buttons => ["OK"]);
 $n = $f->add('NoteBook', -ipadx => 6, -ipady => 6);
 $address_p = $n->add("address", -label => "Required", -underline => 0);
 $pref_p = $n->add("pref", -label => "Optional", -underline => 0);
 $address_p->LabEntry(-label => "Source Port Number:", -labelPack => [-side => "left", -anchor => "w"], -width => 20, -textvariable => \$tcp_source)->pack(-side => "top", -anchor => "ne");
 $address_p->LabEntry(-label => "Dest. Port Number:", -labelPack => [-side => "left", -anchor => "w"], -width => 20, -textvariable => \$tcp_dest)->pack(-side => "top", -anchor => "ne");
 foreach (2 .. 20) {
  if ($tcphdr[$_]) {
   $tmp = "tcp_$tcphdr[$_]";
   $pref_p->LabEntry(-label => "$tcphdr[$_]:", -labelPack => [-side => "left"], -width => 15, -textvariable => \${$tmp})->pack(-side => "top", -anchor => "ne");
  }
 }
 $n->pack(-expand => "yes", -fill => "both", -padx => 5, -pady => 5, -side => "top");
 $f->Show;
}
sub udph {
 $f = $mdb->DialogBox(-title => "UDP Headers", -buttons => ["OK"]);
 $n = $f->add('NoteBook', -ipadx => 6, -ipady => 6);
 $address_p = $n->add("address", -label => "Required", -underline => 0);
 $pref_p = $n->add("pref", -label => "Optional", -underline => 0);
 $address_p->LabEntry(-label => "Source Port Number:", -labelPack => [-side => "left", -anchor => "w"], -width => 20, -textvariable => \$udp_source)->pack(-side => "top", -anchor => "ne");
 $address_p->LabEntry(-label => "Dest. Port Number:", -labelPack => [-side => "left", -anchor => "w"], -width => 20, -textvariable => \$udp_dest)->pack(-side => "top", -anchor => "ne");
 foreach (2 .. 5) {
  if ($udphdr[$_]) {
   $tmp = "udp_$udphdr[$_]";
   $pref_p->LabEntry(-label => "$udphdr[$_]:", -labelPack => [-side => "left"], -width => 15, -textvariable => \${$tmp})->pack(-side => "top", -anchor => "ne");
  }
 }
 $n->pack(-expand => "yes", -fill => "both", -padx => 5, -pady => 5, -side => "top");
 $f->Show;
}
sub icmph {
 $f = $mdb->DialogBox(-title => "ICMP Headers", -buttons => ["OK"]);
 $n = $f->add('NoteBook', -ipadx => 6, -ipady => 6);
 $address_p = $n->add("address", -label => "Required", -underline => 0);
 $pref_p = $n->add("pref", -label => "Optional", -underline => 0);
 $address_p->Label(-text => "None", -anchor => 'e')->pack;
 foreach (0 .. 10) {
  if ($icmphdr[$_]) {
   $tmp = "icmp_$icmphdr[$_]";
   $pref_p->LabEntry(-label => "$icmphdr[$_]:", -labelPack => [-side => "left"], -width => 15, -textvariable => \${$tmp})->pack(-side => "top", -anchor => "ne");
  }
 }
 $n->pack(-expand => "yes", -fill => "both", -padx => 5, -pady => 5, -side => "top");
 $f->Show;
}

