#!/usr/bin/perl -w
###############

##
#     tool:     scandns.pl
#  version:     1.0
#   author:     H D Moore <hdmoore@digitaldefense.net>
#  purpose:     Determine if a DNS service is responding
#    usage:     Run with no arguments for usage options
#     bugs:     Need to use Time::HiRes for latency, seconds are too coarse
#      url:     http://www.digitaloffense.net/index.html?section=TOOLS
##

use strict;
use Socket;
use POSIX;
use Fcntl;
use IO::Select;
use IO::Socket;

my $VERSION = "1.0";

my $input = shift() || usage();
my %targets = ();
my $client = IO::Socket::INET->new(Proto => 'udp') or die "Can't create client port : $@\n";

SetNonBlock($client);
my $select = IO::Select->new($client);

open(INP, "<" . $input) || die "could not open input file: $!";
while (my $line = <INP>)
{
    chomp($line);
    
    my $packet = MakeDNSPacket($line);
    
    my $ipaddr = inet_aton($line);
    my $portaddr = sockaddr_in(53, $ipaddr);


    my $len = send($client, $packet, 0, $portaddr);
    $targets{$line} = time();
   
    my $data; 
    foreach $client ($select->can_read(0.02)) {	
        if(my $system = recv($client, $data, POSIX::BUFSIZ, 0))
        {
            my ($rport, $raddr) = sockaddr_in($system);
            my $rip = inet_ntoa($raddr);
            my $latency = time() - $targets{$line};
            print STDOUT "* $rip - responded in $latency seconds\n";
            delete($targets{$rip});
        }
    }
}
close (INP);


# hang around for any slow responses

my $wait = time() + 5;
while (time() < $wait && scalar(keys(%targets)) > 0)
{
    foreach $client ($select->can_read(0.5)) {	
        my $data; 
        if(my $system = recv($client, $data, POSIX::BUFSIZ, 0))
        {
            my ($rport, $raddr) = sockaddr_in($system);
            my $rip = inet_ntoa($raddr);
            my $latency = time() - $targets{$rip};
            print STDOUT "* $rip - responded in $latency seconds\n";
            delete($targets{$rip});
        } 
    }
    select(undef, undef, undef, .1);
}

exit(0);


############################################################


sub MakeDNSPacket {

    my $ip = shift();
    my $packet;
    my $ID = "\xDE\xAD";

    # FLAGS
    # QR  OPCODE    AA TC RD RA ZERO  RCODE
    # +   ++++      +  +  +  +  +++   ++++
    #
    
    my $FLAGS = pack('B16', "0" . "0000" . "0" . "0" . "1" . "0" . "000" . "0000");
    my $QUEST = "\x00\x01";
    my $ANSRR = "\x00\x00";
    my $AUTRR = "\x00\x00";
    my $ADDRR = "\x00\x00";


    $packet = $ID . $FLAGS . $QUEST . $ANSRR . $AUTRR . $ADDRR;


    # ASN encode the request Ghetto Style (tm)
    
    my $NAME = "";
    my @oct = split(/\./, $ip);
    for (my $i = 3; $i >= 0; $i--)
    {
        $NAME .= chr(length($oct[$i])) . $oct[$i];
    }
    $NAME .= "\x07" . "in-addr" . "\x04" . "arpa" . "\x00";

    my $TYPE = "\x00" . "\x0c";
    my $CLASS = "\x00\x01";

    $packet .= $NAME . $TYPE . $CLASS;
    
    return $packet;
}


sub SetNonBlock {
        my $socket = shift();
        my $flags;
        $flags = fcntl($socket, F_GETFL, 0) || die "Can't get flags for socket: $!\n";
        fcntl($socket, F_SETFL, $flags|O_NONBLOCK) || die "Can't make socket nonblocking: $!\n";
}

sub usage {

print STDERR qq{

*- --[ scandns.pl v$VERSION - H.D. Moore <hdmoore\@digitaldefense.net>

Usage: $0 <input file> 

To "ping" a list of hosts:
    \$ $0 /path/to/ip/list.txt
    
To "ping" a single host:
    \$ echo 192.168.1.1 | $0 -

};
    exit(1);

}