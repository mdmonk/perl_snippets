#!/usr/bin/perl

# qsmon.cgi  -  QUAKE SERVER MONITOR  -  version 1.3.1
# =========================================================================
# qsmon.cgi is a Perl CGI program that queries a Quake server (using qstat)
# and then formats the results and outputs them as a HTML document.
# The list of Quake servers may be hard-coded into this program or input
# via CGI (either hard-coded into the hyperlink or entered from a form).
# If no servers are given, a form is returned so the user can enter a
# server.
#
# To use the built-in form, just call this program directly from a
# hyperlink (i.e. http://www.my.host/cgi-bin/qsmon.cgi).
#
# To force the user to monitor only a certain list of servers, either
# edit the '@QuakeServers' variable below, or use a hyperlink that
# specifies the server(s) by appending the URL to qsmon with a '?'
# and the list of servers seperated by commas.  Here's an example:
#
# <A HREF="http://www.my.host/cgi-bin/qsmon.cgi?207.49.0.5,207.49.0.6">
# Click here to check the Wasatch Fault Quake servers</A>
#
# You can create your own form interface to this program by using
# these settings:  Form action should be the URL to this script, The
# input name for entering the Quake server(s) should be
# 'QuakeServers'.  Here's an example:
#
# <FORM METHOD="post" ACTION="http://www.my.host/cgi-bin/qsmon.cgi">
# Quake Server(s): <INPUT TYPE="text" NAME="QuakeServers">
# (For checking multiple servers, seperate the adressess by commas.)
# </FORM>
#
# NOTE: This script uses the ".cgi" extension because many HTTP (WWW)
#       servers use this extension to recognize CGI programs that may be
#       safely and securely run by the HTTP server.  Depending on your
#       HTTP server, you may have to change the extension to something
#       else.  The HTTP server may also require that you place all CGI
#       programs in a special directory which you may or may not have
#       access to (i.e. "cgi-bin").  For example, some NT HTTP servers
#       prefer to use a ".pl" extension (so it knows it's a Perl script)
#       and put the script in a special directory (like "cgi-shl").
#       You may need to consult your web master and/or the documentation
#       for your HTTP server to learn how it prefers to access Perl CGI
#       scripts or CGI programs in general.
#
#
#   REVISION HISTORY
# ====================
#
# 1.3.1 - Fixed a small bug that would sometimes cause the
#         cell background color to not be set for shirt/pants.
#
# 1.3 - Added timeout (server not responding) and 0 players 
#	check with associated HTML output.
#
# 1.2 - Added support for extended teamplay modes including
#       capture the flag.
#
# 1.1  Added sorting (ordering) of players by frags.
#
# 1.0  First release.
#
#
# Written October 1996 by Kris Nosack 
# E-mail: knosack@park.uvsc.edu
# URL:    http://www.park.uvsc.edu/~knosack
#
# A special acknowledgment goes to Steve Jankowski, the author of
# qstat.  His qstat program is what does the real work of querying
# the Quake servers, while this script is merely a gateway to the WWW.
# You must use qstat version 1.5 or higher with this script.
#
# qstat
# Written by: Steve Jankowski
# E-mail:     steve@activesw.com
# URL:        http://www.activesw.com/people/steve/qstat.html
#
#
#----------------------------------------------------------------------
# Configuration and intialization - you may need to change these.
# If you'd like to force this program to monitor only certain Quake
# servers, uncomment the following line and add the IP address(es) or
# host name(s) of the Quake servers to the list. 
@QuakeServers = ('207.54.133.19:27912');

# Colors and background settings for the web pages.
$BodyArgs = "BGCOLOR=\"#000000\" TEXT=\"#ffffff\" LINK=\"#999999\" VLINK=\"#999999\" ALINK=\"#999999\"";

# Web page table parameters.
$TableArgs = 'BORDER=1 CELLSPACING=0 CELLPADDING=5';

# If your HTTP server doesn't automatically add your cgi-bin directory
# to the Perl include path, or if you are putting this script in a
# other than cgi-bin, then uncomment and edit the "push..." line below.
# NOTE: This didn't seem to work under NT so you'll need to use the full
# path to qstat (see next item below).
# push(@INC,'/usr/local/etc/httpd/cgi-bin');

