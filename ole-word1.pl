use Win32::OLE qw(in with);
use Win32::OLE::Const 'Microsoft Word';
    
$Win32::OLE::Warn = 2; # Throw Errors, I'll catch them

my $Word = Win32::OLE->GetActiveObject('Word.Application')
    || Win32::OLE->new('Word.Application', 'Quit');


$Word->{'Visible'} = 1;
$Word->Documents->Add || die("Unable to create document ", Win32::OLE->LastError());
my $MyRange = $Word->ActiveDocument->Content;
my $mytxt = "Some Random Text";  # I'll fill this in later
# add a table that is the header portion, 1 column by 1 row

$Word->ActiveDocument->Tables->Add({
   Range => $MyRange,
   NumRows => 1,
   NumColumns => 1,
});
$Word->Selection->TypeText ({ Text => $mytxt});
$Word->Selection->MoveRight({Count => 1});
$Word->Selection->TypeText ({ Text => "A little more text"});
