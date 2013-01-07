#!/usr/bin/perl

#################################################################
#                        napage.pl                              #
# 07/22/98 - Page a Command Center Analysti                     #
#            http://ov00ux1:81/perl/napage.pl                   #
#################################################################

$prompt_in_loc   = "/perl/napage.pl/prompt_in";
$posting_loc     = "/perl/napage.pl/posting";

if ($ENV{'PATH_INFO'} eq '' || $ENV{'PATH_INFO'} eq '/prompt_in') 
  {
    &prompt_in;
  }
  elsif ($ENV{'PATH_INFO'} eq '/posting') {
    &posting;
  }


sub prompt_in
{
print "Content-type: text/html\n\n";
print <<endofhtml;
<HTML>
<HEAD>
<TITLE>Command Center Page</TITLE>
<SCRIPT LANGUAGE="JavaScript">
<!--
function selectPin(value)
{
    document.menuform.pin.value = value
}
// -->
</SCRIPT>
</HEAD>
<BODY TEXT="#FFFFFF" BGCOLOR="#000000" LINK="#1973B2" VLINK="#61599F" ALINK="#61599F" onLoad="selectPin(document.menuform.pin1.options[document.menuform.pin1.selectedIndex].value)">
<CENTER><P><IMG SRC="http://ov00ux1:81/natblack.gif"></P></CENTER>
<CENTER><P><FORM NAME="menuform" METHOD="POST" ACTION="/perl/napage.pl/posting" onLoad="selectPin(document.menuform.pin1.options[document.menuform.pin1.selectedIndex].value)">
<INPUT name=pin type=hidden value="xxxxxxx">
<CENTER><TABLE BORDER=3 >
<TR>
<TH COLSPAN=2>Send a page via: </TH>
<TH>Enter the text message below: </TH>
</TR>
<TR>
<TH>Directory</TH>
<TH><SELECT NAME="pin1" Size="10" MAXLENGTH=10 onChange="selectPin(document.menuform.pin1.options[document.menuform.pin1.selectedIndex].value);">
<OPTION Selected Value="1818259">Jeff Cargill
<OPTION Value="1362699">Jeff Helms
<OPTION Value="1362933">Chuck Little
<OPTION Value="9356841">Rod Merchant
<OPTION Value="9356349">David Miranda
<OPTION Value="1821123">Shane Odonnel
<OPTION Value="1842158">Lori Williams
</SELECT></TH>
<TH ROWSPAN=0><TEXTAREA NAME="message" WRAP=YES ROWS=8 COLS=25 MAXLENGTH=496></TEXTAREA></TH>
</TR>
<TR>
<TH>PIN*</TH>
<TH><INPUT type=TEXT size=10 maxlength=10 NAME="pin2" onChange="selectPin(this.value)"></TH>
</TR>
</TABLE></CENTER>
<CENTER><P><INPUT TYPE="SUBMIT" VALUE="SUBMIT">
<INPUT TYPE="RESET" VALUE="CLEAR">
<NOBR>
</CENTER>
</FORM>
<CENTER><P></FORM></P></CENTER>
<TABLE>
<tr>
<td colspan=0 align=left valign=top>
<P>*An entry in the PIN field overrides any selection in the directory.</P>
</td></tr>
</TABLE>
</BODY>
</HTML>
endofhtml
}

