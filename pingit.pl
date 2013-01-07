use Net::Ping;

$host = $ARGV[0];
chomp($host);
$p = Net::Ping->new();
print "host is alive.\n" if $p->ping($host);
$p->close();

$p = Net::Ping->new("icmp");

  print "$host is ";
  print "NOT " unless $p->ping($host, 2);
  print "reachable.\n";

$p->close();