# qstat path.  If you put this script and qstat in a directory that
# Perl can find (see above), you should be able to just call qstat like
# this: "./qstat".  If this doesn't work or when in doubt, just use
# the full path to qstat like this: "/users/quake-guy/cgi-bin/qstat" (unix)
# or "C:/www/quake-guy/cgi-shl/qstat" (NT).  Be sure to use forward
# slashes no matter what OS you're running under.
$QstatPath = "./qstat";

# The URL for this script.  Most HTTP servers will set the
# environment variables SERVER_NAME and SCRIPT_NAME which can be used
# to construct the script's URL.  If this doesn't work, then just go
# ahead and use a hard-coded URL like this:  
# $ScriptURL = 'http://www.my.host/cgi-bin/qsmon.cgi';
$ScriptURL = "http://$ENV{'SERVER_NAME'}$ENV{'SCRIPT_NAME'}";


#######################################################################
#  MAIN PROGRAM
#######################################################################

# First tell Perl to bypass the buffer so in case the HTTP server is
# bogged down we won't get timed-out.  Then output the 'magic' HTML
# header so that the HTTP server knows this is an HTML document.
# This will also allow us to output any debugging info to the web.
# the web and so that in the case of a bogged down server, we won't
# get timed-out. 

$! = 1;
print "Content-type: text/html\n\n";

# What to do?  If the list of Quake servers is set in this program,
# use them.  If a list of servers is provided via CGI, use them.  If
# no servers were specified, output a form so the user can supply a
# server list.
if (!@QuakeServers) {
  $Result = &ReadParse;
  if ($Result) {
    if ($in{'QuakeServers'} ne "") {
      @Value = split(/,/, $in{'QuakeServers'});
    }
    else { @Value = split(/,/, $in); }
    foreach (@Value) { push (@QuakeServers, $_); }
  }
  else {
    &OutputForm;
  }
}

# Output the HTML header
print qq!
!;

