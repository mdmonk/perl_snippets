#!/usr/local/bin/perl
###################################################
# scott.pl
# - simple DBD::Oracle example.
# - 1 Aug 2000: CWL
###################################################
use DBI; 

#$ENV{ORACLE_HOME} = '/opt/home/oracle/product/8.0.5';

print "Content-type: text/plain\n\n"; 

#$dbh = DBI->connect("dbi:Oracle:host=milo.ip.qwest.net;sid=Router", "router", "router") || die $DBI::errstr;
$dbh = DBI->connect("dbi:Pg:dbname=Router", "postgres", "p0stgr3s") || die $DBI::errstr;

#$stmt = $dbh->prepare("SELECT * FROM Cisco_Interface_Data") || die $DBI::errstr; 
$stmt = $dbh->prepare("SELECT * FROM Cisco_Base") || die $DBI::errstr; 
$rc = $stmt->execute() || die $DBI::errstr;

$tmp2 = $stmt->{NAME};

foreach (@{$tmp2}) {
  print "tmp2 array contains: $_\n";
} # end foreach

$nfields = $stmt->rows();
print "Query will return $nfields fields\n\n";
while (@tmp = $stmt->fetchrow()) { print "@tmp\n"; }

warn $DBI::errstr if $DBI::err;
die "fetch error: " . $DBI::errstr if $DBI::err;
$stmt->finish() || die "can't close cursor";
$dbh->disconnect() || die "can't log off Oracle";
