use Win32::OLE;

my $server;
my $database;
my $folder;

my $file = "temp_file.csv";

my $ini = "get_emails.ini";
if (-e $ini)
{
    open (INI,$ini) || die "Not able to open $ini: $!\n";
    chomp ($server = );
    chomp ($database = );
    chomp ($folder = );
}
else
{
    print "\nEnter Notes Server: ";
    chomp ($server=);
    print "\nEnter Notes Database: ";
    chomp ($database=);
    print "\nEnter Folder you want to access: ";
    chomp ($folder=);
}

#connect to the Notes database
my $Notes = Win32::OLE->new('Notes.NotesSession') || warn "Cannot start Lotus Notes Session object: $!\n";
my $Database = $Notes->GetDatabase($server, $database);

#Fetch contents of the folder
my $Response = $Database->GetView($folder);
my $Count = $Response->TopLevelEntryCount;
my $Index = $Count;

open (OUT, ">$file");

#loop through all emails
for (1..$Count)
{
    my $Document = $Response->GetNthDocument($Index--);
    my $subject = $Document->GetFirstItem('Subject')->{Text};
    my $body = $Document->GetFirstItem('Body')->{Text};
    print OUT "Subject: $subject\n",
              "Body: $body\n";
}

`start excel.exe $file`;