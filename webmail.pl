<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML><HEAD>
<META content="text/html; charset=windows-1252" http-equiv=Content-Type></HEAD>
<BODY><XMP>#!/usr/bin/perl
$| = 1;

################################################
# Version 2.1   Dec 29                         #
# I think I took care of the authentication    #
# problems.  Everyone with a valid u/p should  #
# be able to login, regardless of the number of#
# messages they have.  Let me know if you see  #
# any problems.                                #
#                                              #
# Still to do: HTML formatting in message body #
# Clean up alot of the message dumps           #
#==============================================#
# Webmail utility to check mail using regular  #
# Pop mail, sends via SMTP.  All you should    #
# have to configure is the $popserver,         # 
# $smtpserver, $hostname, and $cgibinlocation  #
# variables.                                   #
#                                              #
# by Jason Woodward <woodwardj@jaos.org>       #
################################################

$hostname = '';
$popserver = '';
$smtpserver = '';
$cgibinlocation = '/cgi-bin';

##############end configure#####################
use CGI qw(:standard);
use Mail::POP3Client;
use Socket;

my $username = param("username");
my $password = param("password");
my $dowhat = param("dowhat");
my $messnum = param("messnum");
my $to = param("to");
my $from = param("from");
my $subject = param("subject");
my $mbody = param("mbody");

if ($username eq "" && $password eq "") {
	&login();
} elsif ($dowhat eq "") {
	&login();
} elsif ($dowhat eq "login") {
	&login();
} elsif ($dowhat eq "listmessages") {
	&listmessages();
} elsif ($dowhat eq "readmessage") {
	&readmessage();
} elsif ($dowhat eq "createmessage") {
	&createmessage();
} elsif ($dowhat eq "replymessage") {
	&replymessage();
} elsif ($dowhat eq "deletemessage") {
	&deletemessage();
} elsif ($dowhat eq "sendmessage") {
	&sendmessage();
} elsif ($dowhat eq "forwardmessage") {
	&forwardmessage();
} else { 
&errno("ERROR!! NOTHING TO DO");
}


sub login {
print STDOUT "Content-type: text/html\n";
print STDOUT qq!
<HTML><HEAD><TITLE>$hostname - Webmail</TITLE>
</HEAD><BODY bgcolor="#ffffff">
<TABLE width="100%" cellpadding=2 cellspacing=0 border=0 bgcolor="#006699"> <TR>
<TD><FONT color=FFFFFF size=4><B>$hostname - Mail Login</a></B></FONT></TD></TR></TABLE>
<p><p><p><p><br>
<FORM ACTION="$cgibinlocation/webmail.pl" METHOD=POST>
<input type=hidden name="dowhat" value="listmessages">
<b>Username: <br></b><INPUT TYPE="text" NAME="username"><br>
<b>Password: <br></b><INPUT TYPE="password" NAME="password"><br>
<input type="submit" value="login"><p>
</FORM><p><p>
!;
}



sub listmessages {
$pop2 = new Mail::POP3Client( HOST  => "$popserver", AUTH_MODE => 'PASS' );
$pop2->User( "$username" );
$pop2->Pass( "$password" );
$pop2->Connect() and $pop2->POPStat();
my $servermessage = $pop2->Message;
if ($servermessage =~ m/ERR/) {
	&errno("Login Failed");
} else {
print STDOUT "Content-type: text/html\n";
print STDOUT qq!
<HTML><HEAD><TITLE>$hostname - Webmail</TITLE>
</HEAD><BODY bgcolor="#ffffff"><p><br>
<TABLE width="100%" cellpadding=2 cellspacing=0 border=0 bgcolor="#006699"><TR>
<TD><FONT color=FFFFFF size=4><B>Current Mail Messages</B></FONT></TD></TR></TABLE>
<table cellspacing="1" cellpadding="0" width="100%">
<tr bgcolor=#cccccc>
<td><font size="3"><b>Message</b></font></td>
<td><font size="3"><b>From</b></font></td>
<td><font size="3"><b>Subject</b></font></td>
<td><font size="3"><b>Date</b></font></td>
<td><font size="3"><b>Delete</b></font></td></tr>!;
$maxnumofmess = $pop2->Count();
chop($maxnumofmess);
for ($i = 1; $i <= $pop2->Count(); $i++) {
my $from = '';
my $subject = '';
my $dateofmess = '';
foreach ($pop2->Head ( $i )) {
$from = $_ if (/From:\s+/i);
$subject = $_ if (/Subject:\s+/i);
$dateofmess = $_ if (/Date:\s+/i);
$dateofmess = substr($dateofmess, 0, 22);
}
$subject =~ s/Subject://i;
$from =~ s/From://i;
$dateofmess =~ s/Date://i;
print STDOUT qq!
<tr valign=TOP><td valign=TOP><a href="$cgibinlocation/webmail.pl?username=$username&password=$password&dowhat=readmessage&messnum=$i">
Message $i</a></td>
<td><b>FROM:</b> $from</td> 
<td><b>Subject:</b> $subject</td>
<td><b>On:</b> $dateofmess</TD>
<td><a href="$cgibinlocation/webmail.pl?username=$username&password=$password&dowhat=deletemessage&messnum=$i"><img src="/images/delete.gif" border="0"></td></tr>
!;
}
$pop2->Close;
print STDOUT qq!
</table>
<table width="10%"><TR>
<TD><FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="createmessage">
<input type="submit" value="New Message"></FORM></TD>
<TD><FORM ACTION="$cgibinlocation/webmail.pl" METHOD=POST>
<input type=hidden name="dowhat" value="listmessages">
<INPUT TYPE="hidden" NAME="username" value="$username">
<INPUT TYPE="hidden" NAME="password" value="$password">
<input type="submit" value="Refresh"></FORM></TD>
<TD><FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="dowhat" value="login">
<input type="submit" value="Logout"></FORM></TD></TR></table>
!;
}}