# Do this loop for each server
foreach (@QuakeServers) {
  # Run qstat and split results into 3 groups
  split(/\n/,`$QstatPath -R -P -cn -tsw -qws $_ -raw ,,`);
  $GeneralLine = shift(@_);
  $RulesLine = shift(@_);
  @PlayerLines = @_;
  # Split general and rules info into seperate array elements
  @General = split(/,,/,$GeneralLine);
  @Rules = split(/,,/,$RulesLine);

  # Check to see if the server is not responding
  if ($General[1] eq 'TIMEOUT') {
    print qq!
    $GeneralLine
    <TABLE $TableArgs>
    <TR ALIGN="center">
    <TH><TT><FONT SIZE=+2>$_ Not Responding</FONT></TT></TH>
    </TR>
    <TR ALIGN="center">
    <TD>The Quake server at <B>$_</B> did not respond. The server may be down or only
    temporarily unreachable.</TD>
    </TR>
    </TABLE>
    <HR>

    !;
    next;
  }

  # Output header for general info table
  print qq!
  !;
  # Output header for player info table
  print qq!
  !;

  # Check to see if there's more than 0 players
  if ($General[5] == 0) {
    print "<TR ALIGN=\"center\"><TD COLSPAN=6>No Players</TD></TR>\n";
  }
  else {
    # Sort the players by frags
    foreach $I (0 .. $#PlayerLines) {
      ($Num[$I], $Name[$I], $Address[$I], $Frags[$I], $TheRest[$I]) = split(/,,/, $PlayerLines[$I]);
      $Frags[$I] = $Frags[$I] . ".$I";
    }
    @Name = ();
    @Address = ();
    @TheRest = ();
    @SortedFrags = sort {$b <=> $a} @Frags;
    @Frags = ();
    @SortedPlayerLines = ();
    foreach $I (0 .. $#SortedFrags) {
      ($Frags, $Index) = split(/\./, $SortedFrags[$I]);
      push (@SortedPlayerLines, $PlayerLines[$Index]);
    }

    # Ouput the player table data
    foreach (@SortedPlayerLines) {
      @Player = split(/,,/,$_);
      # manipulate a few results
      $PlayerNumber = ++$Player[4];
      $ShirtColor = &Quake2WebColor($Player[5]);
      $PantsColor = &Quake2WebColor($Player[6]);
      $ShirtTextColor = &TextColor($Player[5]);
      $PantsTextColor = &TextColor($Player[6]);

      # Output a table row for each player
      print qq!
      !;
    }
  }
  # Close the table
  print qq!
  !;

  # Open rules info table
  
  # Ouput the rules table data
  @Settings = ();  # clear the array
  foreach (@Rules) {
    ($Properties, $Setting) = split (/=/, $_);
    push (@Settings, $Setting);
  }
  # Bold non-default settings and change some to be more descriptive
  if ($Settings[7] == 1) { $Settings[0] = 'Yes'; }
  elsif ($Settings[7] == 0) { $Settings[7] = 'No'; }
  if ($Settings[1] == 16) { $Settings[1] = 'Default'; }
  if ($Settings[2] == 0) { $Settings[2] = 'None'; }
  if ($Settings[3] == 0) { $Settings[3] = 'None'; }
#  elsif ($Settings[3] == 1) { $Settings[3] = '<B>No</B>'; }
#  elsif ($Settings[3] == 2) { $Settings[3] = '<B>No, except start</B>'; }
  $Modified = 0;
  if ($Settings[7] == 1) { $Teamplay = 'None'; }
  elsif ($Settings[7] < 1) {
    # Probably a modified teamplay server - these are for Zoid's CTF patch
    $Modified = 1;
    if ($Settings[4] >= 1024) {
      $Teamplay = "<B>Choose Team</B><BR>\n";
      $Settings[4] = $Settings[4] - 1024;
    }
    if ($Settings[4] >= 512) {
      $Teamplay = "<B>Custom Client</B><BR>\n";
      $Settings[4] = $Settings[4] - 512;
    }
    if ($Settings[4] >= 256) {
      $Teamplay = $Teamplay . "<B>Capture the Flag</B><BR>\n";
      $Settings[4] = $Settings[4] - 256;
    }
    if ($Settings[4] >= 128) {
      $Teamplay = $Teamplay . "<B>Drop Items</B><BR>\n";
      $Settings[4] = $Settings[4] - 128;
    }
    if ($Settings[4] >= 64) {
      $Teamplay = $Teamplay . "<B>Static Teams</B><BR>\n";
      $Settings[4] = $Settings[4] - 64;
    }
    if ($Settings[4] >= 32) {
      $Teamplay = $Teamplay . "<B>Color Lock</B><BR>\n";
      $Settings[4] = $Settings[4] - 32;
    }
    if ($Settings[4] >= 16) {
      $Teamplay = $Teamplay . "<B>Death Penalty</B><BR>\n";
      $Settings[4] = $Settings[4] - 16;
    }
   if ($Settings[4] >= 8) {
      $Teamplay = $Teamplay . "<B>Frag Penalty</B><BR>\n";
      $Settings[4] = $Settings[4] - 8;
    }
    if ($Settings[4] >= 4) {
      $Teamplay = $Teamplay . "<B>Damage to Attacker</B><BR>\n";
      $Settings[4] = $Settings[4] - 4;
    }
    if ($Settings[4] >= 2) {
      $Teamplay = $Teamplay . "<B>Armor Protect</B><BR>\n";
      $Settings[4] = $Settings[4] - 2;
    }
    if ($Settings[4] >= 1) {
      $Teamplay = $Teamplay . "<B>Health Protect</B>";
    }
  }
  else {
    # Probably just a normal (unmodified) teamplay server
    if ($Settings[4] == 1) { $Teamplay = '<B>Cannot hurt<BR>teamates</B>'; }
    elsif ($Settings[4] == 2) { $Teamplay = '<B>Can hurt<BR>teamates</B>'; }
  }
#  if ($Settings[5] == 0) { $Settings[5] = 'None'; }
#  else { $Settings[5] = '<B>' . $Settings[5] . '</B>'; }
#  if ($Settings[6] == 0) { $Settings[6] = 'None'; }
#  else { $Settings[6] = '<B>' . $Settings[6] . '</B>'; }
  # Output a table row for each variable
  
}  # End of server stats loop

