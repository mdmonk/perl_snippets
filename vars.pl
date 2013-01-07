$ver = $];
$archName = $ENV{PROCESSOR_ARCHITECTURE};
$chipName = $ENV{PROCESSOR_LEVEL} . $ENV{PROCESSOR_ARCHITECTURE};
$chipID   = $ENV{PROCESSOR_IDENTIFIER};

print "Perl Ver:     $ver\n";
print "Arch Name:    $archName\n";
print "Chip Name:    $chipName\n";
print "Chip ID:      $chipID\n";

#if ( -d "d:\\tmp" ) {
#   $success =`set MYTMP=d:\\tmp`;
#   @setAry = `set`;
#} else {
#   print "Check failed\n";
#}
#print "Set variables are:\n@setAry\n";

#$oldpath = $ENV{PATH};
#$ENV{PATH} = "d:\\data\\perl.tmp;" . $oldpath;
print "New Path is: $ENV{PATH};";

#system("runonce.bat");
