########################################################################
#
# SMOG.PL
#
########################################################################
# Finds the servers and workstations in the domain of the machine 
# run on, then gathers information on each machine and logs it.
#
# saves the output to $machine_name.txt. The SMOG 
# files are in a directory based on the date (if it does not exist then 
# it is created) and checks that the machine is accessible before 
# creating the SMOG. 
# (Cannot find a machine if it is not in the domain!)
#
# SMOG files contain the Domain Controller, details of the event log,
# registry entries detailing the network name, NIC, Service Pack level, 
# Network load order and Sophos Anti-virus version and a list of the 
# *active* services.
#
########################################################################
# SMOG.pl is a Perl script for creating System Management and Operation Guides
# interactively for the NT servers (and workstations). The interactive data
# written to the screen is also written to a LOGFILE 
# (\SMOGS\$monthname\$monthname$dayno.txt). (With the exception of system
# error messages which only appear on the screen).
# Summary information is written the the directory (\SMOGS\$monthname\$dayno\Summary).
#
# On completion an event is written to the local event log.
# For the SMOG we want details on the machine's TCP/IP address,
# memory, OS version and Service Pack level, disk configuration and shares.
# We also want information on the domain groups and accounts. What has been
# added, changes to the administration users and groups, and suspicious
# events in the PDC's security log.
#
# It would also be nice to be given comparative information on disk space, 
# memory, processors etc, as well as estimated time before servers run out of
# resources.
#
# As yet - unable to get information on :-
# Memory
# Disk Partitions and free space
#
# The include file is the perl header (.ph) file which contains
# the NT registry macro definitions.
#
use Win32;
use Win32::File;
use Win32::AdminMisc;
use Win32::Registry;
use Net::Ping;
########################################################################
#
# VARIABLES
#
########################################################################
#
# Define variables to make the script more readable
#
@Computers = undef; # Array of NT Servers and NT Workstations to get values from
$PrevValue = "";
# WARNING WARNING if hide_ws is 'true' then this script will hide all 
# workstations in your domain!
###
## $hide_ws = 1 ;
###
$hide_ws = 0 ;

