#!perl.exe
#############################################################
# write_evt.pl
# - writes an event to the event log.
#############################################################
## examples
#
# &writeevent("i=5002", "t=w", "s=File Distribution Script", "d=Error in directory tree.");
#   i= an integer that is the id of the event
#   t= e for error, w for warning, or i for information
#   s= a string containing the source of the error (usually application name)
#   d= a description of the error
#
##
use Win32::EventLog;

sub writeevent
{
    #parse the input array
    foreach (@_)
    {
       (/h=/i) and $host = (split(/=/, $_, 2))[1];
       (/s=/i) and $src  = (split(/=/, $_, 2))[1];
       (/i=/i) and $id   = (split(/=/, $_, 2))[1];
       (/t=/i) and $type = (split(/=/, $_, 2))[1];
       (/d=/i) and $desc = (split(/=/, $_, 2))[1];
    }

    #if not input does not specify a setting, set variable to default
    ($host) ? "\\\\".$host : "\\\\".($ENV{COMPUTERNAME});
    ($src)  or ($src  = "PerlWin32");
    ($id)   or ($id   = 1);
    ($type) or ($type = 'i');

    ($type =~ /e/i) and ($type = EVENTLOG_ERROR_TYPE);
    ($type =~ /i/i) and ($type = EVENTLOG_INFORMATION_TYPE);
    ($type =~ /w/i) and ($type = EVENTLOG_WARNING_TYPE);

    #these three lines write to the Event Log
    %Event = ('EventID' => $id, 'EventType' => $type, 'Strings' => $desc);
    Win32::EventLog::Open($EventObj, $src, $host) || die "Unable to open NT Event Log: $!\n";
    $EventObj->Report(\%Event) || die "Unable to generate event: $!\n";

}
