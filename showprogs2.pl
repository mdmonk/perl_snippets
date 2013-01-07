##################################################
# Program Name: showprogs2.pl
# Description:  Query NT machines for installed
#               program list. Script will find
#               out the server name.
#
# Programmer:   Chuck Little
#
# Revision History:
#  - 0.0.1 (Chuck L.)
#    - Initial coding.
#  - 0.1.0 (Chuck L.)
#    - Functional. Would like to add ability to
#      connect to a remote NT's registry. Perhaps
#      in the future.
##################################################
use strict;
use Win32::Registry;

my ($p, $node, $main, $hnode, $hkey, %values, @values, %serverstat);
$node        = Win32::NodeName();
$node        =~ m/(\w+).*/;
$node        = $1;
chomp $node;
my $ver      = "0.1.0";
my $vdate    = "6 Apr 1999";
my $printout = 1;              # 1=print to output file. 0=go to STDOUT
my $outfile  = "proglist.dat";
if( $ARGV[0] =~ "-v" || $ARGV[0] =~ "-V" ) {
  print "\nShowprogs2.pl: Displays list of installed software.\n";
  print "Programmed by Chuck Little of the Network Automation Team\n";
  print "Revision v.$ver, $vdate\n\n";
  exit;
} # end if

if($printout) {
  if( open(OUTFILE, ">$outfile") ) {
     select(OUTFILE);
  } # end if
} # end if
print "Connecting to $node...";
$node = "\\\\".$node;
$main::HKEY_LOCAL_MACHINE->Connect($node, $hnode) or die "Cannot connect to $node";
$hnode->Open("software\\microsoft\\windows\\currentversion\\uninstall",$hkey) or die "nothing Installed\n";
print "connected!\n\n";
$hkey->GetKeys(\@values);
$hkey->Close();

print "Installed Application List for $node\n";
print "------------------------------------\n";
foreach (@values) {
	$hnode->Open("software\\microsoft\\windows\\currentversion\\uninstall\\".$_,$hkey);
	$hkey->GetValues(\%values);
   print "\[$_\] = $values{DisplayName}[2]\n";
}	
$hkey->Close();
$hnode->Close();
if($printout) {
  close (OUTFILE);
} # end if