sub readmessage {
$pop = new Mail::POP3Client( HOST  => "$popserver", AUTH_MODE => 'PASS');
$pop->User( "$username" );
$pop->Pass( "$password" );
$pop->Connect() || &errno("Could not login!");
print STDOUT "Content-type: text/html\n";
print STDOUT qq!
<HTML><HEAD><TITLE>$hostname - Webmail</TITLE>
</HEAD><BODY bgcolor="#ffffff">
!;
my $from = '';
my $subject = '';
foreach ($pop->Head ( $messnum )) {
$from = $_ if (/From:\s+/i);
$subject = $_ if (/Subject:\s+/i);
}
$subject =~ s/Subject://i;
$from =~ s/From://i;
$from =~ s/"//g;
my $nextmessnum = $messnum + 1;
my $prevmessnum = $messnum - 1;
print STDOUT qq!
<table width="10%"><TR>
<TD><FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="to" value="$from">
<input type="hidden" name="subject" value="Re: $subject">
<input type="hidden" name="username" value='$username'>
<input type="hidden" name="password" value="$password">
<input type="hidden" name="messnum" value="$messnum">
<input type="hidden" name="dowhat" value="replymessage">
<input type="submit" value="Reply"></FORM></TD>
<TD><FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="subject" value="Fw: $subject">
<input type="hidden" name="dowhat" value="forwardmessage">
<input type="hidden" name="messnum" value="$messnum">
<input type="hidden" name="from" value="$from">
<input type="submit" value="Forward"></FORM></TD>
<TD><FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="deletemessage">
<input type="hidden" name="messnum" value="$messnum">
<input type="submit" value="Delete this Message"></FORM></TD>
<TD><FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="listmessages">
<input type="submit" value="Back to Messages"></FORM></TD>
!;
if ($messnum == 1) {
print STDOUT qq!
<TD><FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="readmessage">
<input type="hidden" name="messnum" value="$nextmessnum">
<input type="submit" value="Next Message"></FORM></TD></TR></TABLE>
<table cellspacing="1" cellpadding="0" width="100%">
<tr bgcolor=#cccccc>
!;
} elsif ($messnum eq $maxnumofmess) {
print STDOUT qq!
<TD><FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="readmessage">
<input type="hidden" name="messnum" value="$prevmessnum">
<input type="submit" value="Previous Message"></FORM></TD></TR></TABLE>
<table cellspacing="1" cellpadding="0" width="100%">
<tr bgcolor=#cccccc>
!;
} else {
print STDOUT qq!
<TD><FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="readmessage">
<input type="hidden" name="messnum" value="$nextmessnum">
<input type="submit" value="Next Message"></FORM></TD>
<TD><FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="readmessage">
<input type="hidden" name="messnum" value="$prevmessnum">
<input type="submit" value="Previous Message"></FORM></TD></TR></TABLE>
<table cellspacing="1" cellpadding="0" width="100%">
<tr bgcolor=#cccccc>
!;
}
print STDOUT qq!
<td><font size="3"><b>From:</b> $from</font></td>
<td><font size="3"><b>Subject:</b> $subject</font></td></tr></table><p>
<table cellspacing="1" cellpadding="0" width="100%">
<tr bgcolor=#cccccc><TD><hr>
!;
foreach ($pop->Body ( $messnum )) {
&CLEANHTML($_);
print "$_\n<br>";
}
$pop->Close;
print STDOUT qq!
</td></tr></table><p><p>
!;
}

