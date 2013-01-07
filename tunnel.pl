#!/usr/bin/perl -w
use strict;
use sigtrap qw(die INT QUIT);
$|++;

use IO::Socket::INET qw(CRLF);
use IO::Select;
use Getopt::Long;

$SIG{__WARN__} = sub {
  warn map "[".localtime()."] [$$] $_\n", (join "", @_) =~ /(.+)\n*/g;
};

my $TIMEOUT = 10;

GetOptions(
           "localhost=s" => \ (my $LOCALHOST = "localhost"),
           "localport=i" => \ (my $LOCALPORT = 0),
           "remotehost=s", => \ (my $REMOTEHOST = "localhost"),
           "remoteport=i" => \ (my $REMOTEPORT = 25),
           "connect=s" => \ (my $CONNECT),
           ) or die "opts";
my $master = IO::Socket::INET->new
  (Listen => 5, Reuse => 1, LocalHost => $LOCALHOST, LocalPort => $LOCALPORT)
  or die "Cannot create listen socket: $@";
warn sockhostport($master), "\n";

my $select = IO::Select->new($master);
while (1) {
  my @ready = $select->can_read($TIMEOUT);
  warn "ready is @ready", "\n";
  redo unless @ready;           # heartbeat

  for (@ready) {
    if ($master eq $_) { # new connection
      my $slave = $master->accept;
      warn "connection from ", peerhostport($slave), " at ", $slave, "\n";
      ## open remote connection, and set up peering
      my $remote = IO::Socket::INET->new(PeerHost => $REMOTEHOST,
                                         PeerPort => $REMOTEPORT)
        or (warn "Cannot connect: $!"), next;
      warn "connected to $remote\n";
      $select->add($slave, $remote);
      $ {*$slave}{__Peer} = $remote;
      $ {*$remote}{__Peer} = $slave;
      if (defined $CONNECT) {
        print $remote "CONNECT $CONNECT HTTP/1.0", CRLF, CRLF;
        $ {*$remote}{__Buf} = "";
      }
    } else {
      warn "reading from $_\n";
      my $peer = $ {*$_}{__Peer};       # get peer
      if ((my $count = $_->sysread(my $buf, 8192)) > 0) {
        if (exists $ {*$_}{__Buf}) { # stripping until blank line
          if (($ {*$_}{__Buf} .= $buf) =~ s/^.*?\r?\n\r?\n//s) { # got it
            $buf = delete $ {*$_}{__Buf}; # back to normal
          } else {
            $buf = "";          # don't show anything yet
          }
        }
        warn "sending $count bytes containing <$buf> to $peer\n";
        $peer->print($buf);
      } else {                  # EOF
        warn "shutting down $_ and $peer\n";
        $select->remove($_, $peer); # don't watch them
        $_->close;
        $peer->close;
      }
    }
  }
}

sub sockhostport {
  my $io_socket_inet = shift;
  sprintf "%s:%d", $io_socket_inet->sockhost, $io_socket_inet->sockport;
}
sub peerhostport {
  my $io_socket_inet = shift;
  sprintf "%s:%d", $io_socket_inet->peerhost, $io_socket_inet->peerport;
}

