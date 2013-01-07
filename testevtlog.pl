use Win32::EventLog;

write2eventlog();

sub write2eventlog ($$$$) {
# parameters:
#	$cName - application name that appears in SOURCE field
#	$cMessage - value for event log DESCRIPTION field
#	$cData - value for event log DATA field
#	$iEventID - value for EVENTID field (usually an errorcode)

	my ($pEvent, $iEventID, $logentry, $cMessage, $cData);
	($cName, $cMessage, $cData, $iEventID) = @_;

	# create defaults if things are missing
	$cName = "NETMAN" unless $cName;
	$cMessage = "This is a test" unless $cMessage;
	$cData = "This is data" unless $cData;
	$iEventID = 0 unless $iEventID;

	# create eventlog hash
	$logentry = { "EventID" => $iEventID,
			"EventType" => EVENTLOG_ERROR_TYPE,
			"Category" => NULL,
			"Strings" => $cMessage, 
			"Data" => $cData,
	};

	$pEvent = new Win32::EventLog($cName) or die "Could not create new event\n";
	$pEvent->Report($logentry) or die "Could not write to event log\n";

	$pEvent->CloseEventLog;
}
