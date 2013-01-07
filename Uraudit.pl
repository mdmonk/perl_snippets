# Program name - URAUDIT.PL  written by Paul Popour 11/99
# Perl Win32 script tested with AS version 5.005_02
# Purpose - To report and record user rights on all servers in a domain

use Win32::AdminMisc;
use Win32::NetAdmin;
use Win32::Lanman;

unless ($domain = Win32::DomainName){die "Unable to obtain the domain
name";}
unless (Win32::NetAdmin::GetDomainController("", $domain, $pdc)){die "Unable
to obtain the PDC name for $domain.";}
unless (Win32::NetAdmin::GetServers($pdc, $domain, 0x00000008, \@DC))
{&logit("Unable to read NetBios 0008.");}
unless (Win32::NetAdmin::GetServers($pdc, $domain, 0x00008000, \@servers))
{&logit("Unable to read NetBios 8000.");}
for (@servers) { $srvname{$_} = 1 }

$adir = "C:\\TEMP\\AUDIT";
if (!-e "$adir"){mkdir ($adir, 0777)|| die "Unable to create $adir";}

@DCrights =(
SE_SERVICE_LOGON_NAME,
SE_BATCH_LOGON_NAME,
SE_AUDIT_NAME,
SE_CREATE_PERMANENT_NAME,
SE_MACHINE_ACCOUNT_NAME,
SE_TCB_NAME,);

@rights =(
SE_INTERACTIVE_LOGON_NAME,
SE_NETWORK_LOGON_NAME,
SE_BACKUP_NAME,
SE_CHANGE_NOTIFY_NAME,
SE_CREATE_PAGEFILE_NAME,
SE_DEBUG_NAME,
SE_INC_BASE_PRIORITY_NAME,
SE_INCREASE_QUOTA_NAME,
SE_LOAD_DRIVER_NAME,
SE_PROF_SINGLE_PROCESS_NAME,
SE_REMOTE_SHUTDOWN_NAME,
SE_RESTORE_NAME,
SE_SECURITY_NAME,
SE_SHUTDOWN_NAME,
SE_SYSTEM_ENVIRONMENT_NAME,
SE_SYSTEM_PROFILE_NAME,
SE_SYSTEMTIME_NAME,
SE_TAKE_OWNERSHIP_NAME,);

@A1 = split(/\\/, "$pdc");
$server = $A1[2];
print "Auditing the PDC - $server\n";
$output = "$adir\\$server.txt";
open(OUTFILE, ">$output") || die "Cannot open output file $output";
close OUTFILE;
unless (open(OUTFILE, ">>$output")){die ("Cannot open output file
$output");}
foreach $right (@DCrights){&cright($server, $right);}
foreach $right (@rights){&cright($server, $right);}
close OUTFILE;

foreach $server (@servers)
 {
 print "Auditing $server\n";
 $output = "$adir\\$server.txt";
 open(OUTFILE, ">$output") || die "Cannot open output file $output";
 close OUTFILE;
 unless (open(OUTFILE, ">>$output")){die ("Cannot open output file
$output");}
 foreach $right (@rights){&cright($server, $right);}
 close OUTFILE;
 }

sub cright
 {
 my ($server, $right) = @_;
 print OUTFILE "\n\n$server - $right\n\n";
 if(!Win32::Lanman::LsaEnumerateAccountsWithUserRight("\\\\$server", $right,
\@sids))
  {
  $error = Win32::Lanman::GetLastError();
  print OUTFILE "$server - Error: $error\n";
  return();
  }
 if(!Win32::Lanman::LsaLookupSids($server, \@sids, \@infos))
  {
  $error = Win32::Lanman::GetLastError();
  print OUTFILE "$server - Error: $error\n";
  return();
  }
 foreach $info (@infos)
  {
  if (${$info}{'use'} eq "2")
   {
   print OUTFILE "\n\t${$info}{'name'} Group (Global)\n\n";
   &global(${$info}{'domain'}, ${$info}{'name'}, "P");
   next;
   }
  elsif (${$info}{'use'} eq "4")
   {
   print OUTFILE "\n\t${$info}{'name'} Group (Local)\n\n";
   &lgroups($server, ${$info}{'name'});
   next;
   }
  elsif (${$info}{'use'} eq "1")
   {
   print OUTFILE "\t${$info}{'name'}";
   &getname(${$info}{'domain'}, ${$info}{'name'});
   next;
   }
  else
   {
   print OUTFILE "\n\t${$info}{'name'}\n\n";
   next;
   }
  print OUTFILE "\n";
  }
 }

sub global
 {
 my ($domain, $ggroup, $source) = @_;
 my ($PDC, @users);
 return if ($ggroup eq "Domain Users");
 unless (Win32::NetAdmin::GetDomainController("", $domain, $PDC))
  {
  print OUTFILE ("Unable to obtain the PDC name for $domain.\n");
  return();
  }
 if(!Win32::Lanman::NetGroupGetUsers("$PDC", $ggroup, \@users))
  {
  $error = Win32::Lanman::GetLastError();
  print OUTFILE "$server, $ggroup - Error: $error\n";
  return();
  }
 foreach $user (@users)
  {
  next if (${$user}{'name'} eq "");
  if ($source eq "P")
   {
   print OUTFILE "\t\t\t${$user}{'name'}";
   &getname($domain, ${$user}{'name'});
   }
  elsif ($source eq "L")
   {
   print OUTFILE "\t\t\t\t${$user}{'name'}";
   &getname($domain, ${$user}{'name'});
   }
  }
  print OUTFILE "\n";
 }

sub lgroups
 {
 my ($server, $lgroup) = @_;
 my (@users, @A1);
 if(!Win32::Lanman::NetLocalGroupGetMembers("\\\\$server", $lgroup,
\@users))
  {
  $error = Win32::Lanman::GetLastError();
  print OUTFILE "$server, $lgroup - Error: $error\n";
  return();
  }
 foreach $user (@users)
  {
  next if (${$user}{'domainandname'} eq "");
  @A1 = split (/\\/, ${$user}{'domainandname'});
  if (${$user}{'sidusage'} eq 2)
   {
   print OUTFILE "\n\t\t\t$A1[1] Group (Global)\n\n";
   &global($A1[0], $A1[1], "L");
   }
  else
   {
   print OUTFILE "\t\t\t$A1[1]";
   &getname($A1[0], $A1[1]);
   }
  }
 print OUTFILE "\n";
 }

sub getname
 {
 my ($domain, $user) = @_;
 my ($PDC, @Hash1, @luinfo);
 if ($srvname{$domain})
  {
  unless(Win32::Lanman::NetUserGetInfo("\\\\$domain", "$user", \%luinfo))
   {
   $error = Win32::Lanman::GetLastError();
   print OUTFILE "$server - Error: $error\n";
   return();
   }
  print OUTFILE "$luinfo{'full_name'}\n";
  return();
  }
 unless (Win32::NetAdmin::GetDomainController("", $domain, $PDC))
  {
  print OUTFILE ("Unable to obtain the PDC name for $domain.");
  return();
  }
 unless (Win32::AdminMisc::UserGetMiscAttributes("$PDC", "$user", \%Hash1))
  {
  print OUTFILE "Unable to obtain information on $user from $PDC\n";
  next;
  }
 print OUTFILE "  =  $Hash1{USER_FULL_NAME}\n";
}


