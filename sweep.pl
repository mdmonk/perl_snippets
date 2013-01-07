#####################################################
# sweep.pl
# 
# This is a collection of subroutines That can be used
#   for checking host vulnerabilites.  Functionality
#   can be added by configuring the particular sub-
#   routines and adding the calls.  Adding the ability
#   to write to a log file is trivial.
# 
# As this script is written now, it can scan the
#   selected ports.  Add functionality by adding
#   the appropriate calls to subroutines.
#####################################################
# For ping
use Net::Ping;
# For www_svr
use LWP::Simple;
# For socket
use IO::Socket;
# Get SNMP data

# Requires Net::SNMP module from CPAN
# use Net::SNMP();

# For Win32-specific functions
# If not using NT, remove this line and references
#    in subroutines
use Win32;
#####################################################
# Ports to check
# make this a hash, so that the name can be easily printed 
# out along with the port number
# Not all ports checked...use the Cheswick and Bellovin
# approach
@tcp_ports = (15,	 #netstat
              21,	 #ftp		   banner
	           23,	 #telnet
	           25,	 #SMTP		banner
              43,	 #whois
	           69,	 #TFTP
              70,	 #gopher
              79,	 #finger
              80,  #HTTP		banner
	           110, #POP3		banner
              111, #portmapper
              139, #NBT-ssn
              512, #exec
	           513, #login
	           514, #shell
              12345);#NetBus	banner
$target = shift;
print "Checking $target...\n";
#################################################
# main section
#################################################
$ip = name($target);
foreach $port (@tcp_ports) {
  check_port($ip,$port);
}
#################################################
# Get name or IP, return IP address
#################################################
sub name {
  my ($host) = @_;
  eval {
    $ipaddr = inet_ntoa(inet_aton($host));
    print "IP:\t\t$ipaddr\n";
    return $ipaddr;
  }  || die "Could not find host.\n";
  
}
#################################################
#  Ping the host
#################################################
sub ping {
 my ($host) = @_;
  $p = Net::Ping->new("icmp");
  print "$host is ";
  print "NOT " unless $p->ping($host, 2);
  print "alive.\n";
  $p->close();
}
#################################################
# Get name of WWW Server
#################################################
sub www_svr {
  my ($host) = @_;
  eval {
   ($junk, $junk, $junk,$junk, $server) = head("http://$host");
  
    print "HTTP Server:\t$server\n";
  } || print "Cound not get HTTP Server.\n";
}
#################################################
# Check to see if a port is open
#################################################
sub check_port {
  my ($host,$port) = @_;
  $remote = IO::Socket::INET -> new (
             Proto => "tcp",
	     Timeout => 3,
             PeerAddr => $host,
             PeerPort => $port );
  if ($remote) { 
    close $remote;
    print "$host:$port=>\tActive\n";
    if ($port == 80) {www_svr($host);}
#   if ($port == 21) {get_banner($host,$port);}
#   if ($port == 25) {get_banner($host,$port);}
#   if ($port == 79) {finger($host);}
#   if ($port == 110) {get_banner($host,$port);}
#   if (($port == 139) && Win32::IsWinNT()) {nbt($host);}
  } else { print "$host:$port=>\tInactive\n"; }  
}
#################################################
# Get banner (single line) from port
#################################################
sub get_banner {
  my ($host,$port) = @_;
  $remote = IO::Socket::INET -> new (
          Proto => "tcp",
          PeerAddr => $host,
          PeerPort => $port
          ) or die "Could not open socket.\n";

  $line = <$remote>;
  print "$line\n";
  close $remote;
}
#################################################
# Send data to a port, read back all data
# (finger)
#################################################
sub finger {
  my ($host) = @_;
  print "Finger $host...\n";
  $remote = IO::Socket::INET -> new (
          Proto => "tcp",
          PeerAddr => $host,
          PeerPort => 79
          );
  print $remote "\n";
  @lines = <$remote>;
  foreach $line (@lines) { print "$line\n"; }
}
#################################################
# Run nbtstat on the target
#################################################
sub nbt {
  my ($host) = @_;
  open(NBT,"nbtstat -A $host |");
  while(<NBT>) { print ; }
}
#################################################
# Attempt a null connection via 'net use'
#################################################
sub null_conn {
  my ($host) = @_;
  $user = '""';
  $pass = '""';
  open(NUL, "net use \\\\$host\ipc\$ $pass /user:$user |");
  while (<NUL>) {
    print;
  }
}
#################################################
# SNMP:  get system information
#################################################
sub snmp {
  my ($hostname) = @_;
  $community = 'public';
  $port      = 161;
  ($session, $error) = Net::SNMP->session(
                       Hostname  => $hostname,
                       Community => $community,
                       Port      => $port);
   if (!defined($session)) {
      printf("ERROR: %s\n", $error);
      exit 1;
   }
# OIDs we are interested in...
   $sysDescr = '1.3.6.1.2.1.1.1.0';
   $sysObjectID = '1.3.6.1.2.1.1.2.0';
   $sysContact = '1.3.6.1.2.1.1.4.0';
   $sysName = '1.3.6.1.2.1.1.5.0';
   $sysLocation = '1.3.6.1.2.1.1.6.0';
   $sysServices = '1.3.6.1.2.1.1.7.0';
# sysDecr
   if (defined($response = $session->get_request($sysDescr))) {
      print "System Description:  $response->{$sysDescr}\n";
   } else {
      printf("ERROR: %s\n", $session->error);
      $session->close;
   }
#sysObjectID
   if (defined($response = $session->get_request($sysObjectID))) {
      print "System ObjectID:  $response->{$sysObjectID}\n";
   } else {
      printf("ERROR: %s\n", $session->error);
      $session->close;
   }
#sysContact
   if (defined($response = $session->get_request($sysContact))) {
      print "System Contact:  $response->{$sysContact}\n";
   } else {
      printf("ERROR: %s\n", $session->error);
      $session->close;
   }
#sysName 
   if (defined($response = $session->get_request($sysName))) {
      print "System Name:  $response->{$sysName}\n";
   } else {
      printf("ERROR: %s\n", $session->error);
      $session->close;
   }
#sysLocation
   if (defined($response = $session->get_request($sysLocation))) {
      print "System Location:  $response->{$sysLocation}\n";
   } else {
      printf("ERROR: %s\n", $session->error);
      $session->close;
   }
#sysServices
   if (defined($response = $session->get_request($sysServices))) {
      print "System Services String:  $response->{$sysServices}\n";
   } else {
      printf("ERROR: %s\n", $session->error);
      $session->close;
   }
   $session->close;
}
#################################################
# UDP Ping
#################################################
sub udp_ping {
  my ($host) = @_;
  $p = Net::Ping->new();
  print "$host is alive.\n" if $p->ping($host);
  $p->close();
}
