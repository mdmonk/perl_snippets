use Win32::Process;
sub Win32Error {
    die Win32::FormatMessage( Win32::GetLastError() );
} # Win32Error

sub Restart {
# Is this line needed because the findfile sub is included.
#    require "findfile.pl"; 
    my $perlexe = &findfile("perl.exe", "PATH");
    $perlexe =~ tr#/#\\#;
    my $cmdexe = &findfile("cmd.exe", "PATH");
    $cmdexe =~ tr#/#\\#;
    my $arg = $0;
    my $ProcessObj;
    Win32::Process::Create($ProcessObj,
    	$cmdexe,
    	"/c $perlexe $0",
    	0,
    	NORMAL_PRIORITY_CLASS,
    	".") || Win32Error();
    exit;
} # Restart

sub findfile {
    local ($filename, $path) = @_;
    local (@path_table);

    #   Split path differently on MS-DOS and UNIX (ugh!)
    @path_table = split (defined ($ENV {"COMSPEC"})? ";": ":", $ENV{$path});

    #   If file has absolute path, or exists locally, that's fine for us
    return $filename if -f $filename;
    foreach (@path_table) {
        return "$_/$filename" if -f "$_/$filename";
    }
    return "";
}

1;
