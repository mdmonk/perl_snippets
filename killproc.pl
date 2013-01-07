use Win32::Setupsup ;

sub newpid {

$pid = 32 ;

while(!$died)
{
	die if(!Win32::Setupsup::GetProcessList('', \@proc, \@threads));

	$died = 1;	

            # GetProcessList & PIDS
	foreach $p (@proc)
	{
                print "#Name: ${$p}{'name'}#pid: ${$p}{'pid'}#\n";
		# $died = 0 if ${$p}{'pid'} == $pid;

		$selection = "<your selection>" ;
		# Lets have a look for selection.exe process
		if ( ${$p}{'name'} =~ /$selection/ )
                       {
			print "Located process $selection - Analyzing...PID:" ;
			$selpid = ${$p}{'pid'} ;
			print "$selpid.\nSending 2 KILL-SIG\n" ;
			die if(!Win32::Setupsup::KillProcess($selpid, 0)) ;
			die if(!Win32::Setupsup::KillProcess($selpid, 0)) ;
		}
	}
     }
}

&newpid ;

