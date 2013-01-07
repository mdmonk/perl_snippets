testeventlog();

sub testeventlog {
     write2eventlog("somedumapp", "describing myself", "data junk", 1000);
}

sub write2eventlog ($$$$) {
# DESCRIP:
#    Writes message to eventlog
# PARAMS:
#    $cName - application name that appears in SOURCE field
#    $cMessage - value for event log DESCRIPTION field
#    $cData - value for event log DATA field
#    $iEventID - value for EVENTID field (usually an errorcode)

     my ($pEvent, $iEventID, $logentry, $cMessage, $cData);
     ($cName, $cMessage, $cData, $iEventID) = @_;

     # create eventlog hash
     $logentry = { "EventID" => $iEventID,
               "EventType" => EVENTLOG_ERROR_TYPE,
               "Category" => NULL,
               "Strings" => $cMessage,
               "Data" => $cData,
     };

     $pEvent = new Win32::EventLog($cName) or die "Could not create new
event\n";
     $pEvent->Report($logentry) or die "Could not write to event log\n";

     $pEvent->CloseEventLog;
}
