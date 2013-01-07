#!c:\perl\bin\perl.exe
###############################################################
#
# Example 3.16 in the Win32 Extensions book.
#  - Apparently there were mistakes in the
#    original ver in the book.
#
# Date: 26 Feb 1999
#
###############################################################
use Win32::Registry;

if( $HKEY_LOCAL_MACHINE->Open("Software\\ActiveState", $Key)){
	ProcessKey($Key);
	$Key->Close();
}

sub ProcessKey{
	# This was "my $Key = $_;"
	my $Key = $_[0];
	my ($SubKeyName, $SubKey, @KeyList);
	my ($Value, $ValueList, %Values);
	
	# This was "$Key->GetValues(%Values);"
	$Key->GetValues(\%Values);
	
	foreach $Value (sort keys %ValueList){
		print "$Value = $ValueList{$Value}[2]\n";
	}
	
	$Key->GetKeys(\@KeyList);
	
	foreach $SubKeyName (sort @KeyList){
		if($Key->Open($SubKeyName, $SubKey)){
			print "Processing key: $SubKeyName:\n";
			ProcessKey($SubKey);
			$SubKey->Close();
		}
	}
# This closing brace was not present
}
