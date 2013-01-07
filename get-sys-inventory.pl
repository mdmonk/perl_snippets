#!/usr/bin/perl

use IO::Socket::INET;

if ( ! $ARGV[0] ) { die "You need to provide me with a class C subnet to scan\nExample:\t$0 192.168.0\n"; }

my $IP1 = $ARGV[0];
my $AuthFile = "~/.smb";

print "IP|HOSTNAME|LOGGED IN USER|SERIAL NUMBER|MODEL\n";

for (our $IP2=1; $IP2 <= 254; $IP2++) {

        if (our $HostCheck = new IO::Socket::INET ( PeerAddr => "$IP1.$IP2",
                                               PeerPort => "135",
                                               Proto => "tcp",
					       Timeout => 5 ) ) {

        close $HostCheck;

        my $User = `wmic -A $AuthFile //$IP1.$IP2 \"select UserName from win32_computersystem\" 2>/dev/null |grep -Ev \"CLASS|Name|UserName|ERROR\"`;
        chomp $User;
        my $Serial = `wmic -A ~/.ssh/.smbtree2 //$IP1.$IP2 \"select SerialNumber from win32_bios\" 2>/dev/null | grep -Ev \"CLASS|SoftwareElementID|ERROR\" | awk -F '|' '{ print \$2 \"|\" \$6 }'`;
        chomp $Serial;
        print "$IP1.$IP2|$User|$Serial\n";
        }

        else {
        print "$IP1.$IP2|NA|NA|NA\n";
        }

}

