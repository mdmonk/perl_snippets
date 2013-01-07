use Win32::API;

$SHGFI = new Win32::API("shell32", "SHGetFileInfo", [P, L, P, I, I], L);
$GBT = new Win32::API("kernel32", "GetBinaryType", [P, P], N);

if($ARGV[0]) {
    $type = ExeType($ARGV[0]);
    $type = "Don't know!" if not defined $type;
    print "$ARGV[0]: $type\n";
} else {
    print "Usage: perl exetype.pl exefile\n";
}

sub ExeType {
    my($file) = @_;
    my $result; 
    my $type = undef;
    if(Win32::IsWinNT) {
        my @typename = (
            "Win32 based application",
            "MS-DOS based application",
            "16-bit Windows based application",
            "PIF file that executes an MS-DOS based application",
            "POSIX based application",
            "16-bit OS/2 based application",
        );          
        my $typeindex = pack("L", 0);
        $result = $GBT->Call($file, $typeindex);        
        $type = $typename[unpack("L", $typeindex)] if $result;
    }
    if($SHGFI) {
        $result = $SHGFI->Call($file, 0, 0, 0, 0x2000);
        if($result) {
            $type .= ", " if $type;
            my $hi = $result >> 16;
            my $lo = $result & 0x0000FFFF;

            $type .= sprintf("%c%c", $lo & 0x00FF, $lo >> 8);
        
            if($hi) {
                $type .= sprintf(" %d.%02d", $hi >> 8, $hi & 0x00FF);
            }
        }
    }
    return $type;
}
