#!/usr/bin/perl

use Mail::Audit;
use Fcntl ':flock';

srand( time ^ $$ );
my $incoming       = Mail::Audit->new();

my $accepted       = 0;
my $logfile        = '/tmp/mailfilter.log';
my $bounce_percent = 1;
my $email_address  = 'ranger@befunk.com';
my $old_emails     = [
  'ranger@alloyweb.com',
  'ranger@ironweb.com',
  'rangerik@hotmail.com',
  'ranger@evilive.com',
  'ranger@noctis.net',
];

# directory containing the filtered mail folders
my $mail_directory = "/home/ranger";

# the key is the filename of the folder being created,
# and the value is an array reference containing regex
# matches that will put a given mail in that folder
#
# $lists matches on the from, to, cc, or bcc fields

my $lists          = {

  # '' passes through direct to the inbox
  '' => [
      'pudge@perl\.org',
      'security@linux-mandrake\.com',             # Mandrake Security
    ],

  'DFT-Talk' => [
      'dft-talk@alloyweb\.com',
    ],

  'DJ In A Box' => [
      'djiab@defiance\.dyndns\.org',
      'djiab@scenespot\.org',
    ],
  'Linux From Scratch' => [
      'lfs-.*@linuxfromscratch\.org',
    ],
  'Mandrake Cooker' => [
      'cooker@linux-mandrake\.com',
    ],
  'MP3 Discussion' => [
      'mp3encoder@geek\.rcc\.se',                 # LAME
      'shoutcast@listserv\.winamp\.com',          # Shoutcast
    ],
  'OpenNIC' => [
      'discuss@opennic',
    ],
  'OpenNMS' => [
      'general@.*opennms\.org',
    ],
  'Other Lists' => [
      '.*@listbeast.be.com',                      # BeOS
      'atheos-developer@lists\.sourceforge\.net', # AtheOS
      'berlin-design@lists\.sourceforge\.net',    # Berlin
      'dns@.*cr\.yp\.to',                         # DJB DNS
      'discuss-gnustep@gnu\.org',                 # GNUStep
      'freenet-chat@lists\.sourceforge\.net',     # Freenet
      'ggi-develop@eskimo\.com',                  # GGI
      'gnome-list@gnome\.org',                    # Gnome
      'gtk-list@gnome\.org',                      # GTK+
      'ingo-.*@blank\.pages\.de',                 # Gimp Announcements
      'listar-support@listar\.org',               # Listar
      'mesa@iqm\.unicamp\.br',                    # MESA
      'port-hpcmips@netbsd\.org',                 # NetBSD for HPC
      'sparc-list@redhat\.com',                   # RedHat Sparc
      'synopsis-devel@lists\.sourceforge\.net',   # Berlin
      'uclinux.*@uclinux\.org',                   # UCLinux
      'uclinux.*@c3po\.kc-inc\.net',              # UCLinux
      'udmsearch@search\.udm\.net',               # UDMSearch
      'updates@helixcode\.com',                   # Helix updates
      'wine-devel@winehq\.com',                   # WINE
    ],
  'OVForum' => [
      'ovforum@ovforum\.org',
    ],
  'Perl Lists' => [
      'bootstrap@perl\.org',                      # Perl6 Bootstrap
      'modperl@apache\.org',                      # modperl
      'perl5-porters@perl\.org',                  # Perl5 Porters
      'perl-win32-gui@httptech\.com',             # Win32::GUI
      'perl-xml@.*\.activestate\.com',            # Perl-XML
      'poop-group@lists\.sourceforge\.net',       # Perl Object Oriented
      'perl6-.*@perl\.org',                       # All Perl 6 mailing lists
    ],
  'Raleigh Lists' => [
      'raleigh-pm-list@happyfunball\.pm\.org',    # PerlMongers
      'trilug@franklin\.oit\.unc\.edu',           # TriLUG
    ],
  'SceneSpot' => [
      'bug@scenespot\.org',
      'dev@scenespot\.org',
    ],
  'SPAM' => [
      'musicnews@mp3\.com',
      'reg_dev@palm\.com',
      'listserv@wapoutlook\.com',
    ],
  'Surveys' => [
      'aparks@acop\.com',
      'support@questions\.net',
    ],

};

# this is the same as $lists, but matches only against
# the subject

my $subjects = {
  'DJ In A Box' => [
      'djiab',
    ],
};

# process the $lists hash reference for matching mail
# and accept it

for my $list (sort keys %{$lists}) {
  for my $regex (@{$lists->{$list}}) {
    if (

      $incoming->from =~ /$regex/i or
      $incoming->to   =~ /$regex/i or
      $incoming->cc   =~ /$regex/i or
      $incoming->bcc  =~ /$regex/i

    ) {

      if ($list ne "") {
        $incoming->accept("$mail_directory/$list");
        $accepted = 1;
      } else {
        $incoming->accept;
        $accepted = 1;
      }

    }
  }
}

# process the $subjects hash reference for matching mail
# and accept it

for my $list (sort keys %{$subjects}) {
  for my $regex (@{$subjects->{$list}}) {
    if ( $incoming->subject =~ /$regex/i ) {
      $incoming->accept("$mail_directory/$list");
      $accepted = 1;
    }
  }
}

# are they sending to my old address?

for my $address (@{$old_emails}) {

  if (
    $incoming->to  =~ /$address/i or
    $incoming->cc  =~ /$address/i or
    $incoming->bcc =~ /$address/i
  ) {

    if (rand(100) < $bounce_percent) {
      $incoming->reject(<<END);

The $address account is deprecated.  I will
randomly bounce messages $bounce_percent\% of the time until I
stop getting messages at the old address.

<sarchasm on>

  I've only been switched to $email_address now for,
  like, 2 years, so it's understandable you're still
  sending to the old address.

<sarchasm off>

The random percentage of bounced messages will increase
as time goes by, so if you don't want to get any more
of these, I suggest you update your address book.

END

      log($incoming, "old e-mail bounce for $address");

    }
  }
}

# does my e-mail address appear anywhere?

if (
  (not $incoming->to  =~ /$email_address/i) and
  (not $incoming->cc  =~ /$email_address/i) and
  (not $incoming->bcc =~ /$email_address/i)
) {

  $incoming->accept("$mail_directory/Questionable");
  $accepted = 1;
}

# is the sender listed in the RBL?

if (my $spam = $incoming->rblcheck(5)) {
  $incoming->reject(<<END);

You have been marked as a spammer in the Relay Blackhole
List for the following reason:

  $spam

Messages marked as such are not accepted here.

END

  log($incoming, "suspected spammer: $spam");

}

# otherwise, accept it

$incoming->accept();
$accepted = 1;

sub log {
  my $incoming = shift;
  my $reason   = join('', @_);
     $reason   =~ s/\r?\n$//;

  if (open (FILEOUT, ">>$logfile")) {
    flock(FILEOUT, LOCK_EX);
    seek(FILEOUT, 0, 2);
    print FILEOUT scalar localtime, " [ $incoming->from / $incoming->subject ] reason: $reason\n";
    flock(FILEOUT, LOCK_UN);
    close(FILEOUT);
  }
}
