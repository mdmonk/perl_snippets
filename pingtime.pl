use Win32;
use Net::Ping;

my ($time1, $time2, $diff, $total, $avg, @timelist, @newlist);
$node = $ARGV[0];							# Read node from command line
$pkt = 32;								# Packet size - max = 1024
$p = Net::Ping->new("icmp",1,$pkt);					# Create new ICMP object
$n = 5;									# Ping host $n times

print "TickPing!\n\n";

for (1..$n)
	{
	$time1 = Win32::GetTickCount;					# Get the before time
	print "Pinging $node...";
	if ($p->ping($node,1))						# Ping the host
		{
		$time2 = Win32::GetTickCount;				# Get the after time
		$diff = $time2 - $time1;				# Find the difference
		push(@timelist, $diff);					# Push the results into a list for later
		print "node is alive and is $diff ticks away.\n"
		}
	else	{
		$time2 = Win32::GetTickCount;				# Get the after time
		$diff = $time2 - $time1;				# Find the difference
		print "node is unreachable after $diff ticks.\n"
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
print "\nAfter $n attempts, $node is an average of $avg ticks away.\n";

