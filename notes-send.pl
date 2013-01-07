# for sending mail

use Win32::OLE;
use Win32::OLE::Variant;

# your code here

sub send_mail {
    my($name, $notesdomain) = @_;
    my($notes, $db, $doc, $body);

     $notes = Win32::OLE-> new('Notes.NotesSession')
          or die "Cannot start Lotus Notes Session object.\n";

    $db = $notes-> GetDatabase( '' , '');
    $db-> OpenMail;

    $doc = $db-> CreateDocument;
    $doc-> {'Form'} = 'Memo';
    $doc-> {'SendTo'} = ["$name$notesdomain"];
    $doc-> {'CopyTo'} = ["Martin Leyrer/"];
    $doc-> {'Subject'} = 'Mail Subject';
    $body = <<'__STOP_IT';

This is the main body of the mail.
Insert your text here !

__STOP_IT

    $doc-> {'Body'} = $body;
    $doc-> Send(0);
}
