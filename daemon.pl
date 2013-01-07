#####################################################
# Program Name: daemon.pl
# Programmer:   Chuck Little
# Description:  This script runs as a daemon. 
#
# Revision History:
#  - 0.0.1 (10 Mar 1999)
#   - Initial Coding. Excerpted some of this
#     code from the Perl Cookbook.
#####################################################
use POSIX;

# Fork once, then have the parent process exit.
$pid = fork;
exit if $pid;
die "Unable to fork new process: $!\n" unless defined($pid);

# Dissociate from the controlling terminal that started
# this script.
POSIX::setsid() or die "Can't start a new session: $!\n";

# trap fatal signals. Set a flag to indicate we need to exit
# gracefully.
$time_to_die = 0;

sub signal_handler {
  $time_to_die = 1;
}

$SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signal_handler;
# trap or ignore $SIG{PIPE}

############################################
# Now get to work....
############################################

until ($time_to_die) {
  # code goes here....


  if (-e /opt/CC/scripts/ito/tmp/SFQInput.dat) {
     $rtncode = `/opt/CC/scripts/ito/sfqutils/sfqwrapper.pl`
  } # end if
  sleep(3600);
} # end until
