#  Collects ping-based information for WAN-trend analysis
#  Accepts two command-line arguments
#  -i	time interval between ping-sets (in seconds)
#  -n	number of times ping-sets will be sent
#  v1.0, mar99 : initial version - tevfik@itefix.no 

use Getopt::Std;

# BEGIN CUSTOMIZE !!!
$logdir = "C:\\WANPING\\LOGS";

# Machine-list with IP-adresses
@servers = (
	"xxx.yyy.aaa.aaa", 	
	"xxx.yyy.bbb.aaa", 	
	"xxx.yyy.bbb.bbb" 	
 );

# Ping packet-sizes
@packetlengths = (
	"32",
	"256",
	"2048"
);

# END CUSTOMIZE

getopts("i:n:") or die $!;
$interval = $opt_i;
$count = $opt_n;

for ($i=0 ; $i < $count; $i++) {

	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

	foreach $server (@servers) {
		foreach $packetlength (@packetlengths) {
			$logfile= sprintf "$logdir\\$server.$packetlength.%04d%02d%02d.log",$year, $mon+1, $mday;
			$echocmd = sprintf "echo Date/time : %04d/%02d/%02d %02d:%02d >> %s", $year, $mon+1, $mday, $hour, $min, $logfile;
			system $echocmd;
			system "ping -l $packetlength -n 2 $server >> $logfile";
			system "echo ---------- >> $logfile";
		}
	}

	sleep $interval;	
}

