##################################################
# Program Name: rotlog.pl
# Programmer:   Chuck Little
#
# Description:  This script rotates log files.
#               First it checks the log file size
#               and only rotates the file if it is
#               to large.
#
# Date: 9 Dec 1998
##################################################

use strict;

my $maxcycle = 5;
my $filename;
my $name;
if (-s "test.cwl" > 99455) {
  print "Rotating log file...\n";
  rotateLog();
} else {
  print "Not rotating log file...\n";
}
sub rotateLog {
   my @LOGNAMES=('test.cwl');
   foreach $filename (@LOGNAMES) {
     for (my $s=$maxcycle; $s--; $s >= 0 ) {
	    my $oldname = $s ? "$filename.$s" : $filename;
	    my $newname = join(".",$filename,$s+1);
	    rename $oldname,$newname if -e $oldname;
     }
   }
   foreach $name (@LOGNAMES) {
     system("date /t > $name");
   }
} # end rotateLog

