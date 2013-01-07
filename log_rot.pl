$hostname='t004b67';
$LOGPATH='c:\\usr\\OV\\log\\OpC\\'.$hostname;
@LOGNAMES=('one.log');
$MAXCYCLE = 5;
$CURDIR = `pwd`;

chdir $LOGPATH;  # Change to the log directory
$tmp = `pwd`;
print "Directory is: $tmp\n";
foreach $filename (@LOGNAMES) {
   for (my $s=$MAXCYCLE; $s--; $s >= 0 ) {
      $oldname = $s ? "$filename.$s" : $filename;
      $newname = join(".",$filename,$s+1);
      rename $oldname,$newname if -e $oldname;
   }
}
foreach $touchname (@LOGNAMES) {
  system("echo > $touchname");
}
$tmp2 = `cd $CURDIR`;
print "Directory is: $tmp2\n";
