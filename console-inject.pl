#!/usr/bin/perl

# -cp5

use pdump::Sniff;

@iphdr = qw(version ihl tos tot_len id frag_off ttl protocol check saddr daddr);
@tcphdr = qw(source dest seq ack_seq doff res1 res2 urg ack psh rst syn fin window check urg_ptr data);
foreach (@iphdr) {
 print "IP: $_";
 if (/^(s|d)addr$/i) {
  print " [required]";
 }
 print ": ";
 chomp ($ip{$_} = <STDIN>);
}
foreach (@tcphdr) {
 print "TCP: $_";
 if (/^source|dest$/i) {
  print " [required]";
 }
 print ": ";
 chomp ($tcp{$_} = <STDIN>);
}
foreach (keys(%ip)) {
 if ($ip{$_}) {
  $hip{$_} = $ip{$_};
 }
}
foreach (keys(%tcp)) {
 if ($tcp{$_}) {
  $htcp{$_} = $tcp{$_};
 }
}
$a = new pdump::Sniff;
$a->set({ip => { %hip }, tcp => { %htcp }});
$a->send;
