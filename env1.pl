$KEY = "MYTMP";
$VALUE = "d:\\tmp2";

#if (exists($ENV{$KEY})) {
#   print "Value is: $ENV{$KEY}\n";
#} else {
#   print "It doesn't exist.\n";
#}
#$ENV{$KEY} = "d:\\tmp2";
#while ( ($key,$value) = each %ENV ) {
#  print "$key => $value\n";
#}
#if (exists($ENV{$KEY})) {
#   print "Value is: $ENV{$KEY}\n";
#} else {
#   print "It doesn't exist.\n";
#}

$path1 = $ENV{"PATH"};
print "Orig path is:\n$path1\n\n";

# $ENV{"PATH"} ="$path1;$VALUE";
# $path2 = $ENV{"PATH"};
# print "Modified Path is:\n$path2\n\n";
$i = 1;
@paths = split(';', $ENV{"PATH"});
print "Path info is:\b@paths\n\n";
print "Path $i: $paths[$i]\n";