sub createmessage {
print STDOUT "Content-type: text/html\n";
print STDOUT qq!
<HTML><HEAD><TITLE>$hostname - Webmail</TITLE>
</HEAD><BODY bgcolor="#ffffff">
<TABLE width="100%" cellpadding=2 cellspacing=0 border=0 bgcolor="#006699"> <TR>
<TD><FONT color=FFFFFF size=4><B>Send message</a></B></FONT></TD></TR></TABLE>
<p><p><br><FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="sendmessage">
To: <br><input type="text" name="to"><br>
Subject: <br><input type="text" name="subject"><br><p><hr>
<textarea name="mbody" cols=75 rows=14></textarea><br><p><br>
<input type="submit" value="Send"></FORM>
<FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="listmessages">
<input type="submit" value="Back to Messages"></FORM><p><p>
!;
}


sub replymessage {
$pop = new Mail::POP3Client( HOST  => "$popserver", AUTH_MODE => 'PASS' );
$pop->User( "$username" );
$pop->Pass( "$password" );
$pop->Connect() || &errno("Could not login!");
print STDOUT "Content-type: text/html\n";
print STDOUT qq!
<HTML><HEAD><TITLE>$hostname - Webmail</TITLE>
</HEAD><BODY bgcolor="#ffffff">
<TABLE width="100%" cellpadding=2 cellspacing=0 border=0 bgcolor="#006699"> <TR>
<TD><FONT color=FFFFFF size=4><B>Reply to $to</B></FONT></TD></TR></TABLE>
<p><p><br><FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="sendmessage">
To: <br><input type="text" name="to" value="$to"><br>
Subject: <br><input type="text" name="subject" value="$subject"><br><p><hr>
<textarea name="mbody" cols=75 rows=14>
!;
print "\n\n\n\n";
print "You wrote:  \n\n";
foreach ($pop->Body ( $messnum )) {
$_ =~ s/<[^>]*>//gs;
print ">";
print "$_\n";
}
$pop->Close;
print STDOUT qq!
</textarea><br></FONT></TD></TR><p><br>
<input type="submit" value="Send"></FORM>
<FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="listmessages">
<input type="submit" value="Back to Messages"></FORM><p><p>
!;
}

sub deletemessage {
$pop = new Mail::POP3Client( HOST  => "$popserver", AUTH_MODE => 'PASS' );
$pop->User( "$username" );
$pop->Pass( "$password" );
$pop->Connect() || &errno("Could not login!");
$pop->Delete ( $messnum);
$pop->Close;
print STDOUT "Content-type: text/html\n\n";
print STDOUT "<html>\n <head>\n  <title>$hostname - Message Deleted</title>\n </head>\n";
print STDOUT "<body bgcolor=#ffffff><!--Created by $hostname on $date-->\n";
print STDOUT "<P> <BR> </TD><TD valign=top align=left><FONT color=#000000>";
print STDOUT "<TABLE width=100% cellpadding=2 cellspacing=0 border=0 bgcolor=#006699><TR>";
print STDOUT "<TD><FONT color=FFFFFF size=4><B>Message Deleted</B></FONT></TD></TR></TABLE>";
print STDOUT qq!
<FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="listmessages">
<input type="submit" value="Back to Messages"></FORM><p>
!;
}

sub errno {
print STDOUT "Content-type: text/html\n";
my $errmsg = $_[0];
print STDOUT qq!
<HTML><HEAD><TITLE>$hostname - Webmail $errmsg</TITLE>
</HEAD><BODY bgcolor="#ffffff"><p><br>
<TABLE width="100%" cellpadding=2 cellspacing=0 border=0 bgcolor="#006699"> <TR>
<TD><FONT color=FFFFFF size=4><B>$errmsg - $hostname WebMail Login</a></B></FONT></TD></TR></TABLE>
<p><p><p><p><br>
<FORM ACTION="$cgibinlocation/webmail.pl" METHOD=POST>
<input type=hidden name="dowhat" value="listmessages">
<b>Username: <br></b><INPUT TYPE="text" NAME="username"><br>
<b>Password: <br></b><INPUT TYPE="password" NAME="password"><br>
<input type="submit" value="login"><p></FORM><p>
!;
die;
}

