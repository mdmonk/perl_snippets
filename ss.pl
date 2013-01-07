# #!/usr/bin/perl -w
######################################################################
# Program Name:  ss.pl    # ss = SuperScan
# Programmer:    Maddog Monk (with big help from O'Reilly Perl books)
# Description:   Scan for open specified port on a class C IP 
#                address block, or all open ports on a single host.
# 
# Revision History:
#  - 0.1.0 (10 Mar 1999) CWL
#    - Coded and functional. Skipped the 0.0.x series because of
#      this. Need to add functionality to ID service running on the
#      other side of the connection.
######################################################################
use strict;
use Socket;

my ($verboseCCIPA, $verboseSHPS, $connectTime, $protoName,
    $protocolID, $ccnip, $port, $scdnip, $ecdnip, $i, $iaddr,
    $paddr, $cdnip); 

$verboseCCIPA	= 1;
$verboseSHPS	= 0;
$connectTime 	= 1;
$protoName	= "tcp";
$protocolID	= getprotobyname($protoName);

($ccnip, $port, $scdnip, $ecdnip) = @ARGV;

$ccnip or die properUsage();
$port and classCNtwkPortScan() or singleHostPortScan();
#####
1;
#####
################################################
# SUBROUTINES
################################################
################################################
# properUsage:
#  - it is exactly that. It prints the proper
#    usage statement if the incorrect cmd line
#    params are passed in. Actually this only
#    checks to see if the first param is passed
#    in. I will update that later on. Using
#    GetOpts()!
################################################
sub properUsage()
{
	print "\nSingle host port scan:\n",
	      "	\$ ss.pl <dns/ip>\n",
	      "	- Scan for all open ports on <dns/ip>.\n\n",
	      "Class C IP specified port scan:\n",
	      "	\$ ss.pl <ccnip> <port> [<scdnip>] [<ecdnip>]\n",
	      "	- Scan for specified open <port> on <ccnip>.<1|<scdnip>>\n",
	      "	  to <ccnip>.<255|<ecdnip>>.\n\n";
	
	exit 1;
}
################################################
# classCNtwkPortScan:
#  - this subroutine scans a whole class C
#    subnet. Scans each host/device in that
#    subnet for the port you specify.
################################################
sub classCNtwkPortScan()
{
	$ccnip !~ /[0-9]+\.[0-9]+\.[0-9]+/ and
		die "Error: $ccnip [ccnip] is not in format <0-255>.<0-255>.",
		    "<0-255>\n";
	if ($scdnip) {
		$scdnip !~ /[0-9]+/ and
			die "Error: $scdnip [scdnip] is not in format ",
			    "<0-255>\n";
		$scdnip > 254 and $scdnip = 254;
		$scdnip < 0 and $scdnip = 1;
	} else {
		$scdnip = 1;
	}
	if ($ecdnip) {
		$ecdnip !~ /[0-9]+/ and
			die "Error: $ecdnip [ecdnip] is not in format ",
			    "<0-255>\n";
		$ecdnip > 254 and $ecdnip = 254;
		$ecdnip < 0 and	$ecdnip = 1;
	} else {
		$ecdnip = 254;
	}
	print "\nScanning for open port $port on $ccnip.($scdnip > $ecdnip) ",
	      "using $protoName protocol.\n";
	$verboseCCIPA and 
		print "Verbose mode is on, printing refused connections.\n\n"
	or
		print "Verbose mode is off, only printing accepted ",
			 "connections.\n\n";
	for ($i = $scdnip; $i < $ecdnip + 1; $i++) {
      ######################################################
      ## I forgot that SIGNALS don't yet work on Windoze.
      ## So I had to comment out the following two lines.
      ## 
	   #	$SIG{"ALRM"}    = sub { close(SOCKET); };
	   #	alarm $connectTime;
      ##
      ## Added the following line to replace the SIGNAL code.
      ## Remove this when we can use SIGNALS.
      ##
	   sub { close(SOCKET); };
      ######################################################
		socket(SOCKET, PF_INET, SOCK_STREAM, $protocolID);
		$cdnip	= "$ccnip.$i";
		$iaddr  = inet_aton($cdnip);
		$paddr  = sockaddr_in($port, $iaddr);
		if (connect(SOCKET, $paddr)) {
			printf "%0s %20s %14s %12s", $protoName, $cdnip, $port;
			print "Connection accepted.\n";
			close(SOCKET);
		} else {
			if ($verboseCCIPA) {
				printf "%0s %20s %14s %12s", $protoName, $cdnip, $port;
				print "Connection refused.\n";
			}
			close(SOCKET);
		}
	}
	exit 1;
}
################################################
# singleHostPortScan:
#  - this subroutine scans a single host;
#    scanning for open ports from 1-65536 (int)
################################################
sub singleHostPortScan()
{
	if ($ccnip !~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/) { 
		gethostbyname($ccnip) or
			die "Error: Can't resolv $ccnip [dns/ip].\n";
	}
	print "\nScanning for all open ports on $ccnip using $protoName ",
	      "protocol.\n";
	$verboseSHPS and
		print "Verbose mode is on, printing refused connections.\n\n"
	or
		print "Verbose is off, only printing accepted connections.\n\n";
	for ($port = 1; $port < 65536; $port++) {
   ######################################################
   ## I forgot that SIGNALS don't yet work on Windoze.
   ## So I had to comment out the following two lines.
   ## 
	#	$SIG{"ALRM"}    = sub { close(SOCKET); };
	#	alarm $connectTime;
   ##
   ## Added the following line to replace the SIGNAL code.
   ## Remove this when we can use SIGNALS.
   ##
	   sub { close(SOCKET); };
   ######################################################
		socket(SOCKET, PF_INET, SOCK_STREAM, $protocolID);
		$iaddr	= inet_aton($ccnip);
		$paddr	= sockaddr_in($port, $iaddr);	
		if (connect(SOCKET, $paddr)) {
			printf "%0s %20s %14s %12s", $protoName, $ccnip, $port;
			print "Connection accepted.\n";
			close(SOCKET); 
		} else {
			if ($verboseSHPS) {
				printf "%0s %20s %14s %12s", $protoName, $ccnip, $port;
				print "Connection refused.\n";
			}
			close(SOCKET);
		}
	}
	exit 0;
}
