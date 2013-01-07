print "Win32 perl attempt at a Netfinity Interface\n";
$x=0;
@lines=system("d:\\apps\\wnetfin\\nfsysicl /rpt:\"C:\\TEMP\\W95.RPT\"");
open(RPTIN,"<C:\\TEMP\\W95.RPT") || die "Cannot open input file: $!";
open(RPTOUT,">c:\\temp\\report.out") || die "Cannot open output file: $!";
while(<RPTIN>) {
  if($_ =~ /^\*\*\*\*\*\*\*\*\*\*\* Operating System Information/) {
    $x=1;

  }
  if($x==1 && $_ =~ /^\*\*\*\*\*\*\*\*\*\*\* Task List/) {
    $x=0;
  }
  if($x==1) {
    print RPTOUT $_;
  }

  if($_ =~ /^System Serial Number/) {
    print RPTOUT $_;
  }
}
close(RPTIN);
close(RPTOUT);
# system("del c:\\temp\\w95.rpt");
