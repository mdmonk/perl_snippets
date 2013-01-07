# ========== Script start ==========
use Win32::OLE;
use Win32::OLE::Variant;
use strict;

my @mailadr = ();   # this will hold all the mail-adresses

# Get the Notes-Session
my $session = Win32::OLE-> new('Notes.NotesSession')
          or die "Cannot start Lotus Notes Session object.\n";

# Open the Addressbook (local in this case, add Servername to open different Adr.-book)
##my $db = $session-> GetDatabase( '' , '');
my $db = $session-> GetDatabase( 'DZPDML01/OS/DOI' , 'mail/clittle.nsf');
##my $db = $session-> GetDatabase( '' , 'names.nsf');
$db->OpenMail();

print "Connected to ", $db->{Title}, " on ", $db->{Server}, "\n";

foreach my $viewname ($db->GetViews()) {
	print "View name: $viewname\n";
}
#my $view = $db-> GetView('$User');

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
