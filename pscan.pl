#####################################################################
# Program Name: pscan.pl
# Programmer:   Chuck Little
# Desc:  This script does a quick and dirty port scan of a host.
#        Doesn't say what service is responding, just lets you know
#        if there is a response.
#
# Revision History:
#  - 0.0.1 -
#    - Initial coding. Needs LOTS of work.
#
# TO DO:
#  - Add functionality to know what service responded. Would rather
#    not rely on a services file, would like to get that info from
#    the socket itself.
#####################################################################
use IO::Socket;

$rhost = $ARGV[0];
chomp ($rhost);
#$rhost = "ov00ux1";
$rproto = "tcp";
@PORTS[0..1024] = (0..1024);

foreach $rport (@PORTS) {
  if ($rport == 0) {
    next;
  }
  my $ss = IO::Socket::INET->new(PeerAddr => $rhost,
                      PeerPort => $rport,
                      Proto    => $rproto,
                      Timeout  => 3
                      );
  if ($ss) {
    print "\nPort $rport responded\n";
  } else {
    # Who cares what port didn't respond. Only prints a dot
    # to let you know it is still running and that a port 
    # failed to respond.
    print "."
    # print "Port $rport DID NOT respond\n";
  }
}
print "\n";
#####################################################################