sub sendmessage {
$proto = getprotobyname('tcp');
socket(SERVER, AF_INET, SOCK_STREAM, $proto);
$iaddr = gethostbyname($smtpserver);
$port = getservbyname('smtp', 'tcp');
$sin = sockaddr_in($port, $iaddr);
connect(SERVER, $sin);

@to = split (/,\s/, $to);
$mbody =~ s/\n\.[\r|\n]/\n. $1/g;

send SERVER, "HELO $hostname\r\n", 0;
recv SERVER, $sreply, 512, 0;
send SERVER, "MAIL From:<$username\@$hostname>\r\n", 0;
recv SERVER, $sreply, 512, 0;
foreach $line (@to) {
send SERVER, "RCPT To:<$line>\r\n", 0;
}
recv SERVER, $sreply, 512, 0;
send SERVER, "DATA\r\n", 0;
recv SERVER, $sreply, 512, 0;
send SERVER, "Subject: $subject\r\n", 0;
send SERVER, "\r\n$mbody\r\n", 0;
send SERVER, "\r\n\r\n\r\nGet your own free E-mail account at\r\n", 0;
send SERVER, "http://www.$hostname/webmail/\r\n.\r\n", 0;
recv SERVER, $sreply, 512, 0;
send SERVER, "QUIT\r\n", 0;
recv SERVER, $sreply, 512, 0;
close SERVER;

print STDOUT "Content-type: text/html\n\n";
print STDOUT "<html>\n <head>\n  <title>$hostname - Message Sent</title>\n </head>\n";
print STDOUT "<body bgcolor=#ffffff><!--Created by $hostname on $date-->\n";
print STDOUT "<P> <BR> </TD><TD valign=top align=left><FONT color=#000000>";
print STDOUT "<TABLE width=100% cellpadding=2 cellspacing=0 border=0 bgcolor=#006699><TR>";
print STDOUT "<TD><FONT color=FFFFFF size=4><B>Message Sent</B></FONT></TD></TR></TABLE>";
print STDOUT qq!
<FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="listmessages">
<input type="submit" value="Back to Messages"></FORM><p>
!;
}

sub forwardmessage {
$pop = new Mail::POP3Client( HOST  => "$popserver", AUTH_MODE => 'PASS' );
$pop->User( "$username" );
$pop->Pass( "$password" );
$pop->Connect() || &errno("Could not login!");
print STDOUT "Content-type: text/html\n";
print STDOUT qq!
<HTML><HEAD><TITLE>$hostname - Webmail</TITLE>
</HEAD><BODY bgcolor="#ffffff">
<TABLE width="100%" cellpadding=2 cellspacing=0 border=0 bgcolor="#006699"> <TR>
<TD><FONT color=FFFFFF size=4><B>Forward message</a></B></FONT></TD></TR></TABLE>
<p><p><br><FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="sendmessage">
To: <br><input type="text" name="to"><br>
Subject: <br><input type="text" name="subject" value="$subject"><br><p><hr>
<textarea name="mbody" cols=75 rows=14>
!;
print STDOUT "\n\n\n\n";
print STDOUT "$from wrote:  \n\n";
foreach ($pop->Body ( $messnum )) {
$_ =~ s/<[^>]*>//gs;
print ">";
print STDOUT "$_\n";
}
$pop->Close;
print STDOUT qq!
</textarea><br></FONT></TD></TR><p><br>
<input type="submit" value="Send"></FORM>
<FORM ACTION="$cgibinlocation/webmail.pl" method="POST">
<input type="hidden" name="username" value="$username">
<input type="hidden" name="password" value="$password">
<input type="hidden" name="dowhat" value="listmessages">
<input type="submit" value="Back to Messages"></FORM>
!;
}

sub CLEANHTML
{
my($text) = @_;
$text =~ s/([^\s\<]+\@[^\s\r\,\;\>]+)/\%lta href\=\"mailto\:$1\"\%gt$1\%lt\/a\%gt/g;
$text =~ s/\&/\&amp\;/g;
$text =~ s/\</\&lt\;/g;
$text =~ s/\>/\&gt\;/g;
$text =~ s/\%lt/\</g;
$text =~ s/\%gt/\>/g;
$text =~ s/(http\:\S+)\s/"\<a target=\"_top\" href\=\"$1\"\>$1\<\/a\>"/eg;
return $text;
}
</XMP></BODY></HTML>
