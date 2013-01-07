# ========== Script start ==========
use Win32::OLE;
use Win32::OLE::Variant;
use strict;

my @mailadr = ();   # this will hold all the mail-adresses

# Get the Notes-Session
my $session = Win32::OLE-> new('Notes.NotesSession')
          or die "Cannot start Lotus Notes Session object.\n";

# Open the Addressbook (local in this case, add Servername to open different Adr.-book)
my $db = $session-> GetDatabase( 'DZPDML01/OS/DOI' , 'names.nsf');
##my $db = $session-> GetDatabase( '' , 'names.nsf');
print "DB: " . $db->{'Title'} . "\n"; # for debugging

# select the view you want to use
my $view = $db-> GetView('$User');
print "VIEW: " . $view->{'Name'} . "\n";   # for debugging

# iterate over all documents in the view
my $doc = $view-> GetFirstDocument;       # Notes Dokument-Obj
while( defined($doc) ) {

     # get collection of fields in the current document
     my $coll = $doc-> {Items};     # Notes Item Objekt = field in form

     # convert the collection to a normal perl-hash
     my $docfields = &get_fields($coll);

     # we want all mail adresses in an array
     push(@mailadr, $docfields-> {MailAddress});

     $doc = $view-> GetNextDocument( $doc );
}


# spill out all email-adresses

print "\nAll mail adresses from Notes-Adressbook \"$db-> {Title}\":\n";
foreach (@mailadr) {
     print "$_\n";
}

exit;


# Get the names and values of all fields in the collection and
# return them in a hash
sub get_fields {
     my $collection = shift @_;
     my %hash = ();
     my $field;

     foreach $field ( @$collection ) {
          $hash{$field-> {Name}} = $field->{Text};
          # uncomment the following line for debugging or
          # if you want to see all field/value pairs
          print $field-> {Name} . " = " . $field->{Text} . "\n";
     }
     return(\%hash);
}
# ========== Script end ==========