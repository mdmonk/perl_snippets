#!/usr/bin/perl
#
# Print out system information to monitor the box over the web
# Written by James M. Rogers, June 1998
#

use strict;
use CGI;

# Create a new instance of a CGI.
my $query = new CGI;

sub command {

my $line;

    # Print out the title.
    print "<B><P> ***** $_[0] *****</B></P>\n";

    # Print out the result of the command.
    print"<PRE>\n";
    open(INPUT, "$_[1] |") or die "$_[0] failed.";
    while ($line=<INPUT>) {
        # Replace < and > with a * to not confuse the html interpreter.
        $line =~ s/</\&lt/g;
        $line =~ s/>/\&gt/g;
        print $line;
    }
    print "</PRE>\n";
    close (INPUT);
}  # end command

# Send a MIME header.
print $query->header("text/html");

# Send a title.
print $query->title("System Stats");

# Begin HTML output.
print "<H1>Snap Shot</H1>\n";

# The list of commands to display.
# Format is title followed  by the command to execute.

command ("Memory Information", "\/usr\/bin\/free");
command ("Uptime", "\/usr\/bin\/uptime");
command ("Processes", "\/bin\/ps\ aux");
command ("Network Ports", "\/bin\/netstat\ -a");
command ("Network Condition", "\/bin\/netstat\ -i");
command ("Network Interfaces", "\/sbin\/ifconfig");
command ("Network Routes", "\/sbin\/route");
command ("Boot Info", "\/bin\/dmesg");
command ("Mounted", "\/bin\/df");
command ("Finished", "");

# End the HTML.
print $query->end_html;

exit;
