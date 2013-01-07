###############################################################
# Program Name: shutdwn2.pl
# Programmer:   Chuck Little
# Desc:         This script does a shutdown of Win32 systems
#               and then cancels the shutdown. Just testing
#               the facility to shut down Win32 systems
#               through Perl.
###############################################################
use Win32;

$machine = Win32::NodeName();
print "Rebooting local machine\n";
Win32::InitiateSystemShutdown($machine, "Shutting the System Down", 30, 1,1) or die "InitiateSystemShutdown: ", Win32::FormatMessage(Win32::GetLastError);

sleep(5);

Win32::AbortSystemShutdown($machine);