########################################################################
# SUBROUTINES
########################################################################
# 1. hkey_local_read
# 2. opensmogfile
# 3. smogheader
# 4. smog
# 5. logdata
# 6. getregistryinfo
# 7. getservicesinfo
# 8. getevntloginfo
# 9. closefiles
# 10. openoutputfiles
# 11. getdomaininfo
# 12. getdate
# 13. CheckFilesExist
# 14. writefileheaders
# 15. AppendToFiles
# 16. readinputfile
# 17. machineup
# 18. smogdone
########################################################################
# 1. Subroutine to read a value from the HKEY_LOCAL_MACHINE hive.
########################################################################
sub hkey_local_read { 
Win32::Registry::RegConnectRegistry($ntsntw,&HKEY_LOCAL_MACHINE,$RegHandle);
# complains about $RegKey not being numeric, I can't see why it should be.
Win32::Registry::RegOpenKeyEx($RegHandle,$RegKey,&NULL,&KEY_QUERY_VALUE,$KeyHandle);
Win32::Registry::RegQueryValueEx($KeyHandle,$RegValue,&NULL,$Type,$ReturnValue);
Win32::Registry::RegCloseKey($KeyHandle);
return $ReturnValue;
}
########################################################################
# 2. Open output SMOG file -or- abort the script.
########################################################################
sub opensmogfile {
open(SMOGFILE, ">$DirName\\$ntsntw.txt") || 
die "Unable to open output file $ntsntw.txt";
}
########################################################################
# 3. Print header to output file.
########################################################################
sub smogheader {
print SMOGFILE "\n\tNT SMOG - Interactive Report\t($ntsntw)\t$date\n";
print SMOGFILE "\t======= ==================\n\n";
}
########################################################################
# 4. Subroutine to generate the SMOG. Reads details from the registry 
# and writes them to the SMOG file (machine_name.txt).
########################################################################
sub smog {
logdata($ntsntw); # Print the name of the current machine

if (machineup()) { # Generate the SMOG
opensmogfile(); # Open the SMOG file.
smogheader(); # Write the header information

getdomaininfo(); # Get information on Domain Controller
getevntloginfo(); # Get information on the Event Log.
getregistryinfo(); # Get the Registry information
getservicesinfo(); # Get information on Services
getshareinfo(); # Get the details of shares
if ($hide_ws) {
# commented this out...CWL
print "In hide ws check...Moving on...\n";
# hide_workstation(); # Remove a ws from appearing in net neigh
}

logdata("\n"); 
close(SMOGFILE); # Close the SMOG file.
} else { # Machine not available
$ntsntw =~ tr/a-z/A-Z/; print DOWNFILE "\t$ntsntw\n";
logdata(" - Not available\n"); 
}
}
########################################################################
# 5. Subroutine to write data to the LOGFILE and the screen.
########################################################################
sub logdata {
$mydata = shift; 
print LOGFILE "$mydata"; print "$mydata";
}
########################################################################
# 6. Subroutine to get the information from the registry.
########################################################################
# local %digits = (%digits, 't' => 10, 'e' => 11);
#
sub getregistryinfo {
$RegKey = undef; # Registry Key that contains the value
$RegValue = undef; # Registry value we want to retrieve

$SPValue = undef; $NICValue = undef; $NTlocValue = undef;
$UserNameValue= undef; $CoNameValue= undef; $ProdValue= undef;
$SweepValue= undef; $InterCheck= undef; $NTnameValue= undef; 
$NetLoadValue= undef; $PathValue= undef; $PageValue= undef; $TZValue= undef;

logdata(" Registry "); # Entering the routine
print SMOGFILE "Registry Settings\t\tValue\n=================\t\t-----\n";

# TCP/IP Hostname
$PrevName=$TCPnameValue;
print SMOGFILE "TCP IP Hostname \t\t $TCPnameValue\n"; 

# NT Computer Name
$RegKey='SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName'; 
$RegValue='ComputerName';
$NTnameValue = hkey_local_read ($RegKey,$RegValue);
if ($NTnameValue eq $PrevValue) {$NTnameValue = '-BLANK-';} 
print SMOGFILE "NT Computer Name\t$NTnameValue\n"; 

# Patch level
$RegKey='SOFTWARE\Microsoft\Windows NT\CurrentVersion'; $RegValue='CSDVersion';
$SPValue = hkey_local_read ($RegKey,$RegValue);
if ($SPValue eq $PrevValue) {$SPValue = '-UNKNOWN-';} 
print SMOGFILE "Patch level\t\t$SPValue\n"; 
print SERVICEPACKLEVEL "$ntsntw\t\t$SPValue\n"; # Keep details in a file

# User Name
$RegKey='SOFTWARE\Microsoft\Windows NT\CurrentVersion'; $RegValue='RegisteredOwner';
$UserNameValue = hkey_local_read ($RegKey,$RegValue);
if ($UserNameValue eq $PrevValue) {$UserNameValue = '-BLANK-';} 
print SMOGFILE "User Name\t\t$UserNameValue\n"; $PrevValue=$UserNameValue;
print REGISTEREDUSER "$ntsntw\t\t$UserNameValue\n"; # Keep details in a file

# Company Name
$RegKey='SOFTWARE\Microsoft\Windows NT\CurrentVersion'; 
$RegValue='RegisteredOrganization'; $CoNameValue = hkey_local_read ($RegKey,$RegValue);
if ($CoNameValue eq '') {$CoNameValue='- Blank -';}
print SMOGFILE "Company Name\t\t$CoNameValue\n"; $PrevValue=$CoNameValue; 
print REGISTEREDUSER "\t\t$CoNameValue\n\n"; # Keep details in a file

# Product ID
$RegKey='SOFTWARE\Microsoft\Windows NT\CurrentVersion'; $RegValue='ProductId';
$ProdValue = hkey_local_read ($RegKey,$RegValue);
if ($ProdValue eq $PrevValue) {$ProdValue = '-BLANK-';} 
print SMOGFILE "Product Id\t\t$ProdValue\n"; $PrevValue=$ProdValue;
print PRODUCTID "$ntsntw\t\t$ProdValue\n"; # Keep details in a file

# Network Card
$RegKey='SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkCards\1'; 
$RegValue='Title'; $NICValue = hkey_local_read ($RegKey,$RegValue); $PrevValue=$NICValue;
print SMOGFILE "Network Card\t\t$NICValue\n"; 

# Network Load Order
$RegKey='SYSTEM\CurrentControlSet\Control\ServiceProvider\Order'; 
$RegValue='ProviderOrder'; $NetLoadValue = hkey_local_read ($RegKey,$RegValue);
$NetLoadValue =~ tr/a-zA-Z/ /cs; # Eliminate control characters
print SMOGFILE "Network Load Order\t$NetLoadValue\n";

# NT Location
$RegKey='SOFTWARE\Microsoft\Windows NT\CurrentVersion'; $RegValue='PathName';
$NTlocValue = hkey_local_read ($RegKey,$RegValue); $PrevValue=$NTlocValue;
print SMOGFILE "NT Path\t\t\t$NTlocValue\n"; 

# Default Path
$RegKey='SYSTEM\CurrentControlSet\Control\Session Manager\Environment'; 
$RegValue='Path'; $PathValue = hkey_local_read ($RegKey,$RegValue);
if ($PathValue eq $PrevValue) {$PathValue = '-BLANK-';} else {$PrevValue=$PathValue;}
print SMOGFILE "Path\t\t\t$PathValue\n"; 

# Paging Files
$RegKey='SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'; 
$RegValue='PagingFiles'; $PageValue=hkey_local_read ($RegKey,$RegValue);
if ($PageValue eq $PrevValue) {$PageValue = 'BLANK';} else {$PrevValue=$PageValue;}
print SMOGFILE "Paging (size) (max)\t$PageValue\n"; 

# Anti-virus Version
$RegKey='SOFTWARE\Sophos\SweepNT'; $RegValue='Version';
$SweepValue = hkey_local_read ($RegKey,$RegValue);
if ($SweepValue eq $PrevValue) {$SweepValue = '** NONE';} else {$PrevValue=$SweepValue;}
$SweepValue =~ s/ //g ;
print SMOGFILE "Sweep Version\t\t$SweepValue\n"; 
print ANTIVIRUS "$ntsntw\t\t$SweepValue"; # Keep details in a file

# Browser set?
$RegKey='SYSTEM\CurrentControlSet\Services\Browser\Parameters'; $RegValue='MaintainServerList';
$BrowserValue = hkey_local_read ($RegKey,$RegValue);
if ($BrowserValue eq $PrevValue) {$BrowserValue = '** UNKNOWN';} else {$PrevValue=$BrowserValue;}
print SMOGFILE "Browser Setting\t\t$BrowserValue\n"; 

# InterCheck Client?
$RegKey='SOFTWARE\Sophos\SweepNT'; 
$RegValue='InterCheckClient'; 
$ICValue = hkey_local_read ($RegKey,$RegValue);
# print "\n\t$ICValue\n";
# logdata("$ICValue");
if ($ICValue == 1) {
$InterCheck='Yes';} 
else {if ($SweepValue eq '** NONE') {
$InterCheck='N/A';}
else {$InterCheck='* No *';}
}
print SMOGFILE "InterCheck Client\t$InterCheck\n"; 
print ANTIVIRUS "\t\t$InterCheck\n"; # Keep details in a file

# Time Zone
$RegKey='SYSTEM\CurrentControlSet\Control\TimeZoneInformation'; 
$RegValue='DaylightName'; $TZValue = hkey_local_read ($RegKey,$RegValue);
if ($TZValue eq $PrevValue) {$TZValue = '-BLANK-';}
print SMOGFILE "Time Zone\t\t$TZValue\n\n"; 
}
########################################################################
# 7. Subroutine to get information on SERVICES and write the data to the 
# SMOG file.
########################################################################
sub getservicesinfo {
use Win32::Service;
#
# Reset variables
%list=();$key=();
logdata(" Services "); # Entering the routine

# Put the header in the SMOG file
print SMOGFILE "\nService Name\t\t\tDisplay Name (Active SERVICES)";
print SMOGFILE "\n============\t\t\t------------ ---------------\n";

# Get the list of services. If the CurrentState of the service is 'Started' then
# put the information in the SMOG file.
Win32::Service::GetServices($ntsntw, \%list);
foreach $key (keys %list) {
Win32::Service::GetStatus($ntsntw, $list{$key}, \%status);
if ($status{'CurrentState'} == 4) { 
print SMOGFILE "$list{$key} \t\t=\t$key\n"; 
} 
}
}
########################################################################
# 8. Subroutine to get information on the EVENT LOG and write to the SMOG file.
########################################################################
sub getevntloginfo {
use Win32::Eventlog;
logdata(" Eventlog "); # Entering the routine

# Put the header in the SMOG file
print SMOGFILE "\nEvent Logs\n==========\n";

if (Win32::EventLog::Open($EventLog , "System", $ntsntw))
{
if ($EventLog->GetNumber($number))
{ 
print SMOGFILE "There are $number records in the System Event Log\n";

Win32::EventLog::Open($EventLog , "Application", $ntsntw) || die $!;
$EventLog->GetNumber($number) || die $!;
print SMOGFILE "There are $number records in the Application Event Log\n\n\n";
}
else
{
print SMOGFILE "Unable to count the number of entries in the eventlog\n"
}
}
else
{
print SMOGFILE "Unable to open the registry, Win95?\n";
}
}
########################################################################
# 9. Subroutine to close the output files (with the exception of the SMOGs).
########################################################################
sub closefiles {
close(SERVICEPACKLEVEL); # Close the SERVICEPACKLEVEL file.
close(REGISTEREDUSER); # Close the REGISTEREDUSER file.
close(PRODUCTID); # Close the PRODUCTID file.
close(ANTIVIRUS); # Close the ANTIVIRUS file. 
close(DOWNFILE); # Close the DOWNFILE file.
close(LOGFILE); # Close the LOGFILE file.
}
########################################################################
# 10. Subroutine to open the output files (with the exception of the SMOGs).
########################################################################
sub openoutputfiles {
CheckFilesExist(); # Check to see if the files already exist.

# Open output files -or- abort the script.
#
if ($FileExists == 0) {
open(SERVICEPACKLEVEL, ">$SummaryLocation\\SPLEVEL.txt") || 
die "Unable to open output file SPLEVEL.txt";
open(REGISTEREDUSER, ">$SummaryLocation\\REGUSER.txt") || 
die "Unable to open output file REGUSER.txt";
open(PRODUCTID, ">$SummaryLocation\\PRODID.txt") || 
die "Unable to open output file PRODID.txt";
open(ANTIVIRUS, ">$SummaryLocation\\AV.txt") || 
die "Unable to open output file AV.txt"; 
open(DOWNFILE, ">$SummaryLocation\\DOWNFILE.txt") || 
die "Unable to open output file DOWNFILE.txt";
open(HIDDENFILE, ">$SummaryLocation\\HIDDEN.txt") || 
die "Unable to open output file HIDDEN.txt";
open(LOGFILE, ">$FileLocation\\$monthname$dayno.txt") || 
die "Unable to open output file LOGFILE"; 
writefileheaders();}
else {
open(SERVICEPACKLEVEL, ">>$SummaryLocation\\SPLEVEL.txt") || 
die "Unable to open output file SPLEVEL.txt";
open(REGISTEREDUSER, ">>$SummaryLocation\\REGUSER.txt") || 
die "Unable to open output file REGUSER.txt";
open(PRODUCTID, ">>$SummaryLocation\\PRODID.txt") || 
die "Unable to open output file PRODID.txt";
open(ANTIVIRUS, ">>$SummaryLocation\\AV.txt") || 
die "Unable to open output file AV.txt"; 
open(DOWNFILE, ">>$SummaryLocation\\DOWNFILE.txt") || 
die "Unable to open output file DOWNFILE.txt";
open(HIDDENFILE, ">>$SummaryLocation\\HIDDEN.txt") || 
die "Unable to open output file HIDDEN.txt";
open(LOGFILE, ">>$FileLocation\\$monthname$dayno.txt") || 
die "Unable to open output file LOGFILE"; 
AppendToFiles(); print LOGFILE "\n";}
}
########################################################################
# 11. Subroutine to get information on the Domain Controller for the computer.
########################################################################
sub getdomaininfo {
use Win32::NetAdmin;
logdata(" DomainInfo "); # Entering the routine
Win32::NetAdmin::GetDomainController($ntsntw,'OPTRONICS',$PDCName);
if ($PDCName eq '') {$PDCName = '-* NONE *-';}
print SMOGFILE "\nDomain Controller\t$PDCName\n\n"; 
}
########################################################################
# 12. Subroutine to get the date for the SMOG file. Ensure the directory exists.
########################################################################
sub getdate { 
($sec, $min, $hour, $dayno, $monthno, $year) = localtime(time);
@month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec');
$monthname = $month[$monthno]; 

$date = "$monthname $dayno 19$year $hour:$min"; 
if ($min < 10) {$time = "$hour:0$min";}
else {$time = "$hour:$min";}
}
########################################################################
# 13. Subroutine to get ensure the directory exists for SMOG files and see 
# if the files are already there.
########################################################################
sub CheckFilesExist {
# Ensure that the smog directory exists. If not then create it. 
# Sets $FileExists to 1 if the output file 
# $monthno$dayno.txt exists, 0 otherwise
my $domainName = Win32::DomainName();
$BaseDir = "\\smogs";
my $domainDir = "$BaseDir\\$domainName";
my $yearDir = "$domainDir\\19$year";
$FileLocation = "$yearDir\\$monthname"; 
$DirName = "$FileLocation\\$dayno"; 
$SummaryLocation = "$DirName\\Summary";
$File = "$FileLocation\\$monthno$dayno.txt";
if (-e $BaseDir)
{
if ( -e $domainDir)
{
if (-e $yearDir)
{
if (-e $FileLocation)
{
if (-e $DirName)
{
if (-e $SummaryLocation)
{
if (-e $File)
{
$FileExists = 1;
}
else
{
$FileExists = 0;
}
}
else
{
$FileExists = 0;
mkdir($SummaryLocation, 0777) || die "cannot create $SummaryLocation $!";
}
}
else
{
$FileExists = 0;
mkdir($DirName, 0777) || die "cannot create $DirName: $!";
mkdir($SummaryLocation, 0777) || die "cannot create $SummaryLocation $!";
}
}
else
{
$FileExists = 0;
mkdir($FileLocation, 0777) || die "cannot create $FileLocation: $!";
mkdir($DirName, 0777) || die "cannot create $DirName: $!";
mkdir($SummaryLocation, 0777) || die "cannot create $SummaryLocation $!";
}
}
else
{
# create the yearDir
$FileExists = 0;
mkdir($yearDir, 0777) || die "cannot create $yearDir: $!";
mkdir($FileLocation, 0777) || die "cannot create $FileLocation: $!";
mkdir($DirName, 0777) || die "cannot create $DirName: $!";
mkdir($SummaryLocation, 0777) || die "cannot create $SummaryLocation $!";
}
}
else
{
# create the domainDir
$FileExists = 0;
mkdir($domainDir, 0777) || die "cannot create $domainDir: $!";
mkdir($yearDir, 0777) || die "cannot create $yearDir: $!";
mkdir($FileLocation, 0777) || die "cannot create $FileLocation: $!";
mkdir($DirName, 0777) || die "cannot create $DirName: $!";
mkdir($SummaryLocation, 0777) || die "cannot create $SummaryLocation $!";
}
}
else
{
$FileExists = 0;
mkdir($BaseDir, 0777) || die "cannot create $BaseDir: $!";
mkdir($domainDir, 0777) || die "cannot create $domainDir: $!";
mkdir($yearDir, 0777) || die "cannot create $yearDir: $!";
mkdir($FileLocation, 0777) || die "cannot create $FileLocation: $!";
mkdir($DirName, 0777) || die "cannot create $DirName: $!";
mkdir($SummaryLocation, 0777) || die "cannot create $SummaryLocation $!";
}
}
########################################################################
# 14. Subroutine to write the headers into the output files (not SMOG files).
########################################################################
sub writefileheaders {
print SERVICEPACKLEVEL "\n\tNT SMOG - Interactive Report\t$date";
print SERVICEPACKLEVEL "\n\t======= - ==================\n\n";
print SERVICEPACKLEVEL "Computer\tService Pack\n--------\t------------\n";

print REGISTEREDUSER "\n\tNT SMOG - Interactive Report\t$date";
print REGISTEREDUSER "\n\t======= - ==================\n\n";
print REGISTEREDUSER "Computer\tRegistered User/Company\n--------\t-----------------------\n";

print PRODUCTID "\n\tNT SMOG - Interactive Report\t$date";
print PRODUCTID "\n\t======= - ==================\n\n";
print PRODUCTID "Computer\t Product ID\n--------\t ------------\n";

print ANTIVIRUS "\n\tNT SMOG - Interactive Report\t$date";
print ANTIVIRUS "\n\t======= - ==================\n\n";
print ANTIVIRUS "Computer\tSophos Version\tInterCheck client?\n";
print ANTIVIRUS "--------\t--------------\t------------------\n";

print DOWNFILE "\n\tNT SMOG - Interactive Report\t$date";
print DOWNFILE "\n\t======= - ==================\n\n";
print DOWNFILE "Computers not available\n-----------------------\n";

print HIDDENFILE "\n\tNT SMOG - Interactive Report\t$date";
print HIDDENFILE "\n\t======= - ==================\n\n";
print HIDDENFILE "Workstations hidden from Network Neighborhood\n-----------------------\n";
}
########################################################################
# 15. Subroutine to append to files. Do this by writing a line of dashes.
########################################################################
sub AppendToFiles { 
printf SERVICEPACKLEVEL "\n\t------------------------------\t$time\n\n";
print REGISTEREDUSER "\n\t------------------------------\t$time\n\n";
print PRODUCTID "\n\t------------------------------\t$time\n\n";
print ANTIVIRUS "\n\t------------------------------\t$time\n\n";
print DOWNFILE "\n\t------------------------------\t$time\n\n";
print HIDDENFILE "\n\t------------------------------\t$time\n\n";
}
########################################################################
# 17. Subroutine to determine if Server/Workstations is on. 
########################################################################
sub machineup {
if ($p->ping($ntsntw)) {
$RegKey='SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'; 
$RegValue='Hostname'; $TCPnameValue = hkey_local_read ($RegKey,$RegValue);
return 1;
} else {
return 0;
}
}
########################################################################
# 18. Subroutine to write an event to the event log. Completes the SMOG.
########################################################################
sub smogdone {
# open the event log and write an event to say "SMOG run"
Win32::EventLog::Open($EventLog , "SMOG", '') || die $!; # define the event to log.
$Event = {
'EventType' => EVENTLOG_INFORMATION_TYPE,
'Category' => $dayno,
'EventID' => 0x1004,
'Data' => 'SMOG',
'Strings' => "SMOG run",
};
$EventLog->Report($Event) || die $!; # report the event and check the error
}
########################################################################
# 19. Subroutine to extract all the shares configuration
########################################################################
sub getshareinfo {
my $i = 0;
my $RegHandle ;
my $ShareKey = "SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Shares";
my $KeyHandle ;
my $name ;
my $type ;
my $data ;
Win32::Registry::RegConnectRegistry($ntsntw, &HKEY_LOCAL_MACHINE,$RegHandle);
Win32::Registry::RegOpenKeyEx($RegHandle,$ShareKey,&NULL,&KEY_QUERY_VALUE,$KeyHandle);
while ( $result = Win32::Registry::RegEnumValue($KeyHandle,$i++,$name,NULL,$type,$data)) {
if ($i == 1) {
print SMOGFILE "\n\n\tShares configured\n\n=================\t\t-----\n";
logdata(" Shares ");
}
print SMOGFILE "$name\t$type\t$data\n";
}
}
########################################################################
# 21. Hide workstation from the network neighborhood
########################################################################
sub hide_workstation {
my $machine = $ntsntw;
if (is_ws($machine) && visible($machine)) { # if it's running and a wortstation
print HIDDENFILE "$machine is NTWS, hiding\n";
hide($machine); # modify the registry of the machine
# print "restarting the server service\n";
# restart_server($machine) # stop and restart the server service
} 
}
########################################################################
# 22. check to see if it is a workstation
########################################################################
sub is_ws {
# read the registry of the remote machine to see
# what sort of nt it is.
my $RegHandle ; # used to store the registry handles
my $TypeKey = "SYSTEM\\CurrentControlSet\\Control\\ProductOptions";
my $KeyHandle ; # used to store the registry handles
my $NT_version = undef;
my $type ; # this isn't used in at all but is needed by QueryValueEx
my ($host) = @_;
if ($HKEY_LOCAL_MACHINE->Connect($host,$RegHandle)) { # open the hive
if ($RegHandle->Open($TypeKey, $KeyHandle)) { # open the key
if ($KeyHandle->QueryValueEx("ProductType",$type, $NT_version)) { # find the value
$KeyHandle->Close();
}
$RegHandle->Close();
}
$HKEY_LOCAL_MACHINE->Close();
}
return ($NT_version eq "WinNT");
}
########################################################################
# 23. check to see if it isn't already hidden
########################################################################
sub visible {
# read the registry of the remote machine to see
# if it's already hidden
my $RegHandle ; # used to store the registry handles
my $TypeKey = "SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Parameters";
my $KeyHandle ; # used to store the registry handles
my $hiddenValue = 0;
my $type ; # this isn't used in at all but is needed by QueryValueEx
my ($host) = @_;
if ($HKEY_LOCAL_MACHINE->Connect($host,$RegHandle)) { # open the hive
if ($RegHandle->Open($TypeKey, $KeyHandle)) { # open the key
if ($KeyHandle->QueryValueEx("hidden",$type, $hiddenValue)) { # find the value
$KeyHandle->Close();
}
$RegHandle->Close();
}
$HKEY_LOCAL_MACHINE->Close();
}
return ($hiddenValue != 1);
}
########################################################################
# 24. actually add the key and value to the registry
########################################################################
sub hide {
# add the hidden key to the registry to stop it appearing
# in the network neighbourhood
my $RegHandle ; # used to store the registry handles
my $LanmanKey = "SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Parameters";
my $KeyHandle ; # used to store the registry handles
my ($host) = @_;
if ($HKEY_LOCAL_MACHINE->Connect($host,$RegHandle)) {
if ($RegHandle->Open($LanmanKey, $KeyHandle)) {
# need to check that the key isn't already there
if ($KeyHandle->SetValueEx("hidden",undef,&REG_DWORD,1)) {
$KeyHandle->Close();
}
$RegHandle->Close();
}
$HKEY_LOCAL_MACHINE->Close();
}
logdata(" hiding ");
}
########################################################################
# PERL SCRIPT
########################################################################
#
# Algorythm:
#
# While computer in list do
# if machine is accessible then 
# open the SMOG file
# write the headings
# get SMOG details
# write them to the file
# close the file
#
getdate();
openoutputfiles();
$p = Net::Ping->new("icmp",2,64);
$DomCont = Win32::AdminMisc::GetPDC();

if (@ARGV > 0) { # The machine(s) to run SMOGs on are arguments.
while ($ntsntw = shift(@ARGV)) {
smog(); 
}
} else { 
# NT Servers 
# Let the user know what is happening
logdata("\nNT Servers "); 

# Let the user know what is happening
logdata("\nGenerating SMOG files:\n");
Win32::AdminMisc::GetMachines($DomCont, UF_SERVER_TRUST_ACCOUNT, \@Computers, "");

foreach $ntsntw (@Computers) {
$ntsntw =~ s/\W.*//;
smog(); # Generate the SMOG
}
################# NT Workstations ##################
# Let the user know what is happening
logdata("\n\nNT Workstations "); 

# Let the watcher know what is happening
logdata("\nGenerating SMOG files:\n");

Win32::AdminMisc::GetMachines($DomCont, UF_WORKSTATION_TRUST_ACCOUNT, \@Computers, "");
foreach $ntsntw (@Computers) {
$ntsntw =~ s/\W.*//;
$ntsntw =~ tr/a-z/A-Z/;
smog(); # Generate the SMOG
}
smogdone();
}
# Tidy up.
closefiles();
logdata("\n"); # Leave a blank line before the next command prompt.
