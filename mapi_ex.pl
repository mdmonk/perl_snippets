use Win32::MAPI;

my($obj)=new Win32::MAPI(Profile  => 'Microsoft Outlook',
                         Password => 'your_password_here');

#my($obj)=new Win32::MAPI(UseDefProfile=>Yes);

if($obj->IsMAPI){print "\n MAPI is available...\n"}
else{die "\n MAPI is not available!\n"}

$obj->Logon() || die "Can't logon!";

$data{Text}="Perl is great!";
$data{Subject}="Win32::MAPI";
$data{To}='aminer@generation.net';
$data{Attachment}=['amine.txt','amine.txt'];
$data{ShowDialog}=0;# you can set to 1 to
                                      # bring the dialog.
$obj->SendMail(\%data);
$obj->LastError;

$obj->NextMail();
#print "MessageId is: ".$obj->{MessageId}."\n";

%data=(LeaveUnread=>1,NoAttachments=>0,
       UnreadOnly=>0,HeaderOnly=>0);

$obj->ReadMail(\%data);
#$obj->DeleteMail;
print "\nOriginator: ".$data{Originator}."\n";
print "From: ".$data{OrigAddress}."\n";
print "Received: ".$data{DateRecvd}."\n";
print "Text: ".$data{InboxText};

#print "Now downloading...\n";
#$obj->Download;
$obj->Logoff() ;
undef $obj; # dont forget to call the destructor!

#################################################
