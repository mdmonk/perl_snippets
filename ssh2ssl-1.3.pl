#!/usr/bin/perl -w

#==============================================================================#
my $VERSION = 1.3;
#==============================================================================#

=head1 NAME

ssh2ssl - SSH through SSL proxy tunnel

=head1 DESCRIPTION

Allows you to tunnel an SSH connection through an SSL (https) web proxy.

=head1 USAGE

To use this script, you will need to the following to your ~/.ssh/config:

    Host <REMOTE>
        ProxyCommand /path/to/bin/ssh2ssl <PROXY:PORT> %h:%p
        Port 443

You also need to have an sshd running on the far side. Your proxy probably
won't let you use port 22, so run an "sshd -p443" on the <REMOTE> and access
it locally using "ssh <REMOTE>" (the port was set in the config above).      

=head1 PREREQUISITES

This script requires the C<strict> module.  It also requires
C<IO::Handle>, C<IO::Socket> and C<IO::Select> modules.

=head1 COREQUISITES

none

=head1 AUTHOR

Gavin Brock
http://brock-family.org/gavin

=head1 COPYRIGHT

(C) 2000 Gavin Brock - This script is free software; you can
redistribute it and/or modify it under the same terms as Perl
itself.

=head1 README

This script allows you to tunnel an SSH connection through an SSL (https) web proxy.

=head1 CPAN INFO

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

Web
Networking

=cut

#==============================================================================#
# No user servicable parts below
#

use 5.005;
use strict;
use IO::Handle;
use IO::Socket;
use IO::Select;

# Get remote proxy and remote
die "Usage: $0 PROXY:PORT REMOTE:PORT\n" if (my ($proxy,$remote) = @ARGV) != 2;
print STDERR "ssl2ssh: Connecting to [$remote] via [$proxy]\n";

# Set up file handles
my $pxy  = IO::Socket::INET->new($proxy) || die "ssh2ssl: Can't open proxy: $!";
my $sto  = IO::Handle->new_from_fd(fileno(STDOUT),"w");
my $sti  = IO::Handle->new_from_fd(fileno(STDIN), "r");
my $rsel = IO::Select->new($pxy);
my $wsel = IO::Select->new($pxy);

# Now the clever part. We store the subroutines and buffers in the hash part of
# the glob-ref. This gives it a pseudo-object behaviour.

# Initalise buffers
$$pxy->{'wbuf'} = "CONNECT $remote HTTP/1.0\n\n";
$$sto->{'wbuf'} = "";

sub finished { die "ssl2ssh: Connection closed.\n"; }

# Callbacks for IO r/w
$$pxy->{'can_write'} = sub {
  my $bw = $pxy->syswrite($$pxy->{'wbuf'},length $$pxy->{'wbuf'});
  substr($$pxy->{'wbuf'},0,$bw,'');
  $wsel->remove($pxy) unless length $$pxy->{'wbuf'};
};

$$sto->{'can_write'} = sub {
  my $bw = $sto->syswrite($$sto->{'wbuf'},length $$sto->{'wbuf'});
  substr($$sto->{'wbuf'},0,$bw,'');
  $wsel->remove($sto) unless length $$sto->{'wbuf'};
};

$$sti->{'can_read'} = sub {
  $sti->sysread($$pxy->{'wbuf'},1024,length $$pxy->{'wbuf'}) || finished;
  $wsel->add($pxy);
};

$$pxy->{'can_read'} = sub {
  $pxy->sysread(my $buf,1024) || finished;
  $buf =~ /^HTTP\/1.\d 2\d\d/ || die "ssh2ssl: Server said:\n\n",$buf,"\n";
  $rsel->add($sti);
  $$pxy->{'can_read'} = sub { # Redefine for 2nd time
    $pxy->sysread($$sto->{'wbuf'},1024,length $$sto->{'wbuf'}) || finished;
    $wsel->add($sto);
  };
};

# Loop forever
while (my ($r,$w) = IO::Select::select($rsel,$wsel)) {
  foreach my $i (@$r) { $$i->{'can_read'}->()  }
  foreach my $o (@$w) { $$o->{'can_write'}->() }
}

#
# That's all folks...
#==============================================================================#
