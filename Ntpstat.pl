# NTPSTAT.PL - Perl script to monitor the print server queues on NT servers
#
# This script was written by Paul Popour (ppopour@infoave.net) in 1999.
# It is released into the public domain.  You may use it freely, however,
# if you make any modifications and redistribute, please list your name
# and describe the changes. This script is distributed without any warranty,
# express or implied.
#
# NTPSTAT will take any of the three syntax
#
# perl ntstat.pl                   (if you hardcode the server names)
# perl ntstat.pl server1 server2
# perl ntstat.pl all
#

use Win32;
use Win32::NetAdmin;
use Win32::TieRegistry( Delimiter=>"/" );
use Win32::Service;

#
# You can use a hardcoded, automatic, or command line feed of the server names
##############################################################################
#
# Hardcoded runs quicker because you're only checking server that you use as
# a print server, however, this won't automatically pick up any new server
# you decide to use as a print server and always checks all that are coded,
# and you have to edit the script to add or delete print servers.
#
# Despite all that this is what I use. (Speed thrills and I hate typing)
#
# SYNTAX = perl ntstat.pl
#
# Enter hardcoded names like this - @servers = ("PSERVER1", "PSERVER2");

@servers = ();

##############################################################################
#
# Or feed the @ARGV array into the @server array and feed the names from
# the command line seperated by a space, ie., ntstat.pl pserver1 pserver2
#
# SYNTAX = perl ntstat.pl server1 server2
#

if (@ARGV > 0){@servers = @ARGV;}

##############################################################################
#
# Or use the automatic method that will look at each server, be patient.
#
# SYNTAX = perl ntstat.pl all
#

if ("\U$ARGV[0]\E" eq "ALL"){@servers = &getservers;}

#
#

