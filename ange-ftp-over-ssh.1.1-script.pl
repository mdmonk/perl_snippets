#!/usr/local/bin/perl
# an ftp client simulator wrapped around scp


# include in configuration info
# specify here a list of aliases and ports in the hash @aliases, e.g.
#      $aliases{napier}=napier.pvl.edu.au:22
#      $aliases{clare}=localhost:3000

do "$ENV{HOME}/.nftprc";  

# stuff for CPAN
=head1 NAME

ange-ftp-over-ssh 

=head1 DESCRIPTION

GNU emacs has a wonderful remote file editing facility called Ange
ftp. However, because it uses ftp as its file transport agent,
passwords are transmitted as plain text which can be snooped by the
unscrupulous ``bad guys'' out there in cyberspace. This package is a
``drop in replacement'' for the ftp client that instead redirects the
file transfers over ssh, which allows for connections without the ned
for plain text passwords to be transmitted.

=head1 README

NB in this readme, the script is called nftp.pl.  The latest version
of this script can be obtained from
http://parallel.hpc.unsw.edu.au/rks/ange-ftp-over-ssh.html .

Prerequisites 

You should have GNU Emacs and ssh installed, which you probably have
already. You will also need Perl 5 installed.  Then you need to
download the nftp client software, written in perl. This software has
only been tested on Unix platforms, but may well run on Windows
without much change.

If you are not already familiar with ange ftp, you should read the
Emacs manual. In brief, you can open remote files for editing using
the syntax:

/host:filename
/user@host:filename

Getting ssh to connect without prompting for a password 

You also need to get ssh to connect to your remote site without
prompting for a password, as ssh reads the keyboard directly, and
cannot be fed a password directly from nftp.pl. There are two ways to
do this:

1. Set up a .rhosts or .shosts file on your remote system with you
       local hostname and userid. This technique is simple, but
       requires the local workstation to have a well known address
       (not true of ISP dial account, for example). It is also
       susceptible to IP spoofing attacks, and may well have been
       disabled by the system administrator of the remote site for
       this reason.  


2. Set up an ssh-agent to supply your bona fides to the remote system
       using RSA public key encryption. My setup has the following
       lines in my .profile:

       ttname=`tty`
       if [ "${ttname%%[0-9]}" = "/dev/tty" ]; then
         eval `ssh-agent`
         ssh-add
       fi

       This script (which you may need to modify for non-Linux OSes)
       will set up an ssh-agent, and prompt you for your password to
       load your private key into the agent's database.

You now need to copy your public key (located in .ssh/identity.pub)
into the files ~/.ssh/authorized_keys and ~/.ssh/known_hosts on the
remote remote system. This should enable the remote system to
authenticate your ssh connection, using the public key information
supplied by ssh-agent.

Configuration file ~/.nftprc 

Create the file ~/.nftprc containing a list of machines you wish to
remotely edit via ssh with the following sample format:

$aliases{grimble}="grimble.north-pole.com:22";
$aliases{grunge}="localhost:2000";

Any machine name not mentioned in this file will be connected to by
the usual ftp method. In the above example, two hostnames are defined,
grimble, and grunge. In the first case, nftp.pl will ssh to grimble on
port 22 (the standard ssh port). In the second case, the standard ssh
port of grunge has been forwarded to port 2000 on localhost (by
another ssh process perhaps). This is a convenient way of dealing with
firewalls.

Configuring .emacs 

Add the following line to yout .emacs file: 

(setq ange-ftp-ftp-program-name "nftp.pl")

That should be it! 

Things that can go wrong 

nftp.pl deliberately suppresses error messages to avoid confusing
ange-ftp. Try testing a file transfer using something like the
following command:

scp -q -P 22 username@remote.host/.profile /tmp

Any error messages you recieve should be taken seriously. For example,
earlier versions of scp do not support -q, or your default PATH on the
remote system may not include scp.

=pod SCRIPT CATEGORIES

Networking

=cut