sub posting
{

@sfpagers = ("Jeff Cargill",1818259,"Jeff Helms",1362699,"Chuck Little",1362933,"Shane Odonnel",1821123,"Lori Williams",1842158);
@inspagers = ("Rod Merchant",9356841,"David Miranda",9356349);
$i=0;

system "touch /home/gdpj/debug.txt";
system "chmod 666 /home/gdpj/debug.txt";
open OUT,">/home/gdpj/debug.txt" || die "Could not create file";


read (stdin, $postInput, $ENV{'CONTENT_LENGTH'});
@keyValues = split (/&/, $postInput);
foreach  $keyValues (@keyValues)
    {
     ($key, $value) = split (/=/, $keyValues);

     printf OUT "$keyValues are the keyvalues\n";

     $value =~ tr/+/ /;
     $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
     $i++;
     if ($key eq "pin")
        {
          $pin = $value;
        printf OUT "$pin is the pin being assigned from $value\n";
        }
     elsif ($key =~ /message/)
        {
          $message = $value;
        }
     elsif ($key eq "pin1")
        {
          $pin1 = $value;
        }
     elsif ($key eq "pin2")
        {
          $pin2 = $value;
        }
     }

printf OUT "$pin is the pin number and $message is the message\n"; 
close OUT;



$found = 'N';
foreach $tablepin (@inspagers) {
 if ($pin eq $tablepin) {
    $found = 'Y';
    print "Content-type: text/html\n\n";
    print <<endofhtml;
    <HTML>
    <HEAD>
    <TITLE>Command Center Page</TITLE>
    <SCRIPT>
    <!--
    // -->
    </SCRIPT>
    </HEAD>
    <BODY TEXT="#FFFFFF" BGCOLOR="#000000" LINK="#1973B2" VLINK="#61599F" ALINK="#61599F"> 
    <CENTER><P><IMG SRC="http://ov00ux1:81/natblack.gif"></P></CENTER> 
    <FORM METHOD="POST" ACTION='http://www.mci.com/cgi-bin/WebObjects/olab.woa/-/SendAPage.wo'>
    <INPUT name=provider type=hidden value="(1-800-PAGE-MCI) PAGE-MCI">
    <INPUT name=fromPage type=hidden value="SendAPage">
    <INPUT name=pin type=hidden value="$pin">
    <INPUT name=textMessage type=hidden value="$message">
    <CENTER>
    You are about to send $name the message: $message
    <BR>
    Are you sure you want to do this?
    </CENTER>
    <CENTER><P><INPUT TYPE="SUBMIT" VALUE="SEND PAGE"><input type=button value='CANCEL' onClick="location.href='/perl/napage.pl'">
    </CENTER>
    </FORM>
    </BODY>
    </HTML>
endofhtml
    last;
  }
  $name = $tablepin;
}

if ($found eq 'N') {
     foreach $tablepin (@sfpagers) {
       if ($pin eq $tablepin) {
       $found = 'Y'; 
       print "Content-type: text/html\n\n"; 
       print <<endofhtml;
       <HTML>
       <HEAD>
       <TITLE>Command Center Page</TITLE>
       <SCRIPT>
       <!--
       // -->
       </SCRIPT>
       </HEAD>
       <BODY TEXT="#FFFFFF" BGCOLOR="#000000" LINK="#1973B2" VLINK="#61599F" ALINK="#61599F">
       <CENTER><P><IMG SRC="http://ov00ux1:81/natblack.gif"></P></CENTER> 
       <FORM METHOD="POST" ACTION='http://www2.pagemart.com/cgi-bin/rbox/pglpage-cgi'>
       <INPUT name=pin type=hidden value="$pin"> 
       <INPUT name=PAGELAUNCHERID type=hidden value="2">
       <INPUT name="pin1" type=hidden value="$pin1"> 
       <INPUT name=message1 type=hidden value="$message">
       <INPUT name="pin2" type=hidden value="$pin2"> 
       <CENTER> 
       You are about to send $name the message: $message
       <BR> 
       Are you sure you want to do this?
       </CENTER>      
       <CENTER><P><INPUT TYPE="SUBMIT" VALUE="SEND PAGE"><input type=button value='CANCEL' onClick="location.href='/perl/napage.pl'">
       </CENTER> 
       </FORM>
       </BODY>
       </HTML>
endofhtml
       last;
       }
     $name = $tablepin;
     }
}
if ($found eq 'N')
   {
   print "Content-type: text/html\n\n";
    print <<endofhtml;
    <HTML>
    <HEAD>
    <TITLE>Command Center Page</TITLE>
    <SCRIPT>
    <!--
    // -->
    </SCRIPT>
    </HEAD>
    <BODY TEXT="#FFFFFF" BGCOLOR="#000000" LINK="#1973B2" VLINK="#61599F" ALINK="#61599F">
    <form>
    <CENTER><P><IMG SRC="http://ov00ux1:81/natblack.gif"></P></CENTER>
    <BR>
    You must enter a valid PIN.
    <P>
    If you used the PIN override box, this person must be in the list of possible people to page.
    <P> 
    Contact Jeff Helms 6-4301 to get the person/PIN added to the list. 
    <P><input type=button value='BACK' onClick="location.href='/perl/napage.pl'">
    </CENTER>
    </form>
    </BODY>
    </HTML>
endofhtml
    }
}
