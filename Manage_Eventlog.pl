use Win32::EventLog;

my $Event;
my %logentry=(
    "EventID",777,
    "EventType",EVENTLOG_INFORMATION_TYPE,
    "Category",NULL,
    "Strings","Just Another Perl Hacker",   #This appears in the 
                                            #description box
    "Data","This could be some data from your program", #This is in
                                                        #the Data box
);

$Event=new Win32::EventLog("JAPH")||die "I couldn't create a new
event!";
$Event->Report(\%logentry)||die "Couldn't Write to Event Log!!!";
