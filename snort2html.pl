#!/usr/bin/perl -w
#
#  Snort2HTML 1.1 by Dan Swan, March 13, 00.
#  Special thanks to Martin Roesch for writing a friendly, kickass NIDS, 
#  and to Max Vision for the use of his attack signatures database.
#
#  Distribute and modify freely, but give credit where credit is due!
#
#  If you appreciate this product, and would like to give something back, send
#  me the url to your snort logs.  The information will be seen by nobody
#  but myself, and will not be used for malicious purposes.
#
#  INSTALLATION:  Place this file in /usr/local/bin.  To update webpage regularly, 
#                 paste the following quoted text into /etc/cron.hourly/snortupdate:  
#                 "/usr/local/bin/snort2html", and make sure both  files are executable.
#
#                 Also, snort MUST be run with -s option for this program to work.
#
#  WARNING:  You should consider placing this file into a password protected directory 
#            on your web server, or simply not putting a link on your default page.    
#            After all, do you really want strangers to be able to tell what shows up 
#            (and what doesn't show up) in your logs?

#  TODO:  -Display service on Target port 
#         -More color coding of source port (suggestions welcome!)
#         -A cgi wrapper to update page when accessed.
#         -Dynamic sorting by clicking on column header.
#         -Command line flags to control formatting

#  NOTE:  I am interested in any suggestions on improving the code, features 
#         you'd like to see, or tips on making the output more lynx-freindly.    
#         Please send them to swan_daniel@hotmail.com
#
#  CHANGES:
#
#  1.1
#  - Changed <TD><B> to <TH>, fixed perms on outputfile, other minor cosmetic
#    changes as suggested by Ralf Hildebrandt.
#  - Fixed problem parsing ICMP alerts, optimized code for speed (~10% gain) 
#    using patch provided by Nico Erfuth.
#

use Socket;
use POSIX qw(strftime);
use Sys::Hostname;

$logfile="/var/log/secure";   # Change this variable to specify different logfile
$hostname=hostname();
$outputfile="/home/httpd/html/snort2html.html";  # HTML file the log will be outputted to
$MASQHOST=0;    
$time = strftime "%b %d at %H:%M", localtime;

##############################
#          Main              #
##############################

&generatehtmlheader;          # Call funtion to generate HTML header

open(LOG,"$logfile") || die "Unable to open $logfile"; 
my @log = <LOG>;  # Read whole file into big array
close LOG;
chomp @log;
foreach (@log) {
                if ( !  /.*snort*/ )     # If it ain't got the word snort in it...
                                  {                        
                                  next ;                   # ...get me another line.
                                  }

/(.*\s[1-9]*)(\d+\s)(..:..:..\s)(.*:\s)(.*:\s)(.*\d\s)(.*\s)(.*)/;  # Pattern matching against each line read from logfile

# Variables extracted from pattern matching above.
$month=$1;   
$day=$2;
$timeofday=$3;
$hour=$3;
$attack=$5;
$sourceip=$6;
$sourceport=$6;
$targetip=$8;
$targetport=$8;

# Get rid of unwanted characters
$attack=~s/://;
$sourceip=~ s/:.*//;
$hour=~ s/:.*//;
if (!($sourceport =~ s/.*://)) {$sourceport = "-N/A-"};
$sourcehost=gethostbyaddr(inet_aton($sourceip), AF_INET);
$targetip=~ s/:.*//;
if (!($targetport =~ s/.*://)) {$targetport = "-N/A-"};
$targethost=gethostbyaddr(inet_aton($targetip), AF_INET);
$searchattack=$attack;
$searchattack=~ s/\s/+/g;
chop $searchattack;

&timecolor;
&generatehtmlbody    # Generate body of HTML from data read from snortlog
             }

&generatehtmlfooter;   # Generate footer of HTML

chmod (0644, $outputfile);  # Ensure that output file is world readable


#############################################################
####################Subroutines##############################
#############################################################

sub generatehtmlheader {   #Deletes old HTML file, creates new ones, and writes headings.
                        unlink $outputfile;
                        open (HTML, ">$outputfile");
                        print HTML "<HTML>\n";
                        print HTML "<HEAD>\n";
                        print HTML "<TITLE>Hot dog!  Jumping frog!  Its an html2snort log! </TITLE>\n";
                        print HTML "</HEAD>\n";
                        print HTML "<BODY BGCOLOR=\"#AAAAAA\">\n";
                        print HTML "<H1 align=center>Snort log for $hostname</H1>\n";
                        print HTML "<TABLE border>\n";
                        print HTML "<TR>\n";
                        print HTML "<TH>Date</TH>\n";
                        print HTML "<TH>Time</TH>\n";
                        print HTML "<TH>Attack</TH>\n";
                        print HTML "<TH>Source Host</TH>\n";
                        print HTML "<TH>Source Port</TH>\n";
                        print HTML "<TH>Target Host</TH>\n";
                        print HTML "<TH>Target Port</TH>\n";
                        print HTML "</TR>\n";
                        }

sub timecolor {  # Color code time of day according to daytime, evening, and nighttime.
               my $result = int($hour/6);
               if ($result == 0) {$hourcolor = "#000000"; }
               elsif ($result < 3)  {$hourcolor = "#EEEE00"; }
               else {$hourcolor = "#FFCC00"; };
                 }

sub generatehtmlbody {      #   Writes fields to html file.
                      print HTML "<TR>\n";
                      print HTML "<TD><B>$month $day</B></TD>\n";
                      print HTML "<TD><B><FONT COLOR=\"$hourcolor\">$timeofday</font></B></TD>\n";
                      print HTML "<TD>&nbsp\;<A href=\"http://dev.whitehats.com/cgi/test/new.pl/Search?search=$searchattack\">$attack</A></TD>\n";
                      print HTML "<TD>&nbsp\;<A HREF=\"http://www.arin.net/cgi-bin/whois.pl?queryinput=$sourceip&B1=Submit\">", $sourcehost || $sourceip, "</A></TD>\n";
                      if (($sourceport ne "-N/A-") && ($sourceport>61000) && ($sourceport<65096)) {
                                                                       $sourceportcolor="#006600";
                                                                       $MASQHOST=1; 
                                                                       }
                      else {$sourceportcolor="#000000";}
                      print HTML "<TD>&nbsp\;<font color=\"$sourceportcolor\">$sourceport</font></TD>\n";
                      print HTML "<TD>&nbsp\;", $targethost || $targetip, "</TD>\n";
                      print HTML "<TD>&nbsp\;$targetport</TD>\n";
                      print HTML "</TR>\n";
                      } 
sub generatehtmlfooter {  # Writes end of HTML tags, and closes filehandle.
                        print HTML "</TABLE>\n";
                        if ( $MASQHOST ne "0" ) # Need to include masqsourceport explanation at end??
                                               {
                                                print HTML "<TABLE noborder><TR><TD WIDTH=4 ALIGN=left VALIGN=top BGCOLOR=\"#006600\"><font color= \"#006600\">DS</font></TD>
                                                <TD align=left>=Possible masquerading host.</TD></table>\n";
                                                }
                        print HTML "<BR><HR>\n";
                        print HTML "This page generated from <A HREF=\"http://www.clark.net/~roesch/security.html\">snort</A>
                        logs on $time using snort2html by <A HREF=\"mailto:swan_daniel\@hotmail.com\">Dan Swan</A>.<BR>\n";
                        print HTML "</BODY>\n";
                        print HTML "</HTML>\n";
                        close (HTML);
                        }      

