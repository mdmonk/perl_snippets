############################################
# Program Name: rbtmenu.pl
# Programmer: Chuck
# Script to display a "working" menu of
# reboot options.
############################################	
use Win32;

	system "cls";

	print "\n";
	print " Sytem Shutdown Menu\n";
	print "\n";
	print "  1 Shutdown the System\n";
	print "  2 Reboot the System\n";
	print " 99 Abort Shutdown/Reboot\n";
	print "\n";
	print "Select 1, 2 or 99: ";
	$select = <STDIN>;
	chomp $select;

	if ($select eq 1)
	{
#
# Shutdown the system
#
		Win32::InitiateSystemShutdown(undef, "Shutting Down in 15 seconds",
			15, 0, 0);
	}

	elsif ($select eq 2)
	{
#
# Shutdown the system
#
		Win32::InitiateSystemShutdown(undef, "Rebooting in 15 seconds",
			15, 0, 1);
	}

	elsif ($select eq 99)
	{
#
# Abort shutdown / reboot
#
		Win32::AbortSystemShutdown(undef);
	}
#