if (@servers == 0){die "\n\n
SYNTAX: perl ntstat.pl      (you must hardcode server names into script)\n
\tperl ntstat.pl server1 server2\n
\tperl ntstat.pl all\n";}

#
##############################################################################
#
# $deadjob defines how long a job can be in a queue before you want to have
# the option of deleting it. Hint - change to 1 and totally control print
# jobs but not if you've got hundreds of print jobs.
#
##############################################################################

$deadjob = '60';
my ($sec,$min,$hour,$dom,$mon,$year,$x,$x,$x)=localtime(time);
$D1 = sprintf("%02d/%02d/%02d",$mon+1,$dom,$year+1900);
$T1 = sprintf("%02d:%02d",$hour,$min);
print "=" x 26 . "$D1  $T1" . "=" x 26;
print "\n\nSERVER          PRINT QUEUE              MINUTES       SIZE
USER\n";
print " NAME               NAME                IN QUEUE      OF JOB     NAME\n";
foreach $server (@servers)
 {
 unless ($key = $Registry->Open("//$server/LMachine/SYSTEM/CurrentControlSet/Control/Print/Printers/"))
  {print "Unable to attach to registry key on $server\n"; next;}
 unless ($spldir = $key->GetValue("DefaultSpoolDirectory"))
  {print "Unable to obtain spooler directory from $server\n"; next;}
 undef @remove;
 @A1 = split (":", $spldir);
 $spldir = ("\\\\$server\\$A1[0]\$$A1[1]");
 opendir PSDIR, $spldir;
 @filenames = grep (!/^\.\.?$/ , readdir (PSDIR));
 closedir PSDIR;
 next if (@filenames == 0);
 next if ((@filenames == 1) && ($filenames[0] eq "LPDSVC"));
 print "\n" . "=" x 70 . "\n\n$server\n\n";
 foreach $file (@filenames)
  {
  @fnext = split ('\.', "$file");
  if ($fnext[1] eq "SHD")
   {
   $ftime = (stat("$spldir\\$file"))[9];
   my ($fsec,$fmin,$fhour,$fdom,$fmon,$fyear,$x,$x,$x)=localtime($ftime);
   if ("$fyear$fmon$fdom" eq "$year$mon$dom"){$dif = ($min + ($hour * 60)) -($fmin + ($fhour * 60));}
   else {$dif = 'old';}
   $size = -s ("$spldir\\$fnext[0].spl");
   next if ($size eq "" || $size eq "0" );
   1 while $size =~ s/(.*\d)(\d\d\d)/$1,$2/;
   $pname = &procprt("$spldir\\$file");
   $uname = &procusr;
   undef @bytes;
format STRING1 =
@<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<@>>>>>>>@>>>>>>>>>>>>>  @<<<<<<<<<<<<
$server,$pname,$dif,$size,$uname
.
$~ = "STRING1";
write;
   if (($dif eq "old") || ($dif > $deadjob))
    {
    $trash = "";
    print "\nPurge - (Y)es or (N)o - ";
    $trash = <STDIN>;
    chomp $trash;
    $trash = ("\U$trash\E");
    if ($trash eq "Y"){@remove = ("$fnext[0].spl", "$fnext[0].shd", @remove);}
    }
   }
  }
 if (@remove > 0)
  {
  unless (Win32::Service::GetStatus( "\\\\$server",'Spooler', \%status))
   {
   print "Unable to check spooler status on $server\n";
   next;
   }
  if ($status{CurrentState} == 4)
   {
   print "Spooler on $server is running, attempting to stop\n";
   unless (Win32::Service::StopService("\\\\$server",'Spooler'))
    {
    print "Unable to stop spooler on $server\n";
    next;
    }
   sleep(2);
   }
  unless (Win32::Service::GetStatus( "\\\\$server",'Spooler', \%status))
   {
   print "Unable to check spooler status on $server\n";
   next;
   }
  if ($status{CurrentState} == 1)
   {
   print "Spooler on $server is stopped, deleting files\n";
   foreach $fname (@remove){unlink ("$spldir\\$fname");}
   unlink <$spldir\\*.tmp>;
   unless (Win32::Service::StartService("\\\\$server",'Spooler'))
    {
    print "StartService attempt for Spooler service on $server failed\n";
    next;
    }
   sleep(2);
   unless (Win32::Service::GetStatus( "\\\\$server",'Spooler', \%status))
    {
    print "GetStatus attempt for Spooler service on $server failed\n";
    next;
    }
   if ($status{CurrentState} ne 4)
    {
    print "Spooler service is not running on $server\n";
    next;
    }
   if ($status{CurrentState} eq 4){print "Spooler is running on $server\n";}
   }
  }
 }

sub procprt
 {
 my ($data1, $o1, $pname, $d1, $d2, $hexd1, $hexd2) = "";
 my $file = shift;
 open(SHDFILE, "<$file") || return();
 binmode SHDFILE;
 $data1 = do {local $/;<SHDFILE>};
 close SHDFILE;
 @bytes = split //,$data1;
 $o1 = 108;
 $pname = "";
 while (1)
  {
  $d1 = $bytes[$o1];
  $d2 = $bytes[$o1 + 1];
  $o1++;
  $hexd1 = unpack("H*", $d1);
  $hexd2 = unpack("H*", $d2);
  if ($hexd1 ne "00"){$pname = ("$pname$d1");}
  if (($hexd1 eq "00") and ($hexd2 eq "00")) {return($pname);}
  }
 }

sub procusr
 {
 my ($o2, $uname, $d3, $d4, $hexd3, $hexd4) = "";
 $o2 = 16;
 $d3 = $bytes[$o2];
 $d4 = $bytes[$o2 + 1];
 $hexd3 = unpack("H*", $d3);
 $hexd4 = unpack("H*", $d4);
 $o2 = ("$hexd4$hexd3");
 $o2 = hex ($o2);
 while (1)
  {
  $d3 = $bytes[$o2];
  $d4 = $bytes[$o2 + 1];
  $o2++;
  $hexd3 = unpack("H*", $d3);
  $hexd4 = unpack("H*", $d4);
  if ($hexd3 ne "00")
   {
   $uname = ("$uname$d3");
   }
  if (($hexd3 eq "00") and ($hexd4 eq "00"))
   {
   return($uname);
   }
  }
 }

sub getservers
 {
 my ($domain, $pdc, @servers, @servers1, @servers2, @servers3);
 unless ($domain = Win32::DomainName){ die "Couldn't determine domain";}
 unless (Win32::NetAdmin::GetDomainController("", $domain, $pdc)) {die "Unable to get PDC for $domain.";}
 unless (Win32::NetAdmin::GetServers($pdc, $domain, 0x00000008, \@servers1))
{print "Unable to read NetBios 0008.";}
 unless (Win32::NetAdmin::GetServers($pdc, $domain, 0x00000010, \@servers2))
{print "Unable to read NetBios 0010.";}
 unless (Win32::NetAdmin::GetServers($pdc, $domain, 0x00008000, \@servers3))
{print "Unable to read NetBios 8000.";}
 @servers = (@servers1, @servers2, @servers3);
 return(@servers);
}



