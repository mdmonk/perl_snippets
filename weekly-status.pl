#!/usr/bin/perl
#
# weekly-status.pl - view and create weekly status reports
#
#
# $Id: weekly-status.pl,v 1.4 2000/09/11 21:07:56 gregb Exp gregb $
#
########################################################################

## includes and directives
use DBD::Oracle;
use CGI;

#### Globals #####

## subnets here are all /24, and require the xxx.xxx.xxx format
my ($dbh, $sth, $rv, $rc);   ## database handle, statement handle, and return 
                        ## code for DB stuff
## database connection parameters
my $data_source = "dbi:Oracle:host=crash.ip.qwest.net;sid=ipeng";
my $username = "status";
my $dbpasswd = "busywork";

my $page;  ## CGI object

## location of manager's edition
my $man_ed = "/perl/manager-admin-only/weekly-status-manager.pl";

## seconds in a day
my $daysec = 86400;

## types of reports - used in both adding and displaying
my @types = ("ACHIEVEMENT","INITIATIVE","MP_STATUS","REVENUE_IMPACTS", 
	    "CRITICAL_ISSUES","STAFFING_REPORT");
my %typelabels;
$typelabels{"ACHIEVEMENT"} = "Achievements";
$typelabels{"INITIATIVE"} = "Initiatives";
$typelabels{"MP_STATUS"} = "Major Product Status";
$typelabels{"REVENUE_IMPACTS"} = "Revenue Impacts";
$typelabels{"CRITICAL_ISSUES"} = "Critical Issues";
$typelabels{"STAFFING_REPORT"} = "Staffing Report";

#### Environment ####
$ENV{'ORACLE_HOME'} = '/usr/local/oracle/app/oracle/product/8.1.6';


###### THE PROGRAM ######
main();

## End of Program ##  Perl is easy, isn't it?


#### Subroutines #####

## return_footer - print a footer that allows the user to return to the
## main page without doing anything
sub return_footer
  {
    my $url = $page->url;

    print "<br><hr><br>Return to <a href=\"$url\">Weekly Status Application</a><br>\n";
    
    return;
  }




############# INSERT ROUTINES ##################

## add status - allows user to add a status report
sub add_status
  {
    my $curweek = shift @_;   ## given as argument
    my $myself = $page->self_url;
    my $engquery = "select firstname, lastname from engineers";
    my $projquery = "select project_name from projects";
    my @row;
    my $teamquery = "select team_name from teams";
    my @engineers;
    my @projects;
    my @teams;

    ## get engineers
    $sth = $dbh->prepare($engquery);
    $rv = $sth->execute;

    while (@row = $sth->fetchrow_array)
      {
	push @engineers, "$row[0] $row[1]";
      }

    $rc = $sth->finish;


    ## get teams
    $sth = $dbh->prepare($teamquery);
    $rv = $sth->execute;

    while (@row = $sth->fetchrow_array)
      {
	push @teams, $row[0];
      }

    $rc = $sth->finish;
  

    ## get projects
    $sth = $dbh->prepare($projquery);
    $rv = $sth->execute;

    while (@row = $sth->fetchrow_array)
      {
	push @projects, $row[0];
      }
    
    $rc = $sth->finish;
    
    ## now print out the form.

    print "<h2>Status Entry Page</h2>\n";
    print "<br>Please select engineer, product, and type of report, then";
    print " enter your status report in the text box.  2000";
    print " characters max.<br><br>\n"; 

    ## print out the form fields
    ## lots of stuff to choose
    print $page->start_form(-method=>'POST',
			    -action=>"$myself"
			   );

    print "<table border=0 cellspacing=10>";
    print "<tr>\n";
    print "<td><br><b>Current Week:<br>\n";
    print $page->popup_menu(-name=>'cur_week',
			   -values=>[$curweek]
			   );
    
    print "</td><td><br><b>Project Name:<br>\n";
    print $page->popup_menu(-name=>'proj_name',
			    -values=>\@projects
			   );

    print "</td></tr><tr>\n";

    print "<td><br><b>Engineer Name:<br>\n";
    print $page->popup_menu(-name=>'engineer',
			    -values=>\@engineers
			   );


    print "</td><td><br><b>Team this report is for:<br>\n";
    print $page->popup_menu(-name=>'team',
			    -values=>\@teams
			   );

    print "</td></tr><tr>\n";    

    print "<td><br><b>Type of Entry:<br>\n";
    print $page->popup_menu(-name=>'type',
			    -values=>\@types,
			    -labels=>\%typelabels
			   );
    
    print "</td></tr></table>\n";

    print "<br><br>Status Report:<br>\n";
    print $page->textarea(-name=>'report',
			  -maxlength=>2000,
			  -rows=>10,
			  -columns=>60,
			  -default=>'<Your Report Here>'
			  );

    ## save information for invocation of script
    
    print "<br><br>\n";
    $page->param(-name=>'actions',-value=>'stat_entry');
    print $page->hidden('actions','stat_entry');
    print $page->submit('submit','Add Entry');
    print $page->endform;

    return_footer();

    return;
  }