# Output the entire dynamic HTML stuff
print qq!
<HEAD>
<TITLE>Quake II Server Status</TITLE>
</HEAD>
<BODY $BodyArgs>
<CENTER>
<br><br>
<br><br>
<center>
<table width=500 border=0>
<tr>
<td>


<b>Name</b>: $General[2]<br><br>
<b>Server IP</b>: $General[1]<br><br>
<b>Game Type:</b> $Settings[0] <br><br>
<b>Dmflags:</b> $Settings[1] <br><br>
<b>Timelimit:</b> $Settings[2] <br><br>
<b>Fraglimit:</b> $Settings[3] <br><br>
<b>Players / Max</b>: $General[5] / $General[4]<br><br>
<b>Ping / Timeout</b>: $General[6] / $General[7]<br><br>
<b>Map</b>: $General[3]<br><br>
<b>Map Image</b>: <img src=http://quake.medina.net/data/$General[3].jpg align=top>

  <td valign=top>
  <center><font size=+1><b>Players</b></font></center>
  <TABLE $TableArgs valign=top width=100%>
  <TR ALIGN="center">
  <TR>
  <td width=30>Frags</td>
  <td width=30>Ping</td>
  <td width=190>Name</td>
  </TR>
!;

  # Check to see if there's more than 0 players
  if ($General[5] == 0) {
    print "<TR ALIGN=\"center\"><TD COLSPAN=6>No Players</TD></TR>\n";
  }
  else {
    # Sort the players by frags
    foreach $I (0 .. $#PlayerLines) {
      ($Num[$I], $Name[$I], $Address[$I], $Frags[$I], $TheRest[$I]) = split(/,,/, $PlayerLines[$I]);
      $Frags[$I] = $Frags[$I] . ".$I";
    }
    @Name = ();
    @Address = ();
    @TheRest = ();
    @SortedFrags = sort {$b <=> $a} @Frags;
    @Frags = ();
    @SortedPlayerLines = ();
    foreach $I (0 .. $#SortedFrags) {
      ($Frags, $Index) = split(/\./, $SortedFrags[$I]);
      push (@SortedPlayerLines, $PlayerLines[$Index]);
    }

    # Ouput the player table data
    foreach (@SortedPlayerLines) {
      @Player = split(/,,/,$_);
      # manipulate a few results
      $PlayerNumber = ++$Player[4];
      $ShirtColor = &Quake2WebColor($Player[5]);
      $PantsColor = &Quake2WebColor($Player[6]);
      $ShirtTextColor = &TextColor($Player[5]);
      $PantsTextColor = &TextColor($Player[6]);

    }
      # Output a table row for each player
      print qq!
      <TR>
      <TD>$Player[1]</TD>
      <TD>$Player[2]</TD>
      <TD ALIGN="center">$Player[0]</TD>
      </TR>
      !;

}

print qq!
</TABLE>
</table>
</CENTER>
!;

if (! $Modified) {
   print "\n\n";
}
else {
   print "\n\n";
}


exit;
# End of the main program


#--------------------------------------------------------------------
#  SUBROUTINES
#--------------------------------------------------------------------

# Display the form for entering Quake server(s)
sub OutputForm
{
  print qq!
  <HTML>
  <HEAD>
  <TITLE>Quake Server Monitor</TITLE>
  </HEAD>
  <BODY $BodyArgs>
  <CENTER>
  <H2>Quake Server Monitor</H2>
  <HR>
  <FORM METHOD="post" ACTION="$ScriptURL">
  <P><B>Quake Server(s):</B>
  <INPUT TYPE="text" NAME="QuakeServers" SIZE=60>
  </FORM>
  </CENTER>
  <P>To see what's happening on a Quake server, enter the IP address
  (<I>i.e. 207.49.0.5</I>) or host name
  (<I>i.e. quake1.wasatchfault.com</I>) of a Quake server in the text
  box above and then press 'Enter' (the key on your keyboard).
  To monitor multiple servers, seperate the servers by commas
  (<I>i.e. 207.49.0.5,207.49.0.6</I>).</P>
  </BODY>
  </HTML>!;
  exit;
}


