use Win32::EventLog;
Win32::EventLog::Open($EventLog , "Auto Reboot", "$server") || warn("Can't
open event log");
    $Event = {
                'EventType' => EVENTLOG_INFORMATION_TYPE,
                'Category' => 0,
                'EventID' => 0x1003,
                'Data' => '',
                'Strings' => "Rebooted by $who : $where",
     };
    $EventLog->Report($Event) || warn("Can't write to the event log $!");
