###################################
# Perl script to ping hosts in a
# subnet, if a host responds, use
# tracert to find where they are.
#
# Win32 Perl Script
###################################
use Net::Ping;

my $i;
my $IPaddr;
my @rtn;

$found = "d:\\tmp2\\found.txt"; 
open (OUTPUT, "+>$found") || die "Can't open file: $!\n";

$p = Net::Ping->new("icmp");

for ($i=1;$i<255;$i++) {
  $IPaddr = "138.87.8." . $i;
  # One way is the system ping.
  # @rtn = `ping $IPaddr -n 2`;

  # Or you could get the route while you are
  # doing a system ping.
  # @rtn = `ping -a -r 9 -n 1 $IPaddr`";

  # But we are going to use the Net-Ping
  # module.  
  if ($p->ping($IPaddr, 2)) { 
    @rtn = `tracert $IPaddr`;
    print OUTPUT @rtn; 
  } else { 
    print "No Ping Response...\n";
  } 
}
$p->close();
close(OUTPUT);
