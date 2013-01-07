#!/usr/bin/perl
#
use Net::SNMP;

#
# liest die MIB-II System-Group eines SNMP-Devices aus und zeigt sie an.
#
# Usage: get_snmp_info device1 [device2 [...]]
#
# Jan. 2000 be@cli.de
#

foreach $device( @ARGV )
	{
	print "$device:\n";

	($session, $error) = Net::SNMP->session( -hostname => $device );
	die "error.0\n" if(!defined($session));

	$object = "1.3.6.1.2.1.1.1.0";	# sysDescr
	$response = $session->get_request($object);
	die "error.1: $session->error\n" if(!defined($response));
	print "sysDescr: $response->{$object}\n";

	$object = "1.3.6.1.2.1.1.3.0";	# sysUpTime
	$response = $session->get_request($object);
	die "error.3: $session->error\n" if(!defined($response));
	print "sysUpTime: $response->{$object}\n";

	$object = "1.3.6.1.2.1.1.4.0";	# sysContact
	$response = $session->get_request($object);
	die "error.4: $session->error\n" if(!defined($response));
	print "sysContact: $response->{$object}\n";

	$object = "1.3.6.1.2.1.1.5.0";	# sysName
	$response = $session->get_request($object);
	die "error.5: $session->error\n" if(!defined($response));
	print "sysName: $response->{$object}\n";

	$object = "1.3.6.1.2.1.1.6.0";	# sysLocation
	$response = $session->get_request($object);
	die "error.6: $session->error\n" if(!defined($response));
	print "sysLocation: $response->{$object}\n";

	print "\n";
	$session->close;
	}
