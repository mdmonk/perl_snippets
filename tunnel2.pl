#!C:/perl/bin/perl -w

use strict;
use IO::Socket ();
use Getopt::Long ();


use vars qw($debug $verbose $PORT $TOHOST $TOPORT $DIR);

$PORT = 81;
$TOHOST = "127.0.0.1";
$TOPORT = 80;
$DIR = undef;
$| = 1;

############################################################################
#
#   This is main()
#
############################################################################

{
  my %o = ('port' => $PORT,
	   'toport' => $TOPORT,
	   'tohost' => $TOHOST);
  Getopt::Long::GetOptions(\%o, 'debug', 'verbose+', 'port=s', 'toport=s',
			   'tohost=s', 'dir=s');
  $verbose = 1 if $debug && !$verbose;

  my $ah = IO::Socket::INET->new('LocalAddr' => "0.0.0.0",
				 'LocalPort' => $PORT,
				 'Reuse' => 1,
				 'Listen' => 10)
    || die "Failed to bind to local socket: $!";

  print "Entering main loop.\n" if $o{'verbose'};
  $SIG{'CHLD'} = 'IGNORE';
  my $num = 0;
  while (1) {
    my $ch = $ah->accept();
    if (!$ch) {
      print STDERR "Failed to accept: $!\n";
      next;
    }
    printf("Accepting client from %s, port %s.\n",
	   $ch->peerhost(), $ch->peerport()) if $o{'verbose'};
    ++$num;
    my $pid = eval { fork () };
    if ($@) {
			# fork not supported, we handle a single connection
      Run(\%o, $ch, $num);
    } elsif (!defined($pid)) {
      print STDERR "Failed to fork: $!\n";
    } elsif ($pid == 0) {
      # This is the child
      $ah->close();
      Run(\%o, $ch, $num);
			exit 0;
    } else {
      print "Parent: Forked child, closing socket.\n" if $o{'verbose'};
      $ch->close();
    }
  }
}


sub Run {
  my($o, $ch, $num) = @_;
  my $th = IO::Socket::INET->new('PeerAddr' => $o->{'tohost'},
				 'PeerPort' => $o->{'toport'});
  print("Child: Connecting tunnel to $o->{'tohost'}, port $o->{'toport'}.\n")
    if $o->{'verbose'};
  if (!$th) {
    printf STDERR ("Child: Failed to connect tunnel to %s, port %s.\n",
		   $o->{'tohost'}, $o->{'toport'});
    return
  }

  my $fh;
  if ($o->{'dir'}) {
    $fh = Symbol::gensym();
    open($fh, ">$o->{'dir'}/tunnel$num.log")
      or die "Child: Failed to create file $o->{'dir'}/tunnel$num.log: $!";
  }

  $ch->autoflush();
  $th->autoflush();
  while ($ch || $th) {
    print "Child: Starting loop.\n" if $o->{'verbose'};
    my $rin = "";
    vec($rin, fileno($ch), 1) = 1 if $ch;
    vec($rin, fileno($th), 1) = 1 if $th;
    my($rout, $eout);
    select($rout = $rin, undef, $eout = $rin, 120);
    if (!$rout  &&  !$eout) {
      print STDERR "Child: Timeout, terminating.\n";
    }
    my $cbuffer = "";
    my $tbuffer = "";
    if ($ch  &&  (vec($eout, fileno($ch), 1)  ||
		  vec($rout, fileno($ch), 1))) {
      print "Child: Waiting for client input.\n" if $o->{'verbose'};
      my $result = sysread($ch, $tbuffer, 1024);
      if (!defined($result)) {
	print STDERR "Child: Error while reading from client: $!\n";
	return
      }
      if ($result == 0) {
	print "Child: Client has terminated.\n" if $o->{'verbose'};
	return
      }
      print "Child: Client input: $cbuffer\n" if $o->{'verbose'};
    }
    if ($th  &&  (vec($eout, fileno($th), 1)  ||
		  vec($rout, fileno($th), 1))) {
      print "Child: Waiting for tunnel input.\n" if $o->{'verbose'};
      my $result = sysread($th, $cbuffer, 1024);
      if (!defined($result)) {
	print STDERR "Child: Error while reading from tunnel: $!\n";
	return
      }
      if ($result == 0) {
	print "Child: Tunnel has terminated.\n" if $o->{'verbose'};
	return
      }
      print "Child: Tunnel input: $cbuffer\n" if $o->{'verbose'};
    }
    if ($fh  &&  $tbuffer) {
      (print $fh $tbuffer);
    }
    while (my $len = length($tbuffer)) {
      print "Child: Writing $len bytes to tunnel.\n" if $o->{'verbose'};
      my $res = syswrite($th, $tbuffer, $len);
      print "Child: Wrote $res bytes of $len to tunnel.\n"
	if $o->{'verbose'};
      if ($res > 0) {
	$tbuffer = substr($tbuffer, $res);
      } else {
	print STDERR "Child: Failed to write to tunnel: $!\n";
      }
    }
    while (my $len = length($cbuffer)) {
      print "Child: Writing $len bytes to client.\n" if $o->{'verbose'};
      my $res = syswrite($ch, $cbuffer, $len);
      print "Child: Wrote $res bytes of $len to child.\n"
	if $o->{'verbose'};
      if ($res > 0) {
	$cbuffer = substr($cbuffer, $res);
      } else {
	print STDERR "Child: Failed to write to tunnel: $!\n";
      }
    }
  }
}


__END__

=pod

=head1 NAME

tunnel.pl - Create a TCP/IP tunnel between two ports.


=head1 SYNOPSIS

  tunnel.pl --port=<num> --tohost=<tohost> --toport=<tonum>


=head1 DESCRIPTION

This script is building a TCP/IP tunnel between two ports. In other
words, it makes you think that a server is listening on your local
machine, port <num>, which is really sitting on host <tohost>, port
<tonum>.

The main purpose of the script is the debugging of client/server
applications, as it includes the ability to log what the client
sends. This is done by using the option --dir=<dir>: If this option
is present, then any new connection will be logged in the files
dir/tunnel0.log, dir/tunnel1.log, and so on.


=head1 CPAN SCRIPT

This script can be found on the CPAN. The following sections are for
CPAN's internal script handling and you can mainly ignore them.

=head2 SCRIPT CATEGORIES

Networking

=head2 README

This script is building a TCP/IP tunnel between two ports. In other
words, it makes you think that a server is listening on your local
machine, port <num>, which is really sitting on host <tohost>, port
<tonum>.

The main purpose of the script is the debugging of client/server
applications, as it includes the ability to log what the client
sends. This is done by using the option --dir=<dir>: If this option
is present, then any new connection will be logged in the files
dir/tunnel0.log, dir/tunnel1.log, and so on.


=head1 AUTHOR

Jochen Wiedmann
jochen.wiedmann@softwareag.com

=cut
