#!/usr/bin/perl
#
# ipreq.pl - perl script using DBI interface to keep track of requested IP
# addresses.
#
#
# $Id: ipreq.pl,v 1.2 2000/09/12 21:30:31 gregb Exp gregb $
#
########################################################################

## includes and directives
use DBD::Oracle;
use CGI;
use Socket;

#### Globals #####

## subnets here are all /24, and require the xxx.xxx.xxx format
my @subnets = ("216.111.66", "205.169.63");
my ($dbh, $sth, $rv, $rc);   ## database handle, statement handle, and return 
                        ## code for DB stuff
## database connection parameters
my $data_source = "dbi:Oracle:host=crash.ip.qwest.net;sid=ipeng";
my $username = "ipaddress";
my $dbpasswd = "hurtm3";
my $tablename = "addresses";

my $page;  ## CGI object

## e-mail addresses to use
# my $dns_admin = 'dns-admin@qwestip.net';
my $dns_admin = 'gbaumgar@qip.qwest.net';
# my $carbon_copy = 'applications@qip.qwest.net';
my $carbon_copy = '';
my $prob_email = 'applications@qip.qwest.net';

#### Constants ####

my $begin_ip = 1;
my $end_ip = 253;
my $tmpmail = "/tmp/ipadd-mail";

#### Environment ####
$ENV{'ORACLE_HOME'} = '/usr/local/oracle/app/oracle/product/8.1.6';


###### THE PROGRAM ######
main();

## End of Program ##  Perl is easy, isn't it?


#### Subroutines #####

#################################################################
## req_ip 
##
## This subroutine simply prints out the form to ask the user for
## e-mail and a list of addresses that they'd like to assign.
##
## globals:
##   $page CGI object.
##
#################################################################
sub req_ip
  {
    my $subnet = shift @_;
    my $myself = $page->self_url;

    ## basically just print the form for the user to enter the info
    ## about the names they want
    print $page->start_form(-method=>'POST',
				-action=>"$myself"
				);

    print "<br>Enter your e-mail address (must end in qwest.net or qwest.com):<br>\n";
    ## the size of this field matches the size of the DB field
    print $page->textfield(-name=>'email',
			   -size=>30,
			   -maxlength=>50);
    print "<br><br>Enter hostnames, one per line.  Assumes .ip.qwest.net if a FQDN is not given<br>\n";
    print "The script will attempt to allocate the number of hosts you enter.<br><br>\n";
    print "Please note the server may have to check many IP's, and it could take a while.<br><br>\n";
    print "Duplicate entries in this form will be ignored.<br>\n";
    print $page->textarea(-name=>'hostnames',
			  -rows=>15,
			  -columns=>50);
    print "<br><br>\n";
    $page->param(-name=>'actions',-value=>'got_info');
    print $page->hidden('actions','got_info');
    print $page->hidden('subnet',$page->param('subnet'));
    print $page->submit('submit','Proceed');
    print $page->endform;
  }


    
##############################################################
## get_ip
##
## This subroutine takes the input from req_ip, and an argument
## specifying the subnet to be acted upon, and tries to allocate
## IP addresses in that subnet.  It does a good amount of error
## checking on the input it's given to try and help head off any
## problems with assigning the IP's, involving querying DNS and
## the network.  It prints out what hsots it think should be 
## allocated to what IP's.
##
## globals:
##   $page CGI object
##   $sth, $rv, and $dbh database scalars and objects
##
###############################################################

