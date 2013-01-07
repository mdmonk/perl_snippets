###########################################
# Script name: getIP.pl
# Desc: This function gets the IP
#       of the local machine.
#       More dependable than other
#       methods.
###########################################

$name = (gethostbyname ("localhost"))[0];
$paddr = gethostbyname ($name);
$addr = join (".", unpack ('C4', $paddr));
$fqdn = gethostbyaddr ($paddr, 2) || 'Unknown';
print "$name=$fqdn=$addr=" . a2h($addr) . "\n";


sub a2h { 
	my @hex = ();
    @hex = unpack('H*', shift) =~ /(..)/g;  
	return (wantarray) ? @hex : join(",",@hex);
}

