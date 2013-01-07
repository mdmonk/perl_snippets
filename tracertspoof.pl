#!/usr/bin/perl

# traceroute hop spoofer!
# -samy [cp5@LucidX.com]

use Packet::Inject;
use Packet::IP;
use Packet::Ethernet;
use Packet::ICMP;
use Packet::Definitions;
use Packet::Lookup;
use Packet::Sniff;

use strict;

die "usage: $0 <spoof 1> <spoof 2> ...\n" unless my @spoofs = @ARGV;

my $len = pack('I', 0);
my @mib = (
  &Packet::Definitions::CTL_NET,
  &Packet::Definitions::AF_ROUTE,
  0,
  &Packet::Definitions::AF_LINK,
  &Packet::Definitions::NET_RT_IFLIST,
  0
);
my $mib = pack('iiiiii', @mib);
syscall(&Packet::Definitions::SYS___sysctl, $mib, 6, 0, $len, 0, 0);
my $buf = pack('a' . unpack('I', $len), '');
syscall(&Packet::Definitions::SYS___sysctl, $mib, 6, $buf, $len, 0, 0);
my ($device) = ($buf =~ /.*?(\w{2,5}\d+)/);

# convert hosts to ip now to save time when sending packets
foreach (@spoofs) {
 $_ = quad2int(&Packet::Lookup::host_to_ip($_));
}


my $id       = int(rand(2 ** 16));
my $total    = @spoofs;
my $ethernet = Packet::Ethernet->new();
my $ip       = Packet::IP      ->new();
my $inject   = Packet::Inject  ->new(device => $device);
my $sniff    = Packet::Sniff   ->new(device => $device);
my $sendeth  = Packet::Ethernet->new(
  type       => 0x0800,
);


$inject->open() || die $inject->{errbuf};
$sniff ->open() || die $inject->{errbuf};
$sniff ->loop(0, \&parse, $total);


sub parse {
  my ($total, $hdr, $packet, $s) = @_;
  my ($sendip, $sendicmp);

  $ethernet->decode($packet);
  return unless $ethernet->type == 0x0800;

  $ip->decode($ethernet->data);
  return unless $ip->ttl <= ($total + 1);

  $sendeth->{dest_mac} = $ethernet->src_mac;

  # this is where we send the final packet and get device name
  if ($ip->ttl == $total + 1) {
    $sendicmp = Packet::ICMP->new(
      type          => &Packet::ICMP::ICMP_DEST_UNREACH,
      code          => &Packet::ICMP::ICMP_PORT_UNREACH,
      data          => "\0" x 4 . substr($ip->encode, 0, 28),
    );

    $sendip = Packet::IP->new(
      src_ip        => $ip->dest_ip,
      dest_ip       => $ip->src_ip,
      id            => $id++,
      proto         => 1,
      data          => $sendicmp,
    );

    $inject->write(packet => $sendeth . $sendip);

    print "Port Unreachable sent to " . int2quad($ip->src_ip) . "\n";
  }

  else {
    $sendicmp = Packet::ICMP->new(
      type => &Packet::ICMP::ICMP_TIME_EXCEED,
      code => &Packet::ICMP::ICMP_TTL_EXCEED,
      data => "\0" x 4 . substr($ip->encode, 0, 28),
    );
    $sendip = Packet::IP->new(
      src_ip        => $spoofs[$ip->ttl-1],
      dest_ip       => $ip->src_ip,
      id            => $id++,
      proto         => 1,
      data          => $sendicmp,
    );

    $inject->write(packet => $sendeth . $sendip);

    print "Time Exceeded In Transit sent to " . int2quad($ip->src_ip) .
          " from " . int2quad($spoofs[$ip->ttl-1]) . "\n";
  }

}


sub quad2int
{
    my $val = shift;
    my $counter = 3;
    my $i;
    my $result;
        
    for my $i (split/\./, $val) {
        $result += $i * 256 ** $counter--;
    }
 
    return ($result);
}

sub int2quad
{
    my $val = shift;
    my $result;
     
    if ($val =~ /^\d+$/) {
        $result = join('.', unpack("C4", pack('N', $val)));
    }
        
    return ($result);
}
