# This is what I use to simulate a system call to mailx.  You can add it
# to your collection if you want.
############################################################################
#
#                    File: mailx.pl
#                Revision: $Revision$
#
#          Basic Overview: Emulate mailx on nt
#
#       Comments/Concerns: Not great but it works
#
#      TODO:  1. Add code to prompt for Cc: after message...
#                It will require restructuring the logic but the
#                feel of mailx will then be identical to unix.
#             2. Change code so that it reads in message before
#                opening a connection to the smtp port
#             3. Add code to identify if STDIN is a tty/pipe/file
#                and adjust appropriately when prompting for
#                Subject and Cc etc.
############################################################################
# Configure this for your local site
############################################################################
my $siteSMTP="xxx.xxx.xxx.com";
my $siteDOMAIN="yyy.yyy.com";

# Dont change anything below this line!!!!!!!
############################################################################
# Initialization Routines
############################################################################
use English;
use Net::SMTP;
# use Getopt::Std
############################################################################
# Global Variables
############################################################################
my $PROGNAME="mailx";
my $USAGE=" Usage:  mailx [-s Subject] [-f FromAddress] ToAddresses\n";
my $OPTIONS="ds:f:";

my $VERSION='$Revision 1.02$'; $VERSION=~ s/\$//g;
my $MODDATE='$Date$'; $MODDATE=~ s/\$//g;

my $username=$ENV{'USERNAME'};  $username=~ tr/[A-Z]/[a-z]/;
my $userdomain=$ENV{'USERDOMAIN'};  $userdomain=~ tr/[A-Z]/[a-z]/;
my $computername=$ENV{'COMPUTERNAME'};  $computername=~ tr/[A-Z]/[a-z]/;

my $opt_s,$opt_d,$opt_f;

if ( $ENV{'EMAIL'} )
  { $opt_f="$ENV{'EMAIL'}"; }
else
  { $opt_f="${userdomain}.${username}\@${computername}.${siteDOMAIN}"; }
############################################################################
# Parse Command Line
############################################################################
#getopts($OPTIONS) or die($USAGE);
JGetOpts($OPTIONS) or die($USAGE);
if ( $opt_d )
  { $opt_d=1; }
else
  { $opt_d=0; }
if ( $opt_s =~ m/^$/ )
{
   print "Subject: ";
   $opt_s=<STDIN>;
}
############################################################################
# Begin main processing
############################################################################
$smtp=Net::SMTP->new(${siteSMTP}, Debug=>$opt_d);
$smtp->mail($opt_f);

foreach $toaddress (@ARGV)
 { $smtp->to($toaddress); }

$smtp->data();
$smtp->datasend("From: ${userdomain}\\${username} <${opt_f}>\n");
$smtp->datasend("Subject: $opt_s\n");
$smtp->datasend("To: " . join(", ",@ARGV) . "\n");
$smtp->datasend("X-Mailer: pmailx [WindowsNT] \n");
$smtp->datasend("Comment: Unverified from address\n");
$smtp->datasend("\n");

while (<STDIN>)
{
  last if m/^\.$/g;
  $smtp->datasend($_);
}

# Message End
$smtp->dataend();
# Close connection with smtp port
$smtp->quit;
############################################################################
#  Functions
############################################################################
#            Function: JGetOpts
#
#      Basic Overview: Provide a superset of functionality to standard
#                      supplied Getopts.  The only enhancement is that
#                      the overwriting of arguments can be changed to
#                      appending instead.
#
#             Example: JGetOpts('a:bcd=');
#
#                      -a & -d takes argument.
#                      -b & -c do not take argument.
#                      Sets opt_* as a side effect.
#                      In -a case arg written to opt_a
#                      In -d case arg is appended to opt_d (ENHANCEMENT)
#             Returns: Normal error information
#           Arguments: $_[0]
#                          Description of options
#         Assumptions:
#   Comments/Concerns:
#       Future Issues:
############################################################################
sub JGetOpts
{
    local($argumentative) = @_;
    local(@args, $_, $first, $rest);
    local($errs) = 0;
    local($[) = 0;

    @args = split( / */, $argumentative );
    while (@ARGV and ($_ = $ARGV[0]) =~ /^-(.)(.*)/) {
    ($first, $rest) = ($1, $2);
    $pos = index($argumentative, $first);

    if ($pos >= $[)
       {
         if ($args[$pos+1] eq '=')
            {
              shift(@ARGV);
              if ($rest eq '')
                 {
                   ++$errs unless @ARGV;
                   $rest = shift(@ARGV);
                 }
              eval "if (\$opt_$first)
                       { \$opt_$first .= \":\" . \$rest; }
                      else
                       { \$opt_$first = \$rest; } ";
            }
           elsif ($args[$pos+1] eq ':')
            {
              shift(@ARGV);
              if ($rest eq '')
                 {
                   ++$errs unless @ARGV;
                   $rest = shift(@ARGV);
                 }
              eval "\$opt_$first = \$rest; ";
            }
           else
            {
              eval "\$opt_$first = 1";
              if ($rest eq '')
                 { shift(@ARGV); }
                else
                 { $ARGV[0] = "-$rest"; }
            }
       }
      else
       {
         ++$errs;

         if ($rest ne '')
            { $ARGV[0] = "-$rest"; }
           else
            { shift(@ARGV); }
       }
    }
    $errs == 0;
}
############################################################################
