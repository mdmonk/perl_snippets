#######################################################
# Perl use of "simifmak" to extract hard drive        #
# serial numbers, and memory table.                   #
#######################################################
print "Win32 perl attempt at using simifmak on the Netfinity...\n";
$x=0;
$remcmd="c:\\netfin\\simifmak system.mft c:\\temp\\cwl.mif";
@lines=system("c:\\netfin\\simifmak c:\\netfin\\system.mft f:\\iss\\khth00b1.mif");
open(MIFIN,"<f:\\iss\\khth00b1.mif") || die "Cannot open input file: $!";
open(MIFOUT,">f:\\iss\\mif.out") || die "Cannot open output file: $!";
while(<MIFIN>) {
  if($_ =~ /Name = \"Physical Memory Table\"/) {
    print "\n";
    $x=1;
  }
  
  if($_ =~ /Name = \"Disk Drives Table\"/) {
    print "\n";
    $x=1;
  }

  if($_ =~ /End Table/) {
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
