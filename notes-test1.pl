#!perl.exe
use strict;
use Win32::OLE;
my $Notes = Win32::OLE->new('Notes.NotesSession')
    or die "Cannot start Lotus Notes Session object.\n";
my ($Version) = ($Notes->{NotesVersion} =~ /\s*(.*\S)\s*$/);
print "The current user is $Notes->{UserName}.\n";
print "Running Notes \"$Version\" on \"$Notes->{Platform}\".\n";
my $Database = $Notes->GetDatabase('', 'names.nsf');
my $AllDocuments = $Database->AllDocuments;
my $Count = $AllDocuments->Count;
print "There are $Count documents in the database.\n";
for (my $Index = 1 ; $Index <= $Count ; ++$Index) {
    my $Document = $AllDocuments->GetNthDocument($Index);
    printf "$Index. %s\n", $Document->GetFirstItem('Subject')->{Text};
    my $Values = $Document->GetItemValue('Index_Entries');
    foreach my $Value (@$Values) {
        print " Index: $Value\n";
    }
    last unless $Index < 5;
}