####################################################
# schedjob.pl
# To schedule a job to be run on Win32 machines.
#
# Requires Roth's AdminMisc module?
# http://www.roth.net
####################################################
use Win32::AdminMisc;
$schedtime = "08:45";
# Run it on the 10th, 11th, and 12th of the month.
$DOM = "";
# $DOM = 2**10, 2**11, 2**12;
# We want this to run on Fridays and Sundays...
$DOW = SUNDAY | MONDAY | TUESDAY | WEDNESDAY | THURSDAY | FRIDAY | SATURDAY;
# $ DOW = THURSDAY;
# We want this to run EVERY month...
$Flags = JOB_RUN_PERIODICALLY;
$Command = "perl.exe d:\\data\\perl.tmp\\sfqchk\\sfqchk.pl";
# $Command = "d:\\apps\\notes\\notes.exe";
# First param is the server name.
$Job = Win32::AdminMisc::ScheduleAdd("\\\\T003834",  
                         $schedtime,
                         $DOM,
                         $DOW,
                         $Flags,
                         $Command);
print "Job \# is: $Job\n";