## inmsert status takes what the user entered and inserts it into
## the database
sub insert_status
  {
    my $query = "insert into status_entries (project,engineer,week,type,status,product,team_name) values (?,?,TO_DATE(?,'MM/DD/YYYY'),?,?,?,?)";
    my ($engineer, $project, $week, $type, $status);
    my @row;
    my $repquery = "select week from reports where week = TO_DATE(?,'MM/DD/YYYY')";
    my $repins = "insert into reports (week) values (TO_DATE(?,'MM/DD/YYYY'))";
    my $prodquery = "select product from projects where project_name = ?";
    my $product;
    my $team;

    ## get stuff from environment
    $engineer = $page->param('engineer');
    $week = $page->param('cur_week');
    $type = $page->param('type');
    $project = $page->param('proj_name');
    $status = $page->param('report');
    $team = $page->param('team');

    ## find out what product this project belongs to
    $sth = $dbh->prepare($prodquery);
    $rv = $sth->execute($project);

    ## get the product
    @row = $sth->fetchrow_array;
    $product = $row[0];

    $rc = $sth->finish;

    ## do the status insert
    $sth = $dbh->prepare($query);
    $rv = $sth->execute($project,$engineer,$week,$type,$status,$product,$team);
    
    ## oops - error
    if ($rv != 1)
      {
	print "<br><h3>Error: $rv</h3>\n";
	printf "%s<br>", $dbh->errstr;
      }
    else  ## inserted OK
      {
	print "<br>$engineer successfully inserted a report!<br>\n";
      }

    $rc = $sth->finish;

    ## if the week isn't in the list, add it.
    $sth = $dbh->prepare($repquery);
    $rv = $sth->execute($week);

    if (!(@row = $sth->fetchrow_array))
      {
	$rc = $sth->finish;

	$sth = $dbh->prepare($repins);
	$rv = $sth->execute($week);

	$rc = $sth->finish;

	## oops - error
	if ($rv != 1)
	  {
	    print "<br><h3>Error: $rv</h3>\n";
	    printf "%s<br>", $dbh->errstr;
	  }
	else  ## inserted OK
	  {
	    $rc = $sth->finish;
	    print "<br>$week successfully added to list of weeks with reports<br>\n";
	  }
	
      }	


    return_footer();
    
    return;
  }






############## VIEWER ROUTINES ####################

