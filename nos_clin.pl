################################################################
#  Use command line options.
#  Must use "perl -s" to be able to pass command line
#    options to a script.
################################################################
#  This program prints information as specified by
#  the following options:
#    -L: print Login name
#    -D: print Domain name
#    -N: print Node name
#    -F: print File System Type
#  -all: print everything (overrides other options.

$L = $D = $N = $F = 1 if ($all);
($login_name, $domain_name, $node_name, $fs_type) = GetInfo ($L, $D, $N, $F);

print "Login Name:       $login_name\n";
print "Domain Name:      $domain_name\n";
print "Node Name:        $node_name\n";
print "File System Type: $fs_type\n";

sub GetInfo {
  my($l, $d, $n, $f) = @_;
  my @result;
  $result[0] = &NTLoginName if $l;
  $result[1] = &NTDomainName if $d;
  $result[2] = &NTNodeName if $n;
  $result[3] = &NTFsType if $f;
  return @result;
}
