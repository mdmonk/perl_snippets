use Win32;
use Win32::Service;
use Win32::Registry;
use Win32::Registry::IO;
use Win32::Registry::Find;
use Net::Ping;

my $node = $ARGV[0];

%ini = (	PingTimeout 	=> 3,
		SlowLinkMetric	=> 100,
		DebugLinkMetric => 'yes',
	);

get_remotereg();
print "Closing Handles...\n";
$unode->Close();
$hnode->Close();
#*********************************************************
#*  connect to remote registry
#*********************************************************
sub get_remotereg
	{
	my ($p, %serverstat, %rcmdstat);
	my ($time1, $time2, $diff, $total, $avg, @timelist, @newlist);
	my ($sysroot);
	$n = 6;									# Ping host $n times

	print "Connecting to $node...";
	print LOGFILE "Connecting to $node...";
	$p = Net::Ping->new("icmp",$ini{PingTimeout},32);
	if ($p->ping($node,$ini{PingTimeout}))
		{
		print "system is online...";
		print LOGFILE "system is online...";
		for (1..$n)
			{
			$time1 = Win32::GetTickCount;					# Get the before time
			if ($p->ping($node,$ini{PingTimeout}))				# Ping the host
				{
				$time2 = Win32::GetTickCount;				# Get the after time
				$diff = $time2 - $time1;				# Find the difference
				push(@timelist, $diff);					# Push the results into a list for later
				}
			}
		@newlist = sort(@timelist);						# Sort the list
		pop(@newlist);								# Remove the max time
		shift(@newlist);							# Remove the min time
		foreach (@newlist)
			{
			$total = $total + $_;						# Add up the remaining times
			}
		$avg = $total / ($n - 2);						# Take the average of the results
		if ($avg > $ini{SlowLinkMetric})
			{
			print "($avg ms)slow link...";
			print LOGFILE "($avg ms)slow link...";
			print INACTIVE "$node, slow link, $avg, $ini{SlowLinkMetric}\n";
			return "0";
			}
		if ($ini{DebugLinkMetric} eq lc("yes"))
			{
			print "($avg ms)";
			}
		Win32::Service::GetStatus("\\\\$node", "LanManServer", \%serverstat) or %serverstat = (CurrentState => "N/A");
		Win32::Service::GetStatus("\\\\$node", "RemoteCMD", \%rcmdstat) or %rcmdstat = (CurrentState => "N/A");
		Win32::Service::GetStatus("\\\\$node", "WNTHW", \%wnthwstat) or %wnthwstat = (CurrentState => "N/A");
		Win32::Service::GetStatus("\\\\$node", "SFFSD", \%nssfdstat) or %nssfdstat = (CurrentState => "N/A");
		if ((($rcmdstat{CurrentState} eq "1") or ($rcmdstat{CurrentState} eq "7")) and (lc($ini{StartRCMD}) eq "yes"))
			{
			Win32::Service::StartService("\\\\$node","RemoteCMD") or warn "!";
			sleep(5);
			Win32::Service::GetStatus("\\\\$node", "RemoteCMD", \%rcmdstat) or %rcmdstat = (CurrentState => "N/A");
			}
		if (($serverstat{CurrentState} eq "4") and ($rcmdstat{CurrentState} eq "4"))
			{
			$node = "\\\\$node";
			print "Services active...";
			print LOGFILE "Services active...";
			$hnode = Win32::Registry::Connect($node, HKEY_LOCAL_MACHINE) or return "0";
			$unode = Win32::Registry::Connect($node, HKEY_CURRENT_USER) or return "0";
#			$main::HKEY_LOCAL_MACHINE->Connect($node, $hnode) or return "0";		# Before Win32::Registry Patch
#			$main::HKEY_CURRENT_USER->Connect($node, $unode) or return "0";			# Before Win32::Registry Patch
			print "connected!\n";
			print LOGFILE "connected!\n";
			$sysroot = get_reg_data("HKLM","software\\microsoft\\windows nt\\currentversion","SystemRoot",1);
			@windir = split(/:/,$sysroot);
			if (-e "$node\\$windir[0]\$$windir[1]\\")
				{
				print "You now have a handle to HKLM (\$hnode) and HKCU (\$unode)\n";
				return "1";
				}
			else	{
				print "Could not verify $node\\$windir[0]\$$windir[1]\\...";
				print LOGFILE "Could not verify $node\\$windir[0]\$$windir[1]\\...";
				return "0";
				}
			}
		elsif (($serverstat{CurrentState} ne "4") and ($rcmdstat{CurrentState} eq "4"))
			{
			print "Server inactive...";
			print LOGFILE "Server inactive...";
			print INACTIVE "$node, online, $serverstat{CurrentState}, $rcmdstat{CurrentState}\n";
			return "0";
			}
		elsif (($rcmdstat{CurrentState} ne "4") and ($serverstat{CurrentState} eq "4"))
			{
			print "RCMD inactive...";
			print LOGFILE "RCMD inactive...";
			print INACTIVE "$node, online, $serverstat{CurrentState}, $rcmdstat{CurrentState}\n";
			return "0";
			}
		elsif (($serverstat{CurrentState} ne "4") and ($rcmdstat{CurrentState} ne "4"))
			{
			print "Services inactive...";
			print LOGFILE "Services inactive...";
			print INACTIVE "$node, online, $serverstat{CurrentState}, $rcmdstat{CurrentState}\n";
			return "0";
			}
		}
	else	{
		print "unreachable...";
		print LOGFILE "unreachable...";
		print INACTIVE "$node, unreachable, N/A, N/A\n";
		return "0";
		}
	}
#*********************************************************
#*  retrieve registry key values, or n/a if key not present - after the Win32::Registry patch
#*********************************************************
sub get_reg_data     
	{
	my %vals;
	my $temp;
	my $data;
	my $subtree = $_[0];
	my $key = $_[1];
	my $value = $_[2];
	my $returnval = $_[3];

	if ($subtree eq "HKLM")
		{
		$keyfound = $hnode->Open($key, $hkey);
		}
	elsif ($subtree eq "HKCU")
		{
		$keyfound = $unode->Open($key, $hkey);
		}
	else
		{
		return "N/A";
		}

	if ($keyfound)
		{
		$hkey->GetValues(\%vals);
		$temp = $vals{$value};
		$data = $$temp[2];
		if (($data) or ($data eq "0"))
			{
			return $data;
			$hkey->Close() or print "No need to Close $hkey\n";
			$hnode->Close() or print "No need to Close $hkey\n";
			$unode->Close() or print "No need to Close $hkey\n";
			}
		elsif ($_[3] == 0)
			{
			return "0";
			$hkey->Close() or print "No need to Close $hkey\n";
			$hnode->Close() or print "No need to Close $hkey\n";
			$unode->Close() or print "No need to Close $hkey\n";
			}
		elsif ($_[3] == 1)
			{
			return "N/A";
			$hkey->Close() or print "No need to Close $hkey\n";
			$hnode->Close() or print "No need to Close $hkey\n";
			$unode->Close() or print "No need to Close $hkey\n";
			}
		else	{
			return "Err";
			$hkey->Close() or print "No need to Close $hkey\n";
			$hnode->Close() or print "No need to Close $hkey\n";
			$unode->Close() or print "No need to Close $hkey\n";
			}
		}
	elsif($_[3] == 0)
		{
		return "0";
		$hkey->Close() or print "No need to Close $hkey\n";
		$hnode->Close() or print "No need to Close $hkey\n";
		}
	elsif($_[3] == 1)
		{
		return "N/A";
		$hkey->Close() or print "No need to Close $hkey\n";
		$hnode->Close() or print "No need to Close $hkey\n";
		}
	}
#*********************************************************
#*  retrieve registry key values, or n/a if key not present - old before Win32::Registry patch
#*********************************************************
sub get_reg_data_old     
	{
	my %vals;
	my $temp;
	my $data;
	my $subtree = $_[0];
	my $key = $_[1];
	my $value = $_[2];
	my $returnval = $_[3];

	if ($subtree eq "HKLM")
		{
		$keyfound = $hnode->Open($key, $hkey);
		}
	elsif ($subtree eq "HKCU")
		{
		$keyfound = $unode->Open($key, $hkey);
		}
	else
		{
		return "N/A";
		}

	if ($keyfound)
		{
		$hkey->GetValues(\%vals);
		$temp = $vals{$value};
		$data = $$temp[2];
		if (($data) or ($data eq "0"))
			{
			return $data;
			$hkey->Close();
			$hnode->Close();
			$unode->Close();
			}
		elsif ($_[3] == 0)
			{
			return "0";
			$hkey->Close();
			$hnode->Close();
			$unode->Close();
			}
		elsif ($_[3] == 1)
			{
			return "N/A";
			$hkey->Close();
			$hnode->Close();
			$unode->Close();
			}
		else	{
			return "Err";
			$hkey->Close();
			$hnode->Close();
			$unode->Close();
			}
		}
	elsif($_[3] == 0)
		{
		return "0";
		$hkey->Close();
		$hnode->Close();
		}
	elsif($_[3] == 1)
		{
		return "N/A";
		$hkey->Close();
		$hnode->Close();
		}
	}

