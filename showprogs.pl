#This Perl script prompts for an NT machine name (sans \\), verifies operation by pinging it, then verifies that the Server service is turned on, and finally remotely connects to the registry and provides a listing of programs listed in the "Add/Remove" programs section of the registry.
#NOTE: Both machines must be running TCP/IP...
#!/usr/bin/perl
# showprogs.pl - Query remote NT machines for installed program list	
#
# Syntax:
#    showprogs.pl <wait>
#  <wait> defaults to 10 seconds if no input
###############################################
use Win32::Registry;
use Net::Ping;
use Win32::Service;

my ($p, $node, $main, $hnode, $hkey, %values, @values, $wait, %serverstat);

if ($ARGV < 1)
	{ # default to 10 second if no command line entries
	$wait = "10";
	}
else	{ # else accept first command line entry as wait value
	+$wait = $ARGV[0]; # only accept integers
	}

print "Enter a computer name ===> ";
while (($node=<STDIN>)=~m/.{17,}/)
	{
	print "The machine name must be 15 characters or less.\n";
	print "Please enter a valid machine name ===> ";
	}
chomp $node;

print "Connecting to $node...";
$p = Net::Ping->new("icmp");
if ($p->ping($node,$wait))
	{
	print "system is online...";
	Win32::Service::GetStatus("\\\\".$node, "LanManServer", \%serverstat) or %serverstat = (CurrentState => "N/A");
	if ($serverstat{CurrentState} eq "4")
		{
		$node = "\\\\".$node;
		print "Services active...";
		$main::HKEY_LOCAL_MACHINE->Connect($node, $hnode) or die "Cannot connect to $node";
		$hnode->Open("software\\microsoft\\windows\\currentversion\\uninstall",$hkey) or die "nothing Installed\n";
		print "connected!\n\n";
		$hkey->GetKeys(\@values);
		$hkey->Close();
		
		print "Uninstall List for $node\n";
		print "------------------------------------\n";
		print "\[Keyname\] = DisplayName\n";
		print "------------------------------------\n";
		foreach (@values)
		        {
			$hnode->Open("software\\microsoft\\windows\\currentversion\\uninstall\\".$_,$hkey);
			$hkey->GetValues(\%values);
		        print "\[$_\] = $values{DisplayName}[2]\n";
			}	
	
		$hkey->Close();
		$hnode->Close();
		}
	elsif ($serverstat{CurrentState} ne "4")
		{
		print "Server inactive...";
		}
	}
else	{
	print "unreachable...";
	}