$cwd=".";
$port=22;   # default port for ssh

sub split_quoted
{
    my($i,$j,$quoted,@r);
    split //;
    for ($i=0, $j=0, $quoted=0, @r=(); $i<=$#_; $i++)
    {
	if ($_[$i] eq "\"") {$quoted=!$quoted; next;}
	if ($_[$i] eq " " && !$quoted) {$j++; next;}
	if ($_[$i] eq "\n" && !$quoted) {last;}
	$r[$j].=$_[$i];
    }
    return @r;
}

for (print "ftp>"; <STDIN>; print "ftp>")
{
    if (/^exit/ || /^quit/) {last;}
    if (/^open/)
    { 
	($dummy,$rhost)=split;
	if (!exists($aliases{$rhost})) {exec "ftp -i -n $rhost";}
	print "Connected to $rhost\n";
	print "220 $rhost FTP server ready.\n";
	($rhost,$port)=split /:/,$aliases{$rhost};
    }
    if (/^user/)
    {
	($dummy,$uname)=split;
	print "230 User $uname logged in.\n";
    }
    if (/^hash/) {print "Hash mark printing on (1024 bytes/hash mark).\n";}
    if (/^type binary/) {print "200 Type set to I.\n";}
    if (/^type ascii/) {print "200 Type set to A.\n";}
    if (/^pwd/)
    {
	chomp($pwd=qx{ssh -p $port -l $uname $rhost pwd 2>&1});
	print "257 $pwd is current directory.\n";
    }
    if (/^cd/)  {($dummy,$cwd)=split_quoted;}
    if (/^lcd/)  {($dummy,$lwd)=split_quoted; chdir $lwd;}
    if (/^get/)  
    {
	($dummy,$source,$dest)=split_quoted; 
	if ($source!~m"^/") {$source="$cwd/$source"};
	if (length($dest)==0) {$dest=".";}
	print "200 PORT command successful.\n";
	print "150 Opening BINARY mode data connection for '$source'\n\n";
	system("scp -P $port -q $rhost:$source $dest >/dev/null 2>&1");
	print "226 Transfer complete.\n";
    }
    if (/^put/)
    {
	($dummy,$source,$dest)=split_quoted; 
	if ($dest!~m"^/") {$dest="$cwd/$dest";}
	print "200 PORT command successful.\n";
	print "150 Opening BINARY mode data connection for '$dest'\n\n";
	system("scp -P $port -q $source $rhost:$dest >/dev/null 2>&1");
	print "226 Transfer complete.\n";
    }
    if (/^ls/)
    {
	($dummy,$source,$dest)=split_quoted;
	$result=qx{ssh -p $port $rhost 'cd $cwd; ls $source' 2>&1};
	print "200 PORT command successful.\n";
	print "150 Opening ASCII mode data connection for '/bin/ls'.\n";
	if (length($dest)==0) {print $result;}
	else 
	{
	    open dest,">$dest";
	    print dest $result;
	    close dest
	}
	print "226 Transfer complete.\n";
    }
    if (/^rename/)
    {
	($dummy,$source,$dest)=split_quoted;
	$result=qx{ssh -p $port $rhost 'cd $cwd; mv $source $dest' 2>&1};
	print "250 RNTO command successful.\n";
    }
    if (/^delete/)
    {
	($dummy,$source)=split_quoted;
	$result=qx{ssh -p $port $rhost 'cd $cwd; rm $source' 2>&1};
	print "250 DELE command successful.\n";
    }
    if (/^mkdir/)
    {
	($dummy,$source)=split_quoted;
	$result=qx{ssh -p $port $rhost 'cd $cwd; mkdir $source' 2>&1};
	print "250 MKDIR command successful.\n";
    }
    if (/^chmod/)
    {
	($dummy,$mode,$source)=split_quoted;
	$result=qx{ssh -p $port $rhost 'cd $cwd; chmod $mode $source' 2>&1};
	print "250 CHMOD command successful.\n";
    }
}
