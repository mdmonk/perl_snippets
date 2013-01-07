#!/usr/bin/perl

# \@ is the escape sequence for the "@" symbol.
my @serverList = ('root\@exampleserver1.example.com',
                  'root\@exampleserver2.example.com');

foreach $server (@serverList) {

    open SBUFF, "ssh $server -x -o batchmode=yes 'softwareupdate -i -a' |";
    while(<SBUFF>) {
        my $flag = 0;
        chop($_);

        #check for restart text in $_
        my $match = "Please restart immediately";
        $count = @{[$_ =~ /$match/g]};
        if($count > 0) {
            $flag = 1;
        }
    }
    close SBUFF;

    if($flag == 1) {
        `ssh $server -x -o batchmode=yes shutdown -r now`
    }
}