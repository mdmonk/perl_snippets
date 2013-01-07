#!perl

#
#  Title:   ntwho.pl
#  Author:  Shawn A. Clifford
#  Date:    2000Apr10
#  Purpose: Looks up all users on all machines in the
#           current domain.  Or finds the machines that
#           a specified user is logged into.
#  Usage:   ./ntwho.pl [-r] [ nt_username ... ]
#               -r : Causes ntwho.pl to regenerate the users.hash
#                    file.  This can take a long time!
#  Files:       Creates/reads 'users.hash'
#

use Getopt::Long;
$Getopt::Long::order=$PERMUTE;

my (%USERS, %opts);
my (@NODES, @NODES2, @NetBIOS);
my ($node, $line, $user, $opts, $status);
%USERS = @NODES = @NODES2 = ();

&GetOptions("r", \$opts);

if ( $opts ) {
   print "\nGathering list of nodes in the XXX and YYY domains ...";
   @NODES = `netdom /domain:XXX /noverbose member`;
   @NODES2 = `netdom /domain:YYY /noverbose member`;
   push @NODES, @NODES2;


   print " Done\!\n".scalar(@NODES)." nodes listed.\n\n";

   foreach $node (@NODES) {
      $node =~ s/\\//g;
      $node =~ tr/a-z/A-Z/;
      chomp $node;
      print "\015";
      print "Processing $node ...", " "x20;

      $status = `ping -n 2 $node`; # Is the node alive?
      next if ( $? || $status =~ m/timed out/i || $status =~ m/Bad IP/i );
         
      @NetBIOS = `nbtstat -a ${node}`;
      foreach $line (@NetBIOS) {
	 if ($line =~ /<03>/ && $line =~ /UNIQUE/ && $line !~ /$node/) {
	    $user = (split(/\s+/, $line))[0];
	    $USERS{$user} = $node;
	 }
      }
   }

   open(OUT,">users.hash");
   print "\nSaving hash table ...";
   foreach $user (keys(%USERS)) {
      print OUT "$user,$USERS{$user}\n";
   }
   print "\n\n";
   close(OUT);
}
else {
   print "\nReading hash table ...";
   open(IN,"<users.hash");
   while (<IN>) {
      chomp;
      ($user,$node) = split(/,/, $_);
      $USERS{$user} = $node;
   }
   close(IN);
   print " Done\!\n".scalar(keys %USERS)." hash table entries.\n\n";
}

if ($#ARGV >= 0) {           # Arguments were passed
   foreach $user (@ARGV) {
      $user =~ tr/a-z/A-Z/;
      printf("%-14s", $user);
      if (exists $USERS{$user}) {
	 print " is on node \\\\$USERS{$user}\n";
      }
      else {
	 print " is not logged in\n";
      }
   }
} 
else {
   foreach $user (keys(%USERS)) {
      printf("%-14s", $user);
      print " is on node \\\\$USERS{$user}\n";
   }
}

print "\n";