## select_view - allows selection of what to view by team and week
sub select_view
  {
    my $query = "select TO_CHAR(week, 'MM/DD/YYYY') from reports order by week desc";
    my @row;
    my $teamquery = "select team_name from teams";
    my @teams;
    my @weeks;


    my $myself = $page->self_url;


    $sth = $dbh->prepare($query);
    $rv = $sth->execute;
    
    ## we need the list of weeks as an array, not as a reference
    ## to an array of one element arrays that contain them.
    while (@row = $sth->fetchrow_array)
      {
	push @weeks, $row[0];
      }
    
    $rc = $sth->finish;
    
    $sth = $dbh->prepare($teamquery);
    $rv = $sth->execute;
    
    ## get list of teams
    while (@row = $sth->fetchrow_array)
      {
	push @teams, $row[0];
      }
    
    $rc = $sth->finish;
    
    print "<h3>View Weekly Reports with the following parameters:</h3>\n";

    ## print out the form fields
    print $page->start_form(-method=>'POST',
			    -action=>"$myself"
			   );


    ## popup menu with list of parameters for viewing
    print "<br>Choose the Team to view.  Selecting a team with teams under";
    print " it will view reports for that team and all sub-teams<br>\n";
    print $page->popup_menu(-name=>'team',
			    -values=>\@teams
			    );

    print "<br>Starting Week:<br>";
    print $page->popup_menu(-name=>'start_week',
			    -values=>\@weeks
			    );
    
    print "<br>Ending Week:<br>";
    print $page->popup_menu(-name=>'end_week',
			    -values=>\@weeks
			    );
    

    ## print out the end of the form and page

    $page->param(-name=>'actions',-value=>'do_view');
    print $page->hidden('actions','do_view');
    print $page->submit('submit','View');
    print $page->endform;

    return_footer();

    return;
  }



## view report - prints out the report
sub view_report
  {
    my $query = 
      "select product, project, engineer, status, team_name 
          from status_entries 
          where week >= TO_DATE(?,'MM/DD/YYYY') and 
                week <= TO_DATE(?,'MM/DD/YYYY') and
              type = ? and 
              team_name in 
                (select team_name from teams start with team_name = ?
                 connect by parent_team = prior team_name)
          order by product, project, engineer";
    my $ary_ref;
    my @row;
    my ($project, $product, $engineer, $status);
    my ($curprod, $curproj);
    my $first;
    my $type;
    my ($team,$startweek,$endweek);

    $team = $page->param('team');
    $startweek = $page->param('start_week');
    $endweek = $page->param('end_week');

    ## print out the top of the page
    print "<center><h1>IP and Strategic Transport Planning<br>\n";
    print "Weekly Report</h1></center><br>\n";
    print "<h2>Period of: $startweek to $endweek</h2>\n";
    print "<h2>Team: $team</h2>\n";


    ## there are about 5 or 6 different types of status.  We need
    ## to print a section for each.

    foreach $type (@types)
      {

	printf "<br><br><h3>%s:</h3>\n", $typelabels{$type};
	print "<table border=1 cellspacing=5 width=\"60\%\">\n";

	undef $curprod;


	## this is a flag for the first time through the loop
	$first = 1;
	
	## now query for the statuses of Acheivements
	$sth = $dbh->prepare($query);
	$rv = $sth->execute($startweek,$endweek,$type,$team);
	
	## iterate through achievements
	while (@row = $sth->fetchrow_array)
	  {
	    ## get the data
	    ($product,$project,$engineer,$status) = @row;
	    
	    ## if this is the first in a new group of products, create
	    ## a new table row
	    if ($product ne $curprod)
	      { ## set up the stuff to make the new product the current
		$curprod = $product;
		undef $curproj;  ## always a new project
		
		## if this is more than one time through, print the end
		if (!$first)
		  { print "</td></tr>\n"; }
		else {$first = 0;}
		
		print "<tr><td><h4>$product ";
		printf "%s:</h4>\n", $typelabels{$type};
	      }
	    
	    ## if we're starting a new project
	    if ($project ne $curproj)
	      {
		$curproj = $project;
		
		print "<b><i>&nbsp&nbsp&nbsp&nbsp - $project</b></i><br>\n";
	      }
	    
	    ## print the status
	    print "&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp - $status ($engineer)<br>\n";
	    
	  }
	
	## print the end of the table
	print "</td></tr></table>\n";
	$rc = $sth->finish;
	
      }  # end foreach $type


    return_footer();

    return;
  }

