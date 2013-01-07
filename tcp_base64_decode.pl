#!/usr/bin/perl

# Reads pcap file, decodes base64 tcp payload.
# prints sequence number and decoded data.
# syndrowm 2007-02-05

require Net::Pcap;
require NetPacket::Ethernet;
require NetPacket::IP;
require NetPacket::TCP;
require MIME::Base64;

use Net::Pcap;
use NetPacket::Ethernet qw(:strip);
use NetPacket::IP qw(:strip);
use NetPacket::TCP;
use MIME::Base64;

sub usage {
die "usage: $0 filename\n"
}

sub process_packet {
my($user_data, $header, $packet) = @_;
my $tcp_obj = NetPacket::TCP->decode(ip_strip(eth_strip($packet)));
$data = MIME::Base64::decode($tcp_obj->{data});
chomp($data);
print "$tcp_obj->{seqnum} : $data\n";
}

if ($ARGV[0] eq ""){
        usage();
}

$dump = $ARGV[0];

# Open file
$pcap = Net::Pcap::open_offline($dump, \$err)
or die "Can't read '$dump': $err\n";

# loop over the packets, calling proccess_packet function
Net::Pcap::loop($pcap, 0, \&process_packet, "12 packets for me");

# close the file
Net::Pcap::close($pcap);
