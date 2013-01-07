use Win32::EventLog;

$first = 0;
$count = 0;
	
$EventLog = new Win32::EventLog("System") || die $!;
$EventLog->GetOldest($first);
$EventLog->GetNumber($count);

print "$first\t$count\n";

#$EventLog->Close();
