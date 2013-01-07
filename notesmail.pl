use OLE;

# sendMail("HC65");
sendMail("NWAUTO");

sub sendMail {
  my($name, $domain) = @_;
  my($notes, $db, $doc, $body);

  $notes = CreateObject OLE 'Notes.NotesSession' || die "Couldn't create
new Notes Session Obj.!";
  $db = $notes->GetDatabase( 'Notes00B' , 'mail\mail02\hc65.nsf');
  $db->OpenMail;

  $doc = $db->CreateDocument;
  $doc->{'Form'} = 'Memo';
  $doc->{'SendTo'} = ["$name$domain"];
#  $doc->{'SendTo'} = ["NWAUTO"];
#  $doc->{'CopyTo'} = ["HC65"];
  $doc->{'Subject'} = 'Test Notes Mail';
  $body = <<'__STOP_IT';
This is a test! I am trying to send a Lotus Notes email using
Perl only. Let me know if this works please.

   Chuck.
__STOP_IT

  $doc->{'Body'} = $body;
  $doc->Send(0);
}