sub get_ip
  {
    my $subnet = shift @_;
    my ($a, $b, $c) = split /\./, $subnet;
    my @row;
    my ($email, $date, $fqdn);
    my $prequery = "select fqdn from $tablename where octet_1=$a and octet_2=$b and octet_3=$c and octet_4=?";
    my $hostquery = "select email from $tablename where fqdn = ?";
    my $db_result;
    my $cur_ip;
    my $host;
    my @ips;
    my $i;
    my ($ip, $iaddr, $name, @nameparts, $fieldname);
    my %host_map;
    my ($hosts, $hosts_found);
    my %hosthash;   # this makes sure that entries are unique
    my (@names, @hostnames);
    my $myself = $page->self_url;
    my $url = $page->url;
    my ($result, @duphosts);  ## check for duplicate hosts

    ## check for valid e-mail
    $email = $page->param('email');
    if (!($email =~ /^[\w\.]+@[\w\.]*qwest\.(com|net)$/i)) 
	{print "<h2>Error:</h2><br>Valid-type Qwest e-mail address required.<br>\n";
	 ## allow the user to get back to main page
	 print "<br><hr><br>Return to <a href=\"$url\">IP Request Page</a><br>\n";
	 return;
       }
    

    print "<center><h3>Finding IP's......</h3></center>\n";

    ## get the hostnames
    @names = split /\n/, $page->param('hostnames');

    ## weed out null entries, tack on ip.qwest.net where appropriate
    foreach $host (@names)
      {
	## keys of the hash are the unique hosts
	if (!($host =~ /^\s+$/)) 
	  {
	    $host =~ s/\s+$//;  ## delete trailing whitespace
	    if (!($host =~ /\./)) {$host = "$host.ip.qwest.net";}
	    $hosthash{$host} = 1;
	  }
      }

    @hostnames = keys %hosthash;

    ## how many hosts?
    $hosts = $#hostnames + 1;
    $hosts_found = 0;

    ## prepare the ip query
    $sth = $dbh->prepare($prequery);

    ## try each of the IP's until $hosts are found that work.
    for ($cur_ip = $begin_ip; $cur_ip <= $end_ip; $cur_ip++)
      {
	$rv = $sth->execute($cur_ip);
	if (!(@row = $sth->fetchrow_array)) 
	  {
	    ## do a lookup on the host to check and see if it has
	    ## a name already assigned
	    $ip = "$a.$b.$c.$cur_ip";
	    $iaddr = inet_aton $ip;
	    $name = gethostbyaddr $iaddr, AF_INET;
	    
	    ## burn away the irrelevant domain - what's the hsotname?
	    @nameparts = split /\./, $name;
	    $name = shift @nameparts;

	    ## if DNS lookup returns something, and that something is not
	    ## a dhcp address, skip this one
	    if (!($name =~ /dhcp\d+/) && (length $name > 0)) { 
	      next;}

	    ## if we can ping this address skip it
	    $output=`/usr/sbin/ping $ip 1 2>/dev/null`;
	    if ($? == 0) {
	      next;}

	    push @ips, $ip;
	    $hosts_found++;
	  }
	if ($hosts_found >= $hosts) {
	  last;}
      }
    
    ## serious injury!  No more IP's!  Report to user and go back to first page
    if ($hosts_found < $hosts)
      {
	print "<h2>Error: There are not enough free IP's in the subnet you requested</h2>\n";
	print "<br>Please choose fewer hosts, or try a different subnet.<br>\n";

	print $page->start_form(-method=>'POST',-action=>$url);
	$page->param(-name=>'actions',-value=>'error');
	print $page->hidden('actions','error');
	print $page->submit('submit','Return');
	print $page->endform;
	return;
      }

	
    ## prepare to query for hostname
    $sth = $dbh->prepare($hostquery);

    ## for each host, 
    ## tack on ip.qwest.net if needed
    ## create a hash of hostname - ip pairs, index by hostname
    for($i=0;$i<=$#hostnames;$i++)
      {
	$host = $hostnames[$i];
	$host_map{$host} = $ips[$i];

	## zero this out for each iteration for testing
	undef $result;

	## we want to check if this name already exists in DNS
	$result = gethostbyname $host;

	undef @row;
	
	## do the db query - if it exists, list it as a duplicate
	$rv = $sth->execute($host);
	@row = $sth->fetchrow_array;

	## add it to the problems list
	if ($result || @row) 
	  {
	    push @duphosts, $host;
	  }

      }


    ## we have duplicate hosts, so we should abort with an error.
    if ($#duphosts >= 0)
      {
	print "<h2>Error</h2>\n";
	print "<br>The following hosts already have DNS or DB entries:<br><br>\n";
	print "<ul>\n";
	foreach $host (@duphosts)
	  {
	    print "<li>$host</li>\n";
	  }

	print "</ul><br><br>\n";

	print $page->start_form(-method=>'POST',-action=>$url);
	$page->param(-name=>'actions',-value=>'error');
	print $page->hidden('actions','error');
	print $page->submit('submit','Return');
	print $page->endform;
	return;
      }	



    ## now we want to print out what hosts will be assigned what ip's
    ## print a table
    print "<table border=2 cellspacing=5>\n";
    print "<tr><td><b>Hostname</b></td><td><b>IP Address</b></td></tr>\n";

    foreach $host (@hostnames)
      {
	print "<tr><td>$host</td><td>$host_map{$host}</td></tr>\n";
      }
    
    print "</table>\n";

    ## now we want to ask the user if they want to proceed by committing
    ## these to the database, and mailing the DNS admins
        
    print $page->start_form(-method=>'POST',
			    -action=>"$myself"
			   );

    $i = 1;
    ## pass the host/ip pairs as parameters to the next invocation
    foreach $host (@hostnames)
      {
	$fieldname = "host-$i";
	$page->param(-name=>$fieldname,-values=>$host);
	print $page->hidden($fieldname,$page->param($fieldname));

	$fieldname = "ip-$i";
	$page->param(-name=>$fieldname,-values=>$host_map{$host});
	print $page->hidden($fieldname,$page->param($fieldname));

	$i++;
      }
    $page->param(-name=>'actions',-value=>'send_form');
    print $page->hidden('actions','send_form');
    print $page->hidden('numhosts',$i-1);
    print $page->hidden('email',$page->param('email'));
    print "<br><br>Click below to submit this request.<br><br>\n";
    print $page->submit('submit','Proceed and Request');
    print $page->endform;
    

  }  ## end of get_ip


###########################################################
## do_assign
##
## This subroutine does the database insert of the IP/host
## pairs passed to it from the last invocation where get_ip
## was run.  Also sends off the mail to the admins and the
## cc list.
##
## globals:
##    $page CGI object
##    $carbon_copy, $dns_admin
##    $tmpmail
##    $rv, $sth, $dbh - database objects and scalars
##
###########################################################
sub do_assign
  {
    my @timecodes;
    my $numhosts;  ## number of hosts
    my ($year, $month, $day, $hour, $minute);
    my $query = "insert into $tablename (octet_1, octet_2, octet_3, octet_4, email, date_requested, fqdn) values(?,?,?,?,?,TO_DATE(?,'YYYYMMDDHH24MI'),?)";
    my ($a, $b, $c, $d, $email, $date);
    my $i;
    my ($host, $ip);
    my $curdate = `date`;
    my $myself = $page->url;
    my $allrecip;   ## all recipients

    $numhosts = $page->param('numhosts');
    $email = $page->param('email');

    chomp $curdate;
    $carbon_copy = "$carbon_copy $email";

    ## send the e-mail
    $allrecip = "$dns_admin $carbon_copy";


    print "$numhosts hosts from $email<br>\n";

    ## set up the date
    @timecodes = localtime(time);

    $year = $timecodes[5] + 1900;
    $month = sprintf "%02d", $timecodes[4] + 1;
    $day = sprintf "%02d", $timecodes[3];
    $hour = sprintf "%02d", $timecodes[2];
    $min = sprintf "%02d", $timecodes[1];
    
    $date = "$year$month$day$hour$min";

    open TMPMAIL, ">$tmpmail" || die "Can't open temp mail file";
    print TMPMAIL "From $email   $curdate\n";
    print TMPMAIL "From: DNS Requestor <$email>\n";
    print TMPMAIL "To: $dns_admin\n";
    print TMPMAIL "Cc: $carbon_copy\n";
    print TMPMAIL "Subject: (New) DNS addition request.\n\n";
    print TMPMAIL "\n$email has requested the addition of these hosts and IP's to the DNS records:\n\n";

    ## prepare the query
    $sth = $dbh->prepare($query);

    ## print out online what hosts were entered and e-mailed
    print "<br>The following have been entered: <br>\n";
    print "<table border=2 cellspacing=5>\n";

    for ($i=1; $i <= $numhosts; $i++)
      {
	$host = $page->param("host-$i");
	$ip = $page->param("ip-$i");
	
	chomp $host;
	chomp $ip;

	print TMPMAIL "\t$ip\t$host\n";

	print "<tr><td>$host</td><td>$ip</td><td>$email</td><td>$date</td>\n";

	($a,$b,$c,$d) = split /\./, $ip;

	## for each host, execute the query
        $rv = $sth->execute($a,$b,$c,$d,$email,$date,$host);
	printf "<td>%s</td></tr>\n", $dbh->errstr;

      }

    print TMPMAIL "\nThank You,\n(the new) IP Engineering Automated IP Request Form\n";
    print TMPMAIL "Please report problems to $prob_email\n";
    close TMPMAIL;

    ## send mail.
    system "/bin/rmail $allrecip < $tmpmail";

    ## remove the temp file.
    unlink $tmpmail;

    print "</table>\n";
    print "<br><hr><br>Return to <a href=\"$myself\">IP Request Page</a><br>\n";

  }



######################################################
## view_rows 
## 
## This subroutine assumes a valid subnet given as argument, 
## queries the DB for that subnet.  It returns the result in
## a table.
##
## globals:
##    $rv, $sth, $dbh - database scalars and objects
##
######################################################

sub view_rows
  {
    my $subnet = shift @_;
    my ($a, $b, $c) = split /\./, $subnet;
    my @row;
    my ($d, $email, $date, $fqdn);
    my $query = "select octet_4, email, TO_CHAR(date_requested,'YYYY-MM-DD HH24:MI'), fqdn from $tablename where octet_1=$a and octet_2=$b and octet_3=$c";
    my $myself = $page->url;
    my $count = 0;

    ## prepare the query
    $sth = $dbh->prepare($query);
    ## execute the query
    $rv = $sth->execute;

    ## star the table
    print "<br><h3>Viewing DB records for $subnet subnet</h3><br>\n";

    print "<table border=2 cellspacing=5>\n";
    print "<tr><td><b>IP Address</b></td><td><b>FQDN</b></td>\n";
    print "<td><b>E-mail</b></td><td><b>Date</b></td></tr>\n";

    ## fetch rows from the query and print them
    while (@row = $sth->fetchrow_array)
      {
	$count++;
	($d, $email, $date, $fqdn) = @row;
	print "<tr><td>$a.$b.$c.$d</td><td>$fqdn</td><td>$email</td><td>$date</td></tr>\n";
      }
    print "</table>\n";

    print "<br>$count IP addresses for $subnet in database.<br>\n";

    ## allow the user to get back to main page
    print "<br><hr><br>Return to <a href=\"$myself\">IP Request Page</a><br>\n";

  }



#############################################################
## delete_ip
##
## this function queries the database for machines in a given subnet
## then prints them out with checkboxes next to each machine.  It
## includes all pertinent info about the machine.  Provides a way to
## submit selected machines for deletion.
##
## globals:
##   $page CGI object
##   $rv, $sth, $dbh   database objects and scalars
##
#############################################################
 
sub delete_ip
  {
    my $subnet = shift @_;
    my ($a, $b, $c) = split /\./, $subnet;
    my @row;
    my ($d, $email, $date, $fqdn);
    my $query = "select octet_4, email, TO_CHAR(date_requested,'YYYY-MM-DD HH24:MI'), fqdn from $tablename where octet_1=$a and octet_2=$b and octet_3=$c";
    my $myself = $page->self_url;
    my $ip;
    my (@ips);
    my $i;
    my %labels;
    my $self = $page->url;

    ## prepare the query
    $sth = $dbh->prepare($query);
    ## execute the query
    $rv = $sth->execute;

    ## star the table
    print "<br><h3>Choose DB records for $subnet subnet to delete</h3><br>\n";

    $i = 0;

    print $page->start_form(-method=>'POST',-action=>$myself);
    ## fetch rows from the query and print them
    while (@row = $sth->fetchrow_array)
      {
	## get the values
	($d, $email, $date, $fqdn) = @row;

	$ip = "$a.$b.$c.$d";
	

	$ips[$i++] = $ip;

	$labels{$ip} = " <font size=\"-1\"><b>$ip</b> <code>/ $fqdn / $email / $date</code></font>";
        
      }

   
    print "<br><b>Please enter your e-mail for confirmation (qwest.net or qwest.com required):</b><br>\n";
    print $page->textfield(-name=>'email',
			   -size=>30,
			   -maxlength=>50);
   
    print "<br><br><b>Choose IP's to delete:</b><br>";
    print $page->checkbox_group(-name=>'delete_ips',
				-values=>\@ips,
				-linebreak=>'true',
				-labels=>\%labels);
    $page->param(-name=>'actions',-value=>'selected_delete');
    print "<br><br>\n";
    print $page->hidden('actions','selected_delete');
    print "<h3>Press Submit only if you wish to remove the checked records from the local DB and DNS!</h3>\n";
    print $page->submit('submit','Proceed and Delete');
    print $page->endform;

    ## allow the user to get back to main page
    print "<br><hr><br>Return to <a href=\"$self\">IP Request Page</a><br>\n";

  }


##########################################################	
## do_delete 
##
## delete the entries from the DB and e-mail the form off
##
## globals:
##    $page CGI
##    $dns_admin, $carbon_copy
##    $rv, $sth, $dbh  database objects and scalars
##
##########################################################

sub do_delete
  {
    my @deleted = $page->param('delete_ips');
    my $query = "delete from $tablename where octet_1=? and octet_2=? and octet_3=? and octet_4=?";
    my $emailquery = "select email from $tablename where octet_1=? and octet_2=? and octet_3=? and octet_4=?";
    my ($a,$b,$c,$d, $email);
    my $ip;
    my $iaddr;
    my $fqdn;
    my $myself = $page->url;
    my $allrecip;
    my %emailhash;
    my @owners;
    my @row;
    my (%ccs, @copies);  ## vars for carbon copies
    my @listpairs;
    my $curdate = `date`;


    chomp $curdate;
    $email = $page->param('email');
    chomp $email;

    if (!($email =~ /^[\w\.]+@[\w\.]*qwest\.(com|net)$/i)) 
	{print "<h2>Error:</h2><br>Valid-type Qwest e-mail address required.<br>\n";
	 ## allow the user to get back to main page
	 print "<br><hr><br>Return to <a href=\"$myself\">IP Request Page</a><br>\n";
	 return;
       }

    print "<h2>The following have been deleted from the DB and sent to the DNS admins for removal:</h2>\n";
    print "<b>Note:</b> The names below reflect what a DNS lookup returns, not what's necessarily in the database, though they should be equivalent under most circumstances.<br><br>\n";

    ## prepare to query for the e-mail of each ip
    $sth = $dbh->prepare($emailquery);
    foreach $ip (@deleted)
      {
	($a,$b,$c,$d) = split /\./, $ip;
	
	$rv = $sth->execute($a,$b,$c,$d);
	@row = $sth->fetchrow_array;

	## add to the hash
	$emailhash{$row[0]} = 1;
      }

    ## the owners are the keys of the hash
    @owners = keys %emailhash;

    ## prepare the DB
    $sth = $dbh->prepare($query);

    print "<table border=2 cellspacing=5>\n";

    foreach $ip (@deleted)
      {
	($a,$b,$c,$d) = split /\./, $ip;

	$iaddr = inet_aton $ip;
	$fqdn = gethostbyaddr $iaddr, AF_INET;


	push @listpairs, "\t$ip\t$fqdn\n";
	print "<tr><td>$ip</td><td>$fqdn</td></tr>\n";

	$rv = $sth->execute($a,$b,$c,$d);
      }

    print "</table>";

    ## build the e-mail
    if ($carbon_copy) {$ccs{$carbon_copy} = 1;}
    $ccs{$email} = 1;
    foreach (@owners)
      {
	$ccs{$_} = 1;
      }
    @copies = keys %ccs;;

    
    $allrecip = "$dns_admin @copies";

    ## get mail file ready
    open TMPMAIL, ">$tmpmail" || die "Can't open temp mail file";
    print TMPMAIL "From $email   $curdate\n";
    print TMPMAIL "From: DNS Deletor <$email>\n";
    print TMPMAIL "To: $dns_admin\n";
    print TMPMAIL "Cc: @copies\n";
    print TMPMAIL "Subject: (New) DNS deletion request.\n\n";    
    print TMPMAIL "\n$email has requested the removal of the following DNS entries:\n";
    print TMPMAIL "@listpairs";
    print TMPMAIL "\nThank You,\n(the new) IP Engineering Automated IP Request Form\n";
    print TMPMAIL "Please report problems to $prob_email\n";
    close TMPMAIL;;

    ## send the e-mail
    system "/bin/rmail $allrecip < $tmpmail";

    ## remove the temp file.
    unlink $tmpmail;

    ## allow the user to get back to main page
    print "<br><hr><br>Return to <a href=\"$myself\">IP Request Page</a><br>\n";


  }
  



#############################################################
## claim_ip
##
## this function queries the database for machines in a given subnet
## then prints them out with checkboxes next to each machine.  It
## includes all pertinent info about the machine.  Provides a way to
## claim machines for the e-mail entered.
##
## globals:
##   $page CGI object
##   $rv, $sth, $dbh   database objects and scalars
##
#############################################################
 
sub claim_ip
  {
    my $subnet = shift @_;
    my ($a, $b, $c) = split /\./, $subnet;
    my @row;
    my ($d, $email, $date, $fqdn);
    my $query = "select octet_4, fqdn from $tablename where octet_1=$a and octet_2=$b and octet_3=$c and email='#None#' order by octet_4 asc";
    my $myself = $page->self_url;
    my $ip;
    my (@ips);
    my $i;
    my %labels;
    my $self = $page->url;

    ## prepare the query
    $sth = $dbh->prepare($query);
    ## execute the query
    $rv = $sth->execute;

    ## star the table
    print "<br><h3>Choose DB records for $subnet subnet to claim:</h3><br>\n";

    $i = 0;

    print $page->start_form(-method=>'POST',-action=>$myself);
    ## fetch rows from the query and print them
    while (@row = $sth->fetchrow_array)
      {
	## get the values
	($d, $fqdn) = @row;

	$ip = "$a.$b.$c.$d";
	

	$ips[$i++] = $ip;

	$labels{$ip} = " <font size=\"-1\"><b>$ip</b> <code>/ $fqdn</code></font>";
        
      }

   
    print "<br><b>Please enter your e-mail to claim these names. (qwest.net or qwest.com required):</b><br>\n";
    print $page->textfield(-name=>'email',
			   -size=>30,
			   -maxlength=>50);
   
    print "<br><br><b>Choose IP's to claim with this e-mail:</b><br>";
    print $page->checkbox_group(-name=>'claim_ips',
				-values=>\@ips,
				-linebreak=>'true',
				-labels=>\%labels);
    $page->param(-name=>'actions',-value=>'do_claim');
    print "<br><br>\n";
    print $page->hidden('actions','do_claim');
    print "<h3>Press Submit to associate your e-mail with these hosts.</h3>\n";
    print $page->submit('submit','Claim Hosts!');
    print $page->endform;

    ## allow the user to get back to main page
    print "<br><hr><br>Return to <a href=\"$self\">IP Request Page</a><br>\n";

  }


##########################################################	
## do_claim
##
## delete the entries from the DB and e-mail the form off
##
## globals:
##    $page CGI
##    $dns_admin, $carbon_copy
##    $rv, $sth, $dbh  database objects and scalars
##
##########################################################

sub do_claim
  {
    my @claimed = $page->param('claim_ips');
    my $query = "update $tablename set email=?, date_requested = TO_DATE(?,'YYYYMMDDHH24MI') where octet_1=? and octet_2=? and octet_3=? and octet_4=?";
    my ($a,$b,$c,$d, $email);
    my $ip;
    my $myself = $page->url;
    my (@timecodes, $date, $year, $month, $day, $hour, $minute);

    ## set up the date
    @timecodes = localtime(time);

    $year = $timecodes[5] + 1900;
    $month = sprintf "%02d", $timecodes[4] + 1;
    $day = sprintf "%02d", $timecodes[3];
    $hour = sprintf "%02d", $timecodes[2];
    $min = sprintf "%02d", $timecodes[1];
    
    $date = "$year$month$day$hour$min";

    $email = $page->param('email');
    chomp $email;

    if (!($email =~ /^[\w\.]+@[\w\.]*qwest\.(com|net)$/i)) 
	{print "<h2>Error:</h2><br>Valid-type Qwest e-mail address required.<br>\n";
	 ## allow the user to get back to main page
	 print "<br><hr><br>Return to <a href=\"$myself\">IP Request Page</a><br>\n";
	 return;
       }

    print "<h2>The following IP's have been claimed with indicated e-mail in the database:</h2>\n";


    ## prepare the update query
    $sth = $dbh->prepare($query);

    print "<table border=2 cellspacing=5>\n";

    foreach $ip (@claimed)
      {
	($a,$b,$c,$d) = split /\./, $ip;

	print "<tr><td>$ip</td><td>$fqdn</td><td><i>$email</i></td></tr>\n";

	$rv = $sth->execute($email,$date,$a,$b,$c,$d);
      }

    $rc = $sth->finish;
    
    print "</table>";

    ## allow the user to get back to main page
    print "<br><hr><br>Return to <a href=\"$myself\">IP Request Page</a><br>\n";


  }
  




#############################################################
## change_ip
##
## this function queries the database for machines in a given subnet
## then prints them out with checkboxes next to each machine.  It
## includes all pertinent info about the machine.  Provides a way to
## submit selected machines for changes.
##
## globals:
##   $page CGI object
##   $rv, $sth, $dbh   database objects and scalars
##
#############################################################
 
sub change_ip
  {
    my $subnet = shift @_;
    my ($a, $b, $c) = split /\./, $subnet;
    my @row;
    my ($d, $email, $date, $fqdn);
    my $query = "select octet_4, email, TO_CHAR(date_requested,'YYYY-MM-DD HH24:MI'), fqdn from $tablename where octet_1=$a and octet_2=$b and octet_3=$c";
    my $myself = $page->self_url;
    my $ip;
    my (@ips);
    my $i;
    my %labels;
    my $self = $page->url;

    ## prepare the query
    $sth = $dbh->prepare($query);
    ## execute the query
    $rv = $sth->execute;

    ## star the table
    print "<br><h3>Choose DB records for $subnet subnet to change</h3><br>\n";

    $i = 0;

    print $page->start_form(-method=>'POST',-action=>$myself);
    ## fetch rows from the query and print them
    while (@row = $sth->fetchrow_array)
      {
	## get the values
	($d, $email, $date, $fqdn) = @row;

	$ip = "$a.$b.$c.$d";
	

	$ips[$i++] = $ip;

	$labels{$ip} = " <font size=\"-1\"><b>$ip</b><code> / $fqdn / $email / $date</code></font>";
        
      }

   
    print "<br><b>Please enter your e-mail for confirmation (qwest.net or qwest.com required):</b><br>\n";
    print $page->textfield(-name=>'email',
			   -size=>30,
			   -maxlength=>50);
   
    print "<br><br><b>Choose IP's to delete:</b><br>";
    print $page->checkbox_group(-name=>'change_ips',
				-values=>\@ips,
				-linebreak=>'true',
				-labels=>\%labels);
    $page->param(-name=>'actions',-value=>'spec_change');
    print "<br><br>\n";
    print $page->hidden('actions','spec_change');
    print "<h3>Press Submit to specify changes!</h3>\n";
    print $page->submit('submit','Specify Changes');
    print $page->endform;

    ## allow the user to get back to main page
    print "<br><hr><br>Return to <a href=\"$self\">IP Request Page</a><br>\n";

  }


##########################################################
## spec_change
##
## specify the changes that are to take place.
##
## globals:
##    $page CGI
##    $rv, $sth, $dbh  database objects and scalars
##
##########################################################
sub spec_change
  {
    my @changed = $page->param('change_ips');
    my $ip;
    my $myself = $page->self_url;
    my $self = $page->url;
    my $query = "select fqdn, email from addresses where octet_1=? and octet_2=? and octet_3=? and octet_4=?";
    my @row;
    my $fqdn;
    my $orig_email;
    my $email;
    my %emails;
    my ($a,$b,$c,$d);
    my @receipients;

    $email = $page->param('email');

    if (!($email =~ /^[\w\.]+@[\w\.]*qwest\.(com|net)$/i)) 
	{print "<h2>Error:</h2><br>Valid-type Qwest e-mail address required.<br>\n";
	 ## allow the user to get back to main page
	 print "<br><hr><br>Return to <a href=\"$myself\">IP Request Page</a><br>\n";
	 return;
       }


    print "<h3>Change Request</h3>\n";
    print "If the new names given are not fully qualified,\n";
    print " .ip.qwest.net is assumed.<br><br>\n";

    print $page->start_form(-method=>'POST',-action=>$myself);

    ## prepare the query
    $sth = $dbh->prepare($query);

    print "<table border=2>\n";
    print "<tr><td><b>Current Name/Contact</b></td>\n";
    print "<td><b>Enter New Hostname</b></td>\n";

    foreach $ip (@changed)
      {
	print "<tr><td>";

	($a,$b,$c,$d) = split /\./, $ip;

	## execute the query
	$rv = $sth->execute($a,$b,$c,$d);   
	
	## fetch rows from the query and print them
	@row = $sth->fetchrow_array;

	$fqdn = $row[0];
	$orig_email = $row[1];
	$emails{$orig_email} = 1;   ## start hash of unique people to identify
	
	print "<i>$ip</i><br>$fqdn ($orig_email)";
	print "</td><td>";
	
	## print out form field
	print $page->textfield(-name=>$ip,
			   -size=>20,
			   -maxlength=>40);

	print "</td></tr>\n";
    
      }

    print "</table>\n";

    @receipients = keys %emails;

    $page->param(-name=>'actions',-value=>'do_change');
    print "<br><br>\n";
    print $page->hidden('actions','do_change');
    print $page->hidden('email',$email);
    print $page->hidden('recip',@receipients);
    print "<h3>Press Submit to submit changes!</h3>\n";
    print $page->submit('submit','Submit Changes');
    print $page->endform;

    ## allow the user to get back to main page
    print "<br><hr><br>Return to <a href=\"$self\">IP Request Page</a><br>\n";

  }
    
    
    

##########################################################	
## do_change 
##
## change the entries from the DB and e-mail the form off
##
## globals:
##    $page CGI
##    $dns_admin, $carbon_copy
##    $rv, $sth, $dbh  database objects and scalars
##
##########################################################

sub do_change
  {
    my @recip = $page->param('recip');
    my $query = "update $tablename set email=?, fqdn=?, date_requested = TO_DATE(?,'YYYYMMDDHH24MI') where octet_1=? and octet_2=? and octet_3=? and octet_4=?";
    my ($a,$b,$c,$d);
    my $email = $page->param('email');
    my %newnames;
    my $newname;
    my $myself = $page->url;
    my $allrecip;
    my @owners;
    my @row;
    my $fqdn;
    my (%ccs, @copies);  ## vars for carbon copies
    my $curdate = `date`;
    my (@timecodes, $date, $year, $month, $day, $hour, $minute);
    my @names;
    my $name;

    ## get rid of nasty newline
    chomp $curdate;

    print "<h2>The following have been changed in the DB and sent to the DNS admins:</h2>\n";

    ## set up the date
    @timecodes = localtime(time);

    $year = $timecodes[5] + 1900;
    $month = sprintf "%02d", $timecodes[4] + 1;
    $day = sprintf "%02d", $timecodes[3];
    $hour = sprintf "%02d", $timecodes[2];
    $min = sprintf "%02d", $timecodes[1];
    
    $date = "$year$month$day$hour$min";


    @names = $page->param;

    ## sort out which parameters are IP addresses and nab the new
    ## domain name associated with each.
    foreach $name (@names)
      {
	if ($name =~ /\d+\.\d+\.\d+\.\d+/)
	  {
	    $newname = $page->param($name);
	    ## add .ip.qwest.net if appropriate
	    if (!($newname =~ /\./)) {$newname = "$newname.ip.qwest.net";}
	    $newnames{$name} = $newname;
	  }
      }

    @names = sort keys %newnames;
    
    ## get the database set up to update
    $sth = $dbh->prepare($query);

    print "<table border=2>\n";
    print "<tr><td><b>IP Address</b></td><td><b>New Host Name</b></td></tr>\n";
    
    foreach $name (@names)
      {
	$fqdn = $newnames{$name};
	($a,$b,$c,$d) = split /\./, $name;
	print "<tr><td>$name</td>";
	print "<td>$fqdn</td>\n";

	## do the update
	$rv = $sth->execute($email,$fqdn,$date,$a,$b,$c,$d);
	printf "<td>%s</td></tr>\n", $dbh->errstr;

      }

    print "</table><br>\n";

    print "<br>\n";


    ## build the e-mail
    if ($carbon_copy) {$ccs{$carbon_copy} = 1;}
    $ccs{$email} = 1;
    foreach (@recip)
      {
	$ccs{$_} = 1;
      }
    @copies = keys %ccs;;

    
    $allrecip = "$dns_admin @copies";

    ## get mail file ready
    open TMPMAIL, ">$tmpmail" || die "Can't open temp mail file";
    print TMPMAIL "From $email   $curdate\n";
    print TMPMAIL "From: DNS Changer <$email>\n";
    print TMPMAIL "To: $dns_admin\n";
    print TMPMAIL "Cc: @copies\n";
    print TMPMAIL "Subject: (New) DNS change request.\n\n";    
    print TMPMAIL "\n$email has requested to the following DNS updates:\n";

    foreach $name (@names)
      {
	printf TMPMAIL "\t%s\t%s\n", $name, $newnames{$name};
      }

    print TMPMAIL "\nThank You,\n(the new) IP Engineering Automated IP Request Form\n";
    print TMPMAIL "Please report problems to $prob_email\n";
    close TMPMAIL;;

    ## send the e-mail
    system "/bin/rmail $allrecip < $tmpmail";

    ## remove the temp file.
    unlink $tmpmail;

    ## allow the user to get back to main page
    print "<br><hr><br>Return to <a href=\"$myself\">IP Request Page</a><br>\n";


  }
    

  

##############################################################
## main 
##
## main takes the actions input from the other forms and decides
## which function to invoke with what information it has.  Thus
## it controls which invocation will occur.  It also prints out
## the html header and footer.
##
## globals:
##    $page CGI object
##    $dbh database object
##    $data_source, $username, $tablename, $dbpasswd
##
##############################################################
sub main
  {
    my @names;
    my %labels;
    my $myself;



    $page = new CGI;
    $page->autoEscape(undef);

    print $page->header;
    print $page->start_html(-title=>'IP Request Page',
			     -background=>'/images/bg0005.gif');
    print "<blockquote><blockquote><center>\n";
    print $page->h1('IP Address Request Page');
    print "</center><br><hr><br>\n";
    print "<blockquote>\n";

    ## action indicates the desire to view a subnet.  Provide user with that
    ## opportunity
    if ($page->param('actions') eq 'view')
      {
	## print "Selected view<br><br>\n";
	## @names = $page->param;
	## foreach (@names) {printf "%s : %s<br>\n", $_, $page->param("$_");}
	$dbh = DBI->connect($data_source, $username, $dbpasswd, {AutoCommit => 1}) 
	      || die $dbh->errstr;

	view_rows($page->param('subnet'));

	## disconnect
	$dbh->disconnect;
	
      }

    ## user wants to request an IP or block thereof.  Let him or her do so.
    elsif($page->param('actions') eq 'request')
      {
	## print "Selected request<br><br>\n";
	## @names = $page->param;
	## foreach (@names) {printf "%s : %s<br>\n", $_, $page->param("$_");}
	req_ip($page->param('subnet'));
      }

    ## we've got the e-mail and hosts, now look for stuff
    elsif($page->param('actions') eq 'got_info')
      {
	## print "We got the info....<br><br>\n";
	## @names = $page->param;
	## foreach (@names) {printf "%s : %s<br>\n", $_, $page->param("$_");}
	$dbh = DBI->connect($data_source, $username, $dbpasswd, {AutoCommit => 1}) 
	      || die $dbh->errstr;
	## get the IP's
       	get_ip($page->param('subnet'));

	## disconnect
	$dbh->disconnect;
	
      }

    ## send the form off
    elsif($page->param('actions') eq 'send_form')
      {
	## print "Sending off stuff...<br><br>\n";
	## @names = $page->param;
	## foreach (@names) {printf "%s : %s<br>\n", $_, $page->param("$_");}
	$dbh = DBI->connect($data_source, $username, $dbpasswd, {AutoCommit => 1}) 
	      || die $dbh->errstr;

	## do the assignments and database commits
	do_assign();

	## disconnect
	$dbh->disconnect;
      }	

    ## do a delete
    elsif($page->param('actions') eq 'delete')
      {
	$dbh = DBI->connect($data_source, $username, $dbpasswd, {AutoCommit => 1}) 
	      || die $dbh->errstr;

	## do the assignments and database commits
	delete_ip($page->param('subnet'));

	## disconnect
	$dbh->disconnect;
      }	

    elsif($page->param('actions') eq 'selected_delete')
      {
	$dbh = DBI->connect($data_source, $username, $dbpasswd, {AutoCommit => 1}) 
	      || die $dbh->errstr;

	## do the assignments and database commits
	do_delete();

	## disconnect
	$dbh->disconnect;
      }	


    ## claim an IP/name
    elsif($page->param('actions') eq 'claim')
      {
	$dbh = DBI->connect($data_source, $username, $dbpasswd, {AutoCommit => 1}) 
	      || die $dbh->errstr;

	## do the assignments and database commits
	claim_ip($page->param('subnet'));

	## disconnect
	$dbh->disconnect;
      }	

    elsif($page->param('actions') eq 'do_claim')
      {
	$dbh = DBI->connect($data_source, $username, $dbpasswd, {AutoCommit => 1}) 
	      || die $dbh->errstr;

	## do the assignments and database commits
	do_claim();

	## disconnect
	$dbh->disconnect;
      }	



    ## do a change
    elsif($page->param('actions') eq 'change')
      {
	$dbh = DBI->connect($data_source, $username, $dbpasswd, {AutoCommit => 1}) 
	      || die $dbh->errstr;

	## do the changes and database commits
	change_ip($page->param('subnet'));

	## disconnect
	$dbh->disconnect;
      }	

    ## specify changes to be made
    elsif($page->param('actions') eq 'spec_change')
      {
	$dbh = DBI->connect($data_source, $username, $dbpasswd, {AutoCommit => 1}) 
	      || die $dbh->errstr;

	## do the changes and database commits
	spec_change();

	## disconnect
	$dbh->disconnect;
      }

    elsif($page->param('actions') eq 'do_change')
      {
	$dbh = DBI->connect($data_source, $username, $dbpasswd, {AutoCommit => 1}) 
	      || die $dbh->errstr;

	## do the assignments and database commits
	do_change();

	## disconnect
	$dbh->disconnect;
      }	



    ## otherwise, we're probably just on the main page.
    else
      {
	#@names = $page->param;
	#foreach (@names) {printf "%s : %s<br>\n", $_, $page->param("$_");}

	$myself = $page->self_url;
	print $page->start_form(-method=>'POST',
				-action=>"$myself"
				);
	$labels{'view'} = " View Allocated IP Addresses for a Subnet";
	$labels{'request'} = " Request one or more static named IP(s) on a Subnet";
	$labels{'delete'} = " Delete IP's from allocated DNS tables on a Subnet";
	$labels{'change'} = " Change a previously entered IP address.";
	$labels{'claim'} = " Claim ownership of an IP/hostname on a subnet.";

	print "<br><b>Select Action to perform:</b><br>\n";
	print $page->radio_group(-name=>'actions',
				  -values=>['view','request','delete',
					    'change', 'claim'],
				  -default=>'view',
				  -linebreak=>'true',
				  -labels=>\%labels);
	print "<br><br><b>Subnet to perform action upon:</b><br>\n";
	print $page->radio_group(-name=>'subnet',
				  -values=>[@subnets],
				  -linebreak=>'true');
	print "<br><br><br>\n";
	print $page->submit('submit','Proceed');
	print $page->endform;
      }

    print "</blockquote></blockquote></blockquote>\n";

    print $page->end_html;


    exit(0);  ## exit with no error code

  }
