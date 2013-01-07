####################################################
# Sends email.
#
####################################################
use Net::SMTP;

$smtp = Net::SMTP->new('mail.server.address.com');
print $smtp->domain,"\n";
$smtp->mail( '' );     # use the sender's address here
$smtp->to('dest_name\@dest.mail.server');    # recipient's address
$smtp->data();                                   # Start the mail
#
# Send the header.
#
$smtp->datasend("To: dest_name\@dest.mail.server\n");
$smtp->datasend("From: \n");
$smtp->datasend("\n");
# Send the body.
#
$smtp->datasend("Do the headers display?\n");
$smtp->dataend();                   # Finish sending the mail
$smtp->quit;                        # Close the SMTP connection
