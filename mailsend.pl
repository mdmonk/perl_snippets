use Net::SMTP;

$server   = 'mail.dftech.org';
$sender   = 'chuck.little@relera.com';
@receiver = ('3039013970@page.nextel.com', '3038984997@mobile.att.net');

$smtp = Net::SMTP->new($server); # connect to an SMTP server

foreach $dude (@receiver) {
   $dude1 = "3039013970\@page.nextel.com";
   $dude2 = "3038984997\@mobile.att.net";
   $smtp->mail($sender);     # use the sender's address here
                  
   $smtp->to($dude2);     # recipient's address

   $smtp->data();             # Start the mail

# Send the header.
#
   $smtp->datasend("To: $dude\n");
   $smtp->datasend("From:$sender\n");
 # $smtp->datasend("Subject: Results of Policy Push\n");
   $smtp->datasend("Subject: Test\n");
   $smtp->datasend("\n");

# Send the body.
#
$smtp->datasend("The Script Worked! New policy is now in effect.\nChuck L.");

   $smtp->dataend();                   # Finish sending the mail
   $smtp->quit;                        # Close the SMTP connection
} # end of foreach
