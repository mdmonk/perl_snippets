#!/usr/local/bin/perl

#File name: calendar2.cgi
#runs unix cal program
####################################################################
#Copyright 1998 David Turley (dturley@pobox.com>                                    
#Last Modified April 13, 1998                                                         
#This script may not be resold or distributed without the author's
#express written permission.
#The current version of the script is available at
#http://www.pobox.com/~dturley/script.html
####################################################################


# set variables 
$cgi_url = './calendar2.cgi';
$cal_path = '/usr/bin/cal';

########################NOTHING TO EDIT BELOW#######################

if ($ENV{'REQUEST_METHOD'} eq "POST") {
    &parse_form(*FORM);

    $year = $FORM{'year'};
    $month = $FORM{'month'};

    ## don't let any improper input pass
    if (($year =~ /^\d{1,4}$/) && ($month =~ /^\d\d$/)) { 
        &print_calendar($month,$year);
    }

    else {
        &html_header("Improper Input");
      
        print("You have entered an invalid date.<BR>\n");
        print("Use your back button to try again");
        &html_footer;
    }
}

else { #return initial form
    &html_header("Calendar Demo");
    print <<TOP;
    <H1 ALIGN="center">Calendar Demonstration</H1>
    Select a month and enter any year in the range 1 through 9999. <P>
TOP

    &cal_form;
    
    &html_footer;
}    

exit(0);

################################################################

sub print_calendar {
    my ($month,$year) = @_;
    my (@cal,$i,$line);
    my (@month_names) = qw(January February March April May June July
                           August September October November December);
                          
    my ($sun_date,$mon_date,$tue_date,$wed_date,$thu_date,$fri_date,$sat_date);
    my ($month_str) = $month_names[$month-1];
     
    &html_header("Calendar");
    
    @cal = `$cal_path $month $year`;
   
    print <<CAL_TOP;
    <CENTER>
    <TABLE BORDER="1" CELPADDING="0" CELLSPACING="1" >
    <TR><TD COLSPAN="7" ALIGN="center" BGCOLOR="blue"><FONT COLOR="white">$month_str $year</FONT></TD></TR>
    <TR>
    <TD ALIGN="CENTER" WIDTH="35">Sun</TD>
    <TD ALIGN="CENTER" WIDTH="35">Mon</TD>
    <TD ALIGN="CENTER" WIDTH="35">Tue</TD>
    <TD ALIGN="CENTER" WIDTH="35">Wed</TD>
    <TD ALIGN="CENTER" WIDTH="35">Thu</TD>
    <TD ALIGN="CENTER" WIDTH="35">Fri</TD>
    <TD ALIGN="CENTER" WIDTH="35">Sat</TD>
CAL_TOP
    
    for ($i = 2; $i < $#cal; $i++){  #skip the first two lines
        $line = $cal[$i];
        chomp $line;
        $sun_date=substr($line,0,2);
        $mon_date=substr($line,3,2);
        $tue_date=substr($line,6,2);
        $wed_date=substr($line,9,2);
        $thu_date=substr($line,12,2);
        $fri_date=substr($line,15,2);
        $sat_date=substr($line,18,2);
        
        print "<TR>";
        print "<TD ALIGN=\"center\">$sun_date</TD>";
        print "<TD ALIGN=\"center\">$mon_date</TD>";
        print "<TD ALIGN=\"center\">$tue_date</TD>";
        print "<TD ALIGN=\"center\">$wed_date</TD>";
        print "<TD ALIGN=\"center\">$thu_date</TD>";
        print "<TD ALIGN=\"center\">$fri_date</TD>";
        print "<TD ALIGN=\"center\">$sat_date</TD>";
        print "</TR>";
    
    }
    
    print "</TABLE></CENTER><P>";
    print "<HR><B>Try another date:</B><P>";
    
    &cal_form;
    &html_footer;
    
}

sub html_header {
    my ($document_title) = $_[0];
    print "Content-type: text/html\n\n";
    print "<HTML><HEAD>\n";
    print "<TITLE>$document_title</TITLE></HEAD>\n";
    print "<BODY BGCOLOR=\"#ffffff\">\n";
}

sub html_footer {
    print "</BODY></HTML>"; 
}


sub parse_form {
    local (*FORM) = @_;

    local ( $request_method, $query_string, @key_value_pairs,
           $key_value, $key, $value);

    $request_method = $ENV{'REQUEST_METHOD'};

    if ($request_method eq "GET") {
        $query_string = $ENV{'QUERY_STRING'};
    } elsif ($request_method eq "POST") {
        read (STDIN, $query_string, $ENV{'CONTENT_LENGTH'});
    } else {
        &return_error (500, "Server Error",
                       "Server uses unsupported method");
    }

    @key_value_pairs = split (/&/, $query_string);

    foreach $key_value (@key_value_pairs) {
        ($key, $value) = split (/=/, $key_value);
        $value =~ tr/+/ /;
        $value =~ s/%([\dA-Fa-f][\dA-Fa-f])/pack ("C", hex ($1))/eg;
        $value =~ s/<!--(.|\n)*-->//g;  #removes any server side includes
        $value =~ s/[;><&\*`\|]//g;     #removes dangerous characters
        $value =~ s/^\s+//;             #remove any leading spaces
        $value =~ s/\s+$//;             #remove any trailing spaces

        if (defined($FORM{$key})) {
            $FORM{$key} = join ("\0", $FORM{$key}, $value);
        } else {
            $FORM{$key} = $value;
        }
    }
}

sub return_error {
    local ($status, $keyword, $message) = @_;

    print "Content-type: text/html", "\n";
    print "Status: ", $status, " ", $keyword, "\n\n";

    print <<End_of_Error;

<title>CGI Program - Unexpected Error</title>
<h1>$keyword</h1>
<hr>$message</hr>
Please contact the site administrator for more information.

End_of_Error

    exit(1);
}

sub cal_form {
    print <<CAL_FORM;
    
    <FORM ACTION="$cgi_url" METHOD=POST>
    Enter a month:&nbsp;&nbsp;
    <SELECT NAME="month">
    <OPTION VALUE="01"> January
    <OPTION VALUE="02"> February
    <OPTION VALUE="03"> March
    <OPTION VALUE="04"> April
    <OPTION VALUE="05"> May
    <OPTION VALUE="06"> June
    <OPTION VALUE="07"> July
    <OPTION VALUE="08"> August
    <OPTION VALUE="09"> September
    <OPTION VALUE="10"> October
    <OPTION VALUE="11"> November
    <OPTION VALUE="12"> December
    </SELECT>&nbsp;&nbsp;
    Enter a year:&nbsp;&nbsp;
    <INPUT TYPE = "text" NAME="year" SIZE=10>&nbsp;&nbsp;
    <INPUT TYPE= "submit" VALUE= "Show Me">
    </FORM>
    <HR>
    <P>Script by <A HREF="mailto:dturley\@pobox.com">David Turley</A><BR>
    <A HREF="http://www.pobox.com/~dturley/">My Home Page...</A>
    
CAL_FORM

}
    
