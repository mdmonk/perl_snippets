#!/usr/local/bin/perl


#$ENV{'ORACLE_HOME'} = "/opt/home/oracle/product/8.0.5";

use DBI;

   #$dbh = DBI->connect("dbi:Oracle:host=milo.ip.qwest.net;sid=Router",
   #                    "router", "router") || die $DBI::errstr;
   $dbh = DBI->connect("dbi:Pg:dbname=Router",
                       "postgres", "p0stgr3s") || die $DBI::errstr;
   @tables = $dbh->tables;

    foreach my $line (sort @tables) {
      print "Table: $line\n";

      my $sth = $dbh->prepare("SHOW COLUMNS FROM $line");
      $sth->execute();
      if ($sth->rows > 0) {
        while (my $row = $sth->fetchrow) {
          print "Table $line: $row[0]\n";
        }
      }
      print "\n";
    }

    print "done.\n";
    $dbh->disconnect;