############## UTILITY ROUTINES ####################

## cur_week - returns the date of the monday of the current week
## as a string MM/DD/YYYY
sub cur_week
  {
    my $curtime;
    my @timefields;
    my $weekstring;
    my $days;
    my $curday;
    my $subseconds;
    my $newtime;
    my ($month, $day, $year);

    @timefields = localtime(time);

    ## what's the current day of the week?
    $curday = $timefields[6];
    ## if it's Sunday, revert to previous week, and set to 7 days.
    if ($curday == 0) {$curday = 7;}

    ## day of week is now Mon-Sun, 1-7.  To find out what the date of
    ## the monday of the current week is, subtract $curday-1 days from
    ## the current time
    $subseconds = $daysec * ($curday - 1);

    ## get the current time in seconds
    $curtime = time;

    ## now get the 'time' of the appropriate number of days ago.
    ## namely, that monday
    $newtime = $curtime - $subseconds;

    ## now get the localtime representation for that monday
    @timefields = localtime($newtime);
    $day = $timefields[3];   ## day of month
    $month = $timefields[4];  ## month
    $month++;                 ## convert from 0..11 to 1..12
    $year = $timefields[5];   ## year
    $year += 1900;            ## convert to 4 digit

    ## now return the date of the week string
    $weekstring = sprintf "%02d/%02d/%04d", $month, $day, $year;

    return $weekstring;
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
##    $dbh, $sth database object
##    $data_source, $username, $tablename, $dbpasswd
##
##############################################################
sub main
  {
    my %labels;
    my $myself;
    my $curweek;
    my $query = "select TO_CHAR(week, 'MM/DD/YYYY') from reports order by week desc";
    my $ary_ref;
    my @weeks;
    my @row;
    my $entry;
    my @names;
    my $teamquery = "select team_name from teams";
    my @teams;

    $page = new CGI;
    $page->autoEscape(undef);

    $curweek = cur_week();

    print $page->header;
    print $page->start_html(-title=>'Weekly Status Application',
			     -background=>'/images/report-bg.gif');

    print "<center>";
    print $page->h1('Weekly Status Application');
    print $page->h2("Current Week: $curweek");
    print "<br><hr><br></center>\n";
    print "<blockquote><blockquote><blockquote><blockquote>\n";


    # @names = $page->param;
    # foreach (@names) {printf "%s : %s<br>\n", $_, $page->param("$_");}

    $dbh = DBI->connect($data_source, $username, $dbpasswd, {AutoCommit => 1}) 
      || die $dbh->errstr;

	
    ## Add a status report for the current week
    if ($page->param('actions') eq 'addstat')
      {
	add_status($curweek);
      }
    elsif($page->param('actions') eq 'stat_entry')
      {
	insert_status();
      }
    
    ## select parameters for viewing
    elsif($page->param('actions') eq 'view')
      {
	select_view();
      }	
    ## view the report for the week given
    elsif($page->param('actions') eq 'do_view')
      {
	view_report();
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
	$labels{'view'} = "View Status Report for a Given week";
	$labels{'addstat'} = "Add a status entry to this week's Status Report";

	print "<h3>Select Action to perform:</h3><br>\n";
	print $page->radio_group(-name=>'actions',
				  -values=>['view','addstat'],
				  -default=>'view',
				  -linebreak=>'true',
				  -labels=>\%labels);
	"<br><br><br><br><br>\n";
	print $page->submit('submit','Proceed');
	print $page->endform;

	print "<h3>Administrative and Manager Functionality</h3>\n";
	print "Including insertion and deletion of engineers, teams,\n";
	print "projects, and producs, as well as removal of status\n";
	print "reports.  Go to the <a href=\"$man_ed\">Manager's Edition\n";
	print "</a> You must be configured to access this.<br>\n";

      }

    print "</blockquote></blockquote></blockquote></blockquote>\n";


    print $page->end_html;

    ## disconnect
    $dbh->disconnect;


    exit(0);  ## exit with no error code

  }
