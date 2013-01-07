# Test perl pgm.

use Win32;

$user = Win32::LoginName();
$node = Win32::NodeName();
$tick = Win32::GetTickCount();
$cwd = Win32::GetCwd();
($tick2) = (($tick/1000)/60);

print "User name is:     $user\n";
print "Node name is:     $node\n";
print "CWD is:           $cwd\n";
print "Tick Count is:    $tick\n";
printf ("Minutes Count is: %.2f\n", $tick2);
