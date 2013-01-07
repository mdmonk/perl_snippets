#######################################################
# Perl use of "simifmak" to extract hard drive        #
# serial numbers.                                     #
#######################################################
print "Win32 perl attempt at using simifmak...\n";
$x=0;
# $remcmd="c:\\netfin\\simifmak system.mft c:\\temp\\cwl.mif";
# @lines=system("d:\\apps\\wnetfin\\simifmak system.mft c:\\temp\\cwl.mif");
open(MIFIN,"<c:\\temp\\khth00b1.mif") || die "Cannot open input file: $!";
open(MIFOUT,">c:\\temp\\mif.out") || die "Cannot open output file: $!";
while(<MIFIN>) {
  if($_ =~ /Name = \"Physical Memory Table\"/) {
    $x=1;
  }
  
  if($_ =~ /Name = \"Disk Drives Table\"/) {
    $x=1;
  }

  if($_ =~ /End Table/) {
     print MIFOUT "\n";
     $x=0;
  }

  if($x==1) {
    print MIFOUT $_;
  }

  if($_ =~ /System Serial Number/) {
    print MIFOUT $_;
  }

}
close(MIFIN);
close(MIFOUT);
