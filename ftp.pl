print "Win32 perl attempt at a Netfinity Interface\n";
$x=0;
# system("nfproccl /runcmd:\"simifmak c:\\netfin\\system.mft f:\\iss\\temp_cwl.mif\" /s:\"AGT02LAB\"");
system("cd c:\\temp");
system("ftp agt02lab");
system("custom\n");
system("cutsom\n");
system("ls");
system("quit");

# open(RPTIN,"<C:\\TEMP\\NFRSYSCL.RPT") || die "Cannot open input file: $!";
# open(RPTOUT,">c:\\temp\\report.out") || die "Cannot open output file: $!";
# while(<RPTIN>) {
#  if($_ =~ /^\*\*\*\*\*\*\*\*\*\*\* Operating System Information/) {
#    $x=1;
#
#  }
#  if($x==1 && $_ =~ /^\*\*\*\*\*\*\*\*\*\*\* Task List/) {
#    $x=0;
#  }
#  if($x==1) {
#    print RPTOUT $_;
#  }
#
#  if($_ =~ /^System Serial Number/) {
#    print RPTOUT $_;
#  }
# }
# close(RPTIN);
# close(RPTOUT);
