use Win32;

# This subroutine will display the error information

sub ErrorReport {print Win32::FormatMessage( Win32::GetLastError() );}


# Get a drive letter for connecting to the share

$Drive = Win32::GetNextAvailDrive();
system("NET USE $Drive \\\\SSBSRV1\\BENCHMAT");

# First determine which OS
# Then check for DLL already installed
# If DLL not present then copy to appropriate directory

$WinNT = Win32::IsWinNT();
if ($WinNT) {
	$NTdll = "C:\\WINNT\\SYSTEM32\\PERLCRT.DLL";
	if (-e $NTdll) {
		print "Working ...";
	} else {
		system("COPY $Drive\\PERLCRT.DLL C:\\WINNT\\SYSTEM32\\PERLCRT.DLL");
	}
}

$Win95 = Win32::IsWin95();
if ($Win95) {
	$W95dll = "C:\\WINDOWS\\SYSTEM\\PERLCRT.DLL";
	if (-e $W95dll) {
		print "Working ...";
	} else {
		system("COPY $Drive\\PERLCRT.DLL C:\\WINDOWS\\SYSTEM\\PERLCRT.DLL");
	}
}


# Run the application from the server

use Win32::Process;
Win32::Process::Create($ProcessObj,
	"$Drive\\BMPROG\\BMATE.EXE",
	"BMATE",
	0,
	CREATE_SEPARATE_WOW_VDM,
	"$Drive\\BMDATA");


$ProcessObj->Suspend();
$ProcessObj->Resume();
$ProcessObj->Wait(INFINITE);


# Disconnect from the share

system("NET USE $Drive /DEL");