# Convert a Quake color to a Netscape RGB color for shirt and pants color
sub Quake2WebColor {
  local($QuakeColor) = @_;
  # remove any linefeeds
  $QuakeColor =~ s/\n$//g;
  if ($QuakeColor eq 'White') {$WebColor = '#FFFFFF';}
  elsif ($QuakeColor eq 'Brown') {$WebColor = '#503818';}
  elsif ($QuakeColor eq 'Lavender') {$WebColor = '#9F5F9F';}
  elsif ($QuakeColor eq 'Khaki') {$WebColor = '#9F9F5F';}
  elsif ($QuakeColor eq 'Red') {$WebColor = '#8C0000';}
  elsif ($QuakeColor eq 'Lt Brown') {$WebColor = '#A65050';}
  elsif ($QuakeColor eq 'Peach') {$WebColor = '#DB7575';}
  elsif ($QuakeColor eq 'Lt Peach') {$WebColor = '#DC8F8F';}
  elsif ($QuakeColor eq 'Purple') {$WebColor = '#CC3299';}
  elsif ($QuakeColor eq 'Dk Purple') {$WebColor = '#871F78';}
  elsif ($QuakeColor eq 'Tan') {$WebColor = '#DB9370';}
  elsif ($QuakeColor eq 'Green') {$WebColor = '#215E21';}
  elsif ($QuakeColor eq 'Yellow') {$WebColor = '#FFFF00';}
  elsif ($QuakeColor eq 'Blue') {$WebColor = '#3232CD';}
}


# Use black text on light colors and vice versa
sub TextColor {
  local($QuakeColor) = @_;
  # remove any linefeeds
  $QuakeColor =~ s/\n$//g;
  @LightColors = ('White','Lavender','Khaki','Lt Brown','Peach','Lt Peach','Tan','Yellow');
  foreach (@LightColors) {
    if ($QuakeColor eq $_) {
      return '#000000';
    }
  }
  return '#FFFFFF';
}

# ReadParse
# Reads in GET or POST data, converts it to unescaped text, and puts
# one key=value in each member of the list "@in"
# Also creates key/value pairs in %in, using '\0' to separate multiple
# selections

# Returns TRUE if there was input, FALSE if there was no input 
# UNDEF may be used in the future to indicate some failure.

# Now that cgi scripts can be put in the normal file space, it is useful
# to combine both the form and the script in one place.  If no parameters
# are given (i.e., ReadParse returns FALSE), then a form could be output.

# If a variable-glob parameter (e.g., *cgi_input) is passed to ReadParse,
# information is stored there, rather than in $in, @in, and %in.

sub ReadParse {
  local (*in) = @_ if @_;
  local ($i, $key, $val);

  # Read in text from form
  if ($ENV{'REQUEST_METHOD'} eq "GET") {
    $in = $ENV{'QUERY_STRING'};
  } elsif ($ENV{'REQUEST_METHOD'} eq "POST") {
    read(STDIN,$in,$ENV{'CONTENT_LENGTH'});
  }

  # Read in query from ISINDEx
  if ($ENV{'HTTP_SEARCH_ARGS'} ne "") { $in = $ENV{'HTTP_SEARCH_ARGS'}; }

  @in = split(/&/,$in);

  foreach $i (0 .. $#in) {
    # Convert plus's to spaces
    $in[$i] =~ s/\+/ /g;

    # Split into key and value.  
    ($key, $val) = split(/=/,$in[$i],2); # splits on the first =.

    # Convert %XX from hex numbers to alphanumeric
    $key =~ s/%(..)/pack("c",hex($1))/ge;
    $val =~ s/%(..)/pack("c",hex($1))/ge;

    # Associate key and value
    $in{$key} .= "\0" if (defined($in{$key})); # \0 is the multiple separator
    $in{$key} .= $val;

  }

  return length($in); 
}
