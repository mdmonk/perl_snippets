#!/usr/bin/perl -w
#
# snarfnews - download news from web sites and convert it automatically
#	 into PalmPilot DOC or text format.
#
# Skip down to read the POD documentation.
#
# To set up, search for "CUSTOMISE" -- note UK/Irish spelling. ;)
# Change the setting appropriately and uncomment it, if required.
# Then move the required sites from the "sites_off" directory into the
# "sites" directory, and those will be downloaded automatically next
# time you run the script.

$main::VERSION = "0.9";

$CONFIG = '
# NOTE: on Windows, you will need to use 2 backslashes in any paths in
# this built-in configuration file, to avoid Perl interpreting them,
# like so: C:\\TMP

#######################################################################

# OPTIONAL SITE-DEPENDENT CONFIGURATION

# NOTE: If you will be converting sites into Pilot-readable format, you
# may need to specify this! The directory under your PalmPilot Desktop
# dir where installable PRC files need to go.
#
# On UNIX platforms using pilot-xfer, its simply the directory you use to
# sync with. [REVISIT -- check default pilot-xfer dir]
#
# Generally on Win32 platforms this is of the format
# {pilotdir}/{username}/Install, where {pilotdir} is the PalmPilot Desktop
# directory, and {username} is the abbreviation of the Pilot user name.
# On a Win32 machine with only one Pilot user, this is determined
# automatically from the registry, so you will not need to set it.

# PilotInstallDir: $HOME/pilot			# CUSTOMISE

#######################################################################

# Sites directory, where the site description files are stored.
# By default, a directory called "sites" under your current directory,
# or under your $HOME on UNIX, is used if it exists.

# SitesDir: $HOME/lib/sites			# CUSTOMISE

#######################################################################

# Temporary directory to use for snarfnews. A subdirectory will be
# created called snarfnews_{uid} where {uid} is your user id (or
# 0 on Win32 platforms). On UNIX platforms, this defaults to a hidden
# directory under your home dir, for privacy.

# TmpDir: /tmp					# CUSTOMISE

#######################################################################

# Specify the HTTP proxy server in use at your site, if applicable.

# ProxyHost: proxy.clubi.ie			# CUSTOMISE
# ProxyPort: 80					# CUSTOMISE

# Diff will be searched for on the path if this is not specified here.

# Diff: C:\\path\\to\\diff.exe			# CUSTOMISE

# The MakeDoc tool will be searched for on the path if it is
# not specified here.

# MakeDoc: makedocw.exe				# CUSTOMISE

# Where you want the text-format output to be saved. If commented,
# it will be saved under the snarfnews temporary directory.

# TextSaveDir: C:\\where\\I\\want\\News		# CUSTOMISE
';

#---------------------------------------------------------------------------

=head1 NAME

snarfnews - download news from web sites and convert it automatically
	into PalmPilot DOC or text format.

=head1 SYNOPSIS

snarfnews [options] [-site sitename]

snarfnews [options] [-levels n] [-storyurl regexp] url [...]

Options: [-debug] [-refresh] [-config file] [-text]
	[-install dir] [-dump] [-dumpprc] [-longlines] [-nowrite]

=head1 DESCRIPTION

This script, in conjunction with its configuration file and its set of
"site" files, will download news stories from several top news sites into
text format and/or onto your Pilot (with the aid of the 'makedoc' or
'MakeDocW' utilities).

Alternatively URLs can be supplied on the command line, in which case
those URLs will be downloaded and converted using a reasonable set of
default settings.

HTTP and local files, using the file:/// protocol, are both supported.

Multiple types of sites are supported:

  1-level sites, where the text to be converted is all present on one page
  (such as Slashdot, Linux Weekly News, BluesNews, NTKnow, Ars Technica);

  2-level sites, where the text to be converted is linked to from a Table
  of Contents page (such as Wired News, BBC News, and I, Cringely);

  3-level sites, where the text to be converted is linked to from a Table
  of Contents page, which in turned is linked to from a list of issues
  page (such as PalmPower).

In addition sites that post news as items on one big page, such as
Slashdot, Ars Technica, and BluesNews, are supported using diff.

Note that at this moment in time, the URLs-on-the-command-line invocation
format does not support 2- or 3-level sites.

The script is portable to most UNIX variants that support perl, as well
as the Win32 platform (tested with ActivePerl 5.00502 build 509).

Currently the configuration is stored as a string inside the script
itself, but an alternative configuration file can be specified with the
'-config' switch.

The sites downloaded will be the ones listed in the site files you keep in
your "sites" directory.

snarfnews maintains a cache in its temporary directory; files are kept
in this cache for a week at most. Ditto for the text output directory
(set with 'TextSaveDir' in the built-in configuration).

If a password is required for the site, and the current snarfnews session
is interactive, the user will be prompted for the username and password.
This authentication token will be saved for later use.  This way a site
that requires login can be set up as a .site -- just log in once, and your
password is saved for future non-interactive snarf runs.

Note however that the encryption used to hide the password in the
snarfnews configuration is pretty transparent; I recommend that rather
than using your own username and password to log in to passworded sites, a
dedicated, snarfnews account is used instead.

=head1 OPTIONS

-refresh

Refresh all links -- ignore the 'already_seen' file and always fetch
pages, even if they are recently-cached server-generated HTML.

-config file

Read the configuration from 'file' instead of using the built-in one.

-install dir

The directory to save PRC files to once they've been converted, in order
to have them installed to your PalmPilot.

-site sitename

Limit the snarfing run to 1 or more sites named in the 'sitename'
argument.  Normally all available sites will be snarfed. To limit the
snarf to 2 or more sites, provide multiple -site arguments like so: '-site
ntk.site -site tbtf.site'.

-levels n

When specifying a URL on the command-line, this indicates how many levels
a site has. Not needed when using .site files.

-storyurl regexp

When specifying a URL on the command-line, this indicates the regular
expression which links to stories should conform to. Not needed when using
.site files.

-text

Do not convert the page(s) downloaded into DOC format, just convert them
to text.

-dump

Output the page(s) downloaded directly to stdout in text format, instead
of writing them to files and converting each one to DOC format. This
option implies -text.

-dumpprc

Output the page(s) downloaded directly to stdout in DOC format as a PRC
file, suitable for installation to a PalmPilot.

-longlines

Normally text output is broken up into 70-80 column lines if possible,
to make it readable. However the -longlines switch disables this
behaviour. This switch is primarily useful for debugging.

-nowrite

Test mode -- do not write to the cache or already_seen file, instead write
what would be written normally to a directory called new_cache and a
new_already_seen file.

-debug

Enable debugging output.

=head1 INSTALLATION

To install, edit the script and change the #! line. You may also need to
(a) change the Pilot install dir if you plan to use the pilot installation
functionality, and (b) edit the other parameters marked with CUSTOMISE in
case they need to be customised for your site. They should be set to
acceptable defaults (unless I forgot to comment out the proxy server lines
I use ;).

=head1 EXAMPLES

snarfnews http://www.ntk.net/

To snarf the ever-cutting NTKnow newsletter ('nasty, British and short').
Really though,  you'd save the bother if you just signed up for their
weekly mailings!

=head1 ENVIRONMENT

B<snarfnews> makes use of the C<$http_proxy> environment variable, if it
is set.

=head1 AUTHOR

Justin Mason E<lt>jmason /at/ penguinpowered.comE<gt>

=head1 COPYRIGHT

Some of the post-processing and HTML cleanup code include ideas and code
shamelessly stolen from http://pilot.screwdriver.net/ , Christopher
Heschong's <chris at screwdriver.net> webpage-to-pilot conversion tool,
which I discovered after writing a fully-working version of this script!
Looks like I reinvented the wheel again on this one ;)

Eh, anyway, the remainder of the code is copyright Justin Mason 1998-1999,
and is free software and as such is redistributable and modifiable under
the same terms as Perl itself. Justin can be reached at <justin_mason at
bigfoot.com>.

=head1 SCRIPT CATEGORIES

The CPAN script category for this script is C<Web>. See
http://www.cpan.org/scripts/ .

=head1 PREREQUISITES

C<URI::URL>
C<LWP::UserAgent>
C<HTTP::Date>
C<HTTP::Request::Common>
C<CGI>

All these can be picked up from CPAN at http://www.cpan.org/ .

=head1 COREQUISITES

C<Win32::TieRegistry>, if running on a Win32 platform, to find the Pilot
Desktop software's installation directory.

=head1 README

Snarfnews downloads stories from news sites and converts them to PalmPilot
DOC format for later reading on-the-move.  Site files and full
documentation can be found at http://zap.to/snarfnews/ .

=cut

#---------------------------------------------------------------------------

					    sub usage { die <<__ENDOFUSAGE;

snarfnews - download news from web sites and convert it automatically
	into PalmPilot DOC or text format.

snarfnews [options] [-site sitename]

snarfnews [options] [-levels n] [-storyurl regexp] url [...]

Options: [-debug] [-refresh] [-config file] [-text]
	[-install dir] [-dump] [-dumpprc] [-longlines] [-nowrite]

Both file:/// and http:/// URLs are supported.

Version: $main::VERSION
__ENDOFUSAGE
					    }

#---------------------------------------------------------------------------

# use Carp;
# use strict;	# ah shaggit, life's too short for strict
use File::Find;
use Cwd;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Date;
use URI::URL;

use CGI;

if (&Portability::MyOS eq 'Win32') {
  eval 'use Win32::TieRegistry( Delimiter=>"/", ArrayValues=>0 );';
}

$SIG{__WARN__} = 'warn_log';
$SIG{__DIE__} = 'die_log';

$main::SNARFURL = "http://zap.to/snarfnews";
$main::refresh = 0;
#$main::just_caching = 0;
$main::cached_front_page_lifetime = 10;	# in minutes
$main::onlytext = 0;
$main::dumptxt = 0;
$main::dumpprc = 0;
$main::nowrite = 0;
$main::longlines = 0;
$main::bookmark_char = "\x8D";		# yes, same as Chris' one, cheers!
undef $main::pilotinstdir;
$main::will_makedoc = 0;
$main::cgimode = 0;
$main::cgi = undef;
@main::sites_wanted = ();
@main::cmdline_urls = ();

$main::argv_levels = undef;
$main::argv_storyurl = undef;

$main::useragent = new SnarfHTTP::UserAgent;
$main::useragent->env_proxy;
$main::useragent->agent ("snarfnews/$main::VERSION ($main::SNARFURL) ".
		$main::useragent->agent);

# --------------------------------------------------------------------------

if (defined $ENV{'REQUEST_METHOD'}) {
  # we're running from a CGI script, use CGI mode
  $main::cgimode = 1;
  $main::cgi = new CGI;
}

# --------------------------------------------------------------------------

if ($main::cgimode == 0) {
  while ($#ARGV >= 0) {
    $_ = shift;

    if (/^-debug$/) {
      $main::debug = 1;
    } elsif (/^-refresh/) {
      $main::cached_front_page_lifetime = 0;
      $main::refresh = 1;
    #} elsif (/^-cache/) {
      #$main::just_caching = 1;	# used for future parallelism
    } elsif (/^-dump/) {
      $main::dumptxt = 1;
      $main::onlytext = 1;
    } elsif (/^-dumpprc/) {
      $main::dumpprc = 1;
    } elsif (/^-text/) {
      $main::onlytext = 1;
    } elsif (/^-longlines/) {
      $main::longlines = 1;
    } elsif (/^-nowrite/) {
      $main::nowrite = 1;
    } elsif (/^-config/) {
      $config = shift;
    } elsif (/^-install/) {
      $pilotinstdir = shift;
    } elsif (/^-site/) {
      push (@sites_wanted, shift);
    } elsif (/^-levels/) {
      $argv_levels = shift()+0;
    } elsif (/^-storyurl/) {
      $argv_storyurl = shift;
    } elsif (/^-/) {
      &usage;
    } else {
      unshift @ARGV, $_; last;
    }
  }
  @main::cmdline_urls = @ARGV;
  $main::userid = $<;

} else {
  # load some things from CGI parameters
  @main::cmdline_urls = ($main::cgi->param ('url'));
  $main::argv_levels = $main::cgi->param ('levels');
  $main::argv_storyurl = $main::cgi->param ('storyurl');

  @main::sites_wanted = $main::cgi->param ('sites');

  $main::debug = $main::cgi->param ('debug');
  $main::onlytext = $main::cgi->param ('text');
  $main::nowrite = $main::cgi->param ('nowrite');
  $main::refresh = $main::cgi->param ('refresh');
  $main::userid = $main::cgi->param ('userid');
  &SnarfCGI::get_cookie;
  # $main::password = $main::cgi->param ('password');
  # REVISIT -- use a cookie to store userid and password

  $main::pilotinstdir = undef;
}

@conflines = ();
if (defined $config) {
  open (IN, "< $config") || die "cannot read $config\n";
  @conf = (<IN>); close IN;
  for ($i=0; $i<$#conf; $i++) { $conflines[$i] = "$config:".($i+1); }
} else {
  @conf = split(/\n/, $CONFIG);
  for ($i=0; $i<$#conf; $i++) { $conflines[$i] = "(built-in):".($i+1); }
}

# --------------------------------------------------------------------------

$outdir = '';
%links_start = %links_end = ();
%links_limit_to = %story_limit_to = ();
%links_print = ();
%story_skip = %links_skip = ();
%story_diff = %links_diff = ();
%story_follow_links = ();
%story_postproc = ();
%cacheable = ();	# 0 = static, 1 = dynamic, undef = use heuristics
%printable_sub = ();
%head_pat = ();
%levels = ();
%use_table_smarts = ();
%extra_urls = ();
@sites = ();
$url = '';
$sect = '';
$curkey = '';
$main::cached_front_page_lifetime /= (24*60);	# convert to days
%url_title = ();

undef $tmpdir;
if (&Portability::MyOS eq 'UNIX') { $tmpdir = $ENV{'HOME'}."/.snarfnews"; }
$tmpdir ||= $ENV{'TMPDIR'}; $tmpdir ||= $ENV{'TEMP'};

$diff = 'diff';
if (&Portability::MyOS eq 'Win32') { $diff = "diff.exe"; }

$makedoc = 'makedoc';
if (&Portability::MyOS eq 'Win32') { $makedoc = "makedocw.exe"; }

$sitesdir = "sites";
if (!-d $sitesdir && &Portability::MyOS eq 'UNIX')
			{ $sitesdir = $ENV{'HOME'}."/sites"; }

# ---------------------------------------------------------------------------

sub got_intr {
  my $signame = shift;
  (&Portability::MyOS eq 'UNIX') and system ("stty echo");
  die "got signal SIG$signame, exiting.\n";
}

$SIG{'INT'} = \&got_intr;
$SIG{'TERM'} = \&got_intr;

# ---------------------------------------------------------------------------

if (!defined $pilotinstdir && !$main::cgimode) {
  @main::possible_inst_dirs = ();
  my $dir;

  if (&Portability::MyOS eq 'Win32') {
    eval '
      sub get_instdir_wanted {
	return unless (/^install$/i && -d $File::Find::name);
	push (@main::possible_inst_dirs, $File::Find::name);
      }

      my $key = "HKEY_CURRENT_USER/Software/U.S. Robotics".
		    "/Pilot Desktop/Core//Path";
      if ($dir = $Registry->{$key}) {
	@main::possible_inst_dirs = ();
	find(\&get_instdir_wanted, $dir);
      }
    ';

  } elsif (defined $ENV{'HOME'}) {
    $dir = $ENV{'HOME'}."/pilot";
    if (-d $dir) { @main::possible_inst_dirs = ($dir); }
  }

  if ($#main::possible_inst_dirs == 0) {
    $pilotinstdir = $main::possible_inst_dirs[0];

  } elsif ($#main::possible_inst_dirs > 0 && !$onlytext) {
    warn "Fatal: too many potential pilot PRC install directories, ".
	"please use '-install' argument.\n";
    foreach $dir (@main::possible_inst_dirs) {
      warn "Possible choice: $dir\n";
    }
    &cleanexit(1);
  }
}

# ---------------------------------------------------------------------------

sub ReadSitesDir {
  my ($file, $key);
  my %sites_wanted = ();

  if ($#sites_wanted >= 0) {
    print "Restricting to sites: ".join (' ', @sites_wanted)."\n";
    foreach $key (@sites_wanted) {
      $sites_wanted{$key} = 1;
    }
  }

  if (defined $sitesdir) {
    foreach $file (<$sitesdir/*>) {
      next if ($file =~ /(\.swp$|core|\.bak$|\~$|^#)/);	# skip backups
      if ($#sites_wanted >= 0) {
	my $base = $file; $base =~ s,^.*\/([^\/]+)$,$1,g;
	next unless (defined $sites_wanted{$base});
      }

      open (IN, "< $file") || warn "Cannot read $file\n";
      my $line = 0;
      while (<IN>) {
	push (@conf, $_); push (@conflines, "$file:$line");
	$line++;
      }
      close IN;
    }
  }
}
&ReadSitesDir;

# ---------------------------------------------------------------------------

my $postproc = undef;
my $postproctype = undef;
my $proxyhost;
my $proxyport = 80;
my $line;

foreach $_ (@conf) {
  $line = shift @conflines;
  s/#.*$//; s/^\s+//; s/\s+$//g; next if (/^$/);

  if (defined $postproctype) {
    $postproc .= $_;
    # see if it's the end of the postproc statement scope
    $x = $postproc; 1 while ($x =~ s/\{[^\{\}]*\}//gs);		#{
    if ($x =~ /\}\s*$/) {
      if ($postproctype eq 'Story') {				#{
	$postproc =~ /^(.*)\}\s*$/; $story_postproc{$curkey} = $1;
	$postproc = undef;
	$postproctype = undef;
      }
    }
    next;
  }

  s/^(\S+:)\s+/$1 /;		# easier to read this way ;)
  /^ProxyHost: (.*)$/ and ($proxyhost = $1), next;
  /^ProxyPort: (.*)$/ and ($proxyport = $1+0), next;
  /^TmpDir: (.*)$/ and ($tmpdir = $1), next;

  if (/^SitesDir: (.*)$/) {
    $sitesdir = $1;
    &ReadSitesDir;
    next;
  }

  /^MakeDoc: (.*)$/ and ($makedoc = $1), next;
  /^Diff: (.*)$/ and ($diff = $1), next;
  /^TextSaveDir: (.*)$/ and ($outdir = $1), next;
  /^PilotInstallDir: (.*)$/ and ($pilotinstdir = $1), next;

  if (/^URL: (.*)$/) {
    &FinishConfigSection ($sect, $url);
    $url = $1; $sect = '';

    if ($url !~ m,^(http|file)://,i) { $url = 'http://'.$url; }
    if ($url =~ m,(http|file)://[^/]+$,i) { $url .= '/'; }
    push (@sites, $url);
    &SetDefaultConfigForURL ($url);
    $curkey = $url;
    next;
  }

  if (!defined $curkey || $curkey eq '') {
    $line =~ s/^(.*):(.*?)$/"$1" line $2/g;
    die "Configuration line invalid (outside URL scope?) in $line:\n  $_\n";
  }

  /^Name: (.*)$/ and ($name{$curkey} = $1), next;
  /^Active: (.*)$/ and ($active{$curkey} = $1+0), next;
  /^Levels: (.*)$/ and ($levels{$curkey} = $1-2), next;
  /^AddURL: (.*)$/ and ($extra_urls{$curkey} .= ' '.$1), next;
  /^UseTableSmarts: (.*)$/ and ($use_table_smarts{$curkey} = $1+0), next;

  /^IssueLinksStart: (.*)$/ and ($links_start{"1 $curkey"} = $1), next;
  /^IssueLinksEnd: (.*)$/     and ($links_end{"1 $curkey"} = $1), next;
  /^IssuePrint: (.*)$/      and ($links_print{"1 $curkey"} = $1+0), next;
  /^IssueCachable: (.*)$/     and ($cacheable{"1 $curkey"} = $1+0), next;
  /^IssueDiff: (.*)$/        and ($links_diff{"1 $curkey"} = $1+0), next;
  /^IssueUseTableSmarts: (.*)$/ and ($use_table_smarts{"1 $curkey"} = $1+0), next;

  /^ContentsStart: (.*)$/   and ($links_start{"0 $curkey"} = $1), next;
  /^ContentsEnd: (.*)$/       and ($links_end{"0 $curkey"} = $1), next;
  /^ContentsPrint: (.*)$/   and ($links_print{"0 $curkey"} = $1+0), next;
  /^ContentsCachable: (.*)$/  and ($cacheable{"0 $curkey"} = $1+0), next;
  /^ContentsSkipURL: (.*)$/  and ($links_skip{"0 $curkey"} = $1+0), next;
  /^ContentsDiff: (.*)$/     and ($links_diff{"0 $curkey"} = $1+0), next;
  /^ContentsUseTableSmarts: (.*)$/ and ($use_table_smarts{"0 $curkey"} = $1+0), next;

  if (/^ContentsURL: (.*)$/) {
    my $pat = $1;
    if (!defined ($links_limit_to{"0 $curkey"})) {
      $links_limit_to{"0 $curkey"} = "($pat)";
    } else {
      $links_limit_to{"0 $curkey"} =~ s/\)$/|$pat)/g;
    }
    next;
  }

  /^StoryStart: (.*)$/		and ($story_start{$curkey} = $1), next;
  /^StoryEnd: (.*)$/		and ($story_end{$curkey} = $1), next;
  /^StoryCacheable: (.*)$/	and ($cacheable{"s $curkey"} = $1+0), next;
  /^StoryDiff: (.*)$/		and ($story_diff{$curkey} = $1+0), next;
  /^StorySkipURL: (.*)$/	and ($story_skip{$curkey} = $1), next;
  /^StoryHeadline: (.*)$/	and ($head_pat{$curkey} = $1), next;
  /^StoryToPrintableSub: (.*)$/	and ($printable_sub{$curkey} = $1), next;
  /^StoryFollowLinks: (.*)$/	and ($story_follow_links{$curkey} = $1+0), next;

  if (/^StoryURL: (.*)$/) {
    my $pat = $1;
    if (!defined ($story_limit_to{$curkey})
      		|| $story_limit_to{$curkey} !~ /\)$/)
    {
      $story_limit_to{$curkey} = "($pat)";
    } else {
      $story_limit_to{$curkey} =~ s/\)$/|${pat})/g;
    }
    next;
  }

  if (/^(Story)PostProcess: (.*)$/) {
    my $type = $1;
    my $val = $2;
    if ($val =~ s/^\{//) #}
    {
      $postproctype = $type;
      $postproc = $val;
    } else {
      if ($type eq 'Story') { $story_postproc{$curkey} = $val; }
    }
    next;
  }

  if (/^Section: (.*)$/) {
    &FinishConfigSection ($sect, $url);
    $sect = $1;

    if ($sect !~ m,^(http|file)://,i) {
      if ($sect !~ m,^/,i) {
	$sect = 'http://'.$sect;
      } else {
	$url =~ m,((http|file)://[^/]+)/,; $sect = $1.$sect;
      }
    }
    if ($sect =~ m,(http|file)://[^/]+$,) { $sect .= '/'; }
    $sections{$url} .= "|||$sect";
    $levels{$sect} = $levels{$url};
    $active{$sect} = 1;
    $extra_urls{$sect} = '';
    $curkey = $sect;
    next;
  }

  $line =~ s/^(.*):(.*?)$/"$1" line $2/g;
  warn "Unrecognised config line in $line:\n  $_\n";
}

if (defined $postproctype) {
  warn "Fell off end of ${postproctype}PostProcess statement!\n";
}

&FinishConfigSection ($sect, $url);
undef @conf;
undef @conflines;

if (!defined $sitesdir) {
  warn "Warning: can't find the 'sites' directory, please specify it!\n";
}

if (defined $proxyhost) {
  $main::useragent->proxy
  	(['http', 'ftp'], "http://$proxyhost:$proxyport/");
}

# ---------------------------------------------------------------------------
# Default configuration for a newly-specified URL.

sub SetDefaultConfigForURL {
  my $url = shift;

  $sections{$url} = "";		# none yet
  $active{$url} = 1;		# active by default
  $use_table_smarts{$url} = 1;	# use smarts
  $levels{$url} = -1;		# 1-level site
  $extra_urls{$url} = '';	# no extra URLs

  # default limit to articles at the same site
  $url =~ m,^((http|file)://[^/]*/),i;
  if (defined $1) {
    $story_limit_to{$url} = $1.'.*';
  } else {
    warn "Unsupported URL protocol for URL '".$url."'.\n";
  }
}

# ---------------------------------------------------------------------------
# Incorporate defaults from the main URL into each Section.
#
sub FinishConfigSection {
  my $sect = shift;
  my $url = shift;

  if ($sect ne '') {
    if (!defined $name{$sect}) { $name{$sect} = '(untitled)'; }
    if (!defined $story_start{$sect}) { $story_start{$sect} = $story_start{$url}; }
    if (!defined $story_end{$sect}) { $story_end{$sect} = $story_end{$url}; }
    if (!defined $head_pat{$sect}) { $head_pat{$sect} = $head_pat{$url}; }
    if (!defined $printable_sub{$sect})
		{ $printable_sub{$sect} = $printable_sub{$url}; }
    if (!defined $story_limit_to{$sect})
		{ $story_limit_to{$sect} = $story_limit_to{$url}; }
    if (!defined $story_skip{$sect}) { $story_skip{$sect} = $story_skip{$url}; }
    if (!defined $story_diff{$sect}) { $story_diff{$sect} = $story_diff{$url}; }
    if (!defined $story_follow_links{$sect})
    		{ $story_follow_links{$sect} = $story_follow_links{$url}; }
    if (!defined $active{$sect}) { $active{$sect} = $active{$url}; }

    # If the main site is disabled, so are the sub-sites.
    if ($active{$url} == 0) {
      $active{$sect} = 0;
    }

    $levels{$sect} = $levels{$url};
    for ($lev = $levels{$url}; $lev >= 0; $lev--)
    {
      if (!defined $links_start{"$lev $sect"}) {
	$links_start{"$lev $sect"} = $links_start{"$lev $url"};
      }
      if (!defined $links_end{"$lev $sect"}) {
	$links_end{"$lev $sect"} = $links_end{"$lev $url"};
      }
      if (!defined $links_skip{"$lev $sect"}) {
	$links_skip{"$lev $sect"} = $links_skip{"$lev $url"};
      }
      if (!defined $links_diff{"$lev $sect"}) {
	$links_diff{"$lev $sect"} = $links_diff{"$lev $url"};
      }
      if (!defined $links_print{"$lev $sect"}) {
	$links_print{"$lev $sect"} = $links_print{"$lev $url"};
      }
      if (!defined $links_limit_to{"$lev $sect"}) {
	$links_limit_to{"$lev $sect"} = $links_limit_to{"$lev $url"};
      }
    }
  }
}

# ---------------------------------------------------------------------------

# if ($just_caching) {
#   # just put the pages into the cache and forget about it
#   foreach $url (@main::cmdline_urls) {
#     &log ("bg: getting $url ...");
#     &get_page ($url, 0);
#   }
#   &log ("bg: done.");
#   &cleanexit;
# }

if ($#main::cmdline_urls > -1) {
  @sites = ();
  foreach $url (@main::cmdline_urls) {
    if (-r $url) {
      if ($url =~ m,^/,) {
	$url = 'file://'.$url;
      } else {
	$url = 'file://'.getcwd.'/'.$url;
      }
    }
    if ($url =~ m,(http|file)://[^/]+$,i) { $url .= '/'; }

    if (!defined $name{$url}) {
      $name{$url} = $url;
      if ($url =~ m,/([^/]+)$,) { $name{$url} = $1; }
    }

    push (@sites, $url);
    &SetDefaultConfigForURL ($url);

    if (defined $argv_levels) {
      $levels{$url} = $argv_levels-2;
    }
    if (defined $argv_storyurl) {
      $story_limit_to{$url} = $argv_storyurl;
    }
  }
}

# ---------------------------------------------------------------------------

$slash = '/'; if (&Portability::MyOS eq 'Win32') { $slash = '\\'; }

%already_seen = ();
%last_modtime = ();
@seen_this_time = ();
($x,$x,$x,$mday,$mon,$year,$x,$x,$x) = localtime(time);
@months = qw(x Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
$mon++; $year += 1900;
$filename = sprintf ("%04d_%02d_%02d", $year, $mon, $mday);
$title = "$year-".$months[$mon]."-$mday";

%file2pilotfilename = ();
%file2title = ();

$main::will_makedoc = (!$main::onlytext &&
		defined $makedoc && $makedoc ne '');

if (!$onlytext && !defined $pilotinstdir && !$cgimode) {
  die "fatal: can't find pilot PRC install directory, ".
      "please use '-install' argument.\n";
}

# if we're running in text mode and not converting to DOC format, limit
# the text to 70 columns, otherwise always use long lines by default.
# I'd prefer if MakeDoc could handle the conversion properly without
# requiring this!
if ($main::will_makedoc) {
  $main::longlines = 1;
}

&make_dirs;
&SnarfHTTP::UserAgent::load_logins;
&get_all_sites (@sites);
&convert_output;
&SnarfHTTP::UserAgent::save_logins;

warn "Finished!\n";
&cleanexit;

# ---------------------------------------------------------------------------

sub make_dirs {
  if (!-d $tmpdir) {
    mkdir ($tmpdir, 0777) || die "failed to mkdir '$tmpdir'\n";
  }
  chdir ($tmpdir) or die "cannot cd to $tmpdir\n";

  $user_tmpdir = "$tmpdir/snarfnews_$userid";

# passwords for snarfnews caches are not fully impled right now!
#
#if ($main::cgimode) {
#open (PWD, "< $user_tmpdir/passwd");
#my $pwd = <PWD>; close PWD;
#my $salt = substr($pwd, 0, 2);
#if (crypt ($main::password, $salt) ne $pwd) {
#&SnarfCGI::passwd_failed; exit;
#}
#}

  if (!-d $user_tmpdir) {
    mkdir ($user_tmpdir, 0777) || die "failed to mkdir '$user_tmpdir'\n";
  }

  if ($cgimode && !defined $pilotinstdir) {
    $pilotinstdir = "$user_tmpdir/prc";
    if (!-d $pilotinstdir) {
      mkdir ($pilotinstdir, 0777) || die "failed to mkdir '$pilotinstdir'\n";
    } else {
      sub expire_prcdir { unlink if (-f $_ && -M $_ > 7.0); }
      find(\&expire_prcdir, $pilotinstdir);
    }
  }

  if ($main::debug) {
    open (LOGFILE, "> $user_tmpdir/log.txt");
    select LOGFILE; $| = 1; select STDOUT;
  }

  if ($outdir eq '') { $outdir = "$user_tmpdir/txt"; }
  if (!-d $outdir) {
    mkdir ($outdir, 0777) || die "failed to mkdir '$outdir'\n";

  } else {
    if (!$main::will_makedoc) {
      sub expire_outdir { unlink if (-f $_ && -M $_ > 7.0); }
      find(\&expire_outdir, $outdir);
    }
  }

  $cachedir = "$user_tmpdir/cache"; $newcachedir = $cachedir;
  if (!-d $cachedir) {
    mkdir ($cachedir, 0777) || die "failed to mkdir '$cachedir'\n";

  } else {
    sub expire_cache { unlink if (-f $_ && -M $_ > 7.0); }
    find(\&expire_cache, $cachedir);
  }

  $alreadyseen = "$user_tmpdir/already_seen.txt"; $newalreadyseen = $alreadyseen;

  if ($refresh == 0) {
    if (!open (IN, "< $alreadyseen")) {
      warn "Cannot read $alreadyseen, creating a new one\n";
    } else {
      while (<IN>) {
	s/\s+$//g;
	if (s/\s+lastmod=(\d+)//) { $last_modtime{$_} = $1; }
	$already_seen{$_} = 1;
      }
      close IN;
    }
  }

  if ($nowrite) {
    $newcachedir = "$user_tmpdir/new_cache";
    if (!-d $newcachedir) {
      mkdir ($newcachedir, 0777) || die "failed to mkdir '$newcachedir'\n";
    }
    $newalreadyseen = "$user_tmpdir/new_already_seen.txt";
  }
}

# ---------------------------------------------------------------------------

sub get_all_sites {
  my @sites = @_;

  foreach $site (@sites) {
    my @urls = ($site);
    if ($sections{$site} ne "") {
      @urls = split (/\|\|\|/, $sections{$site});
    }

    foreach $url (@urls) {
      next if ($url eq '');
      next unless ($active{$url} == 1);

      $sitename = $name{$site};
      $sectname = '';
      if ($site ne $url) { $sectname = "_".$name{$url}; }

      my $filedesc = $filename.'_'.$sitename.$sectname;
      $filedesc =~ s/[^-_A-Za-z0-9]+/_/g;
      $filedesc =~ s/_+$//; $filedesc =~ s/^_+//;
      $outfile = $outdir.$slash.$filedesc.'.txt';
      $tmpfile = $outdir.$slash.$filedesc.'.tmp';

      $sectname =~ s/_+$//; $sectname =~ s/^_+//;
      my $secttitle = "$title: $sitename" .
			  ($sectname ne '' ? ": $sectname" : "");

      open (OUTFILE, "> $tmpfile") || die "cannot write to $tmpfile\n";
      print OUTFILE "$secttitle\n\n\n";
      $stories_found = 0;

      my $u;
      foreach $u ($url, split (' ', $extra_urls{$url})) {
	if ($levels{$url} >= 0) {
	  &download_front_page ($u, $url, $levels{$url});
	} else {
	  # just read the text and write it to a file
	  &download_story_page ($u, $url, 1);
	}
      }

      if ($stories_found != 0) {
	warn "$secttitle: $stories_found stories downloaded.\n";

	print OUTFILE "(End of snarf - copyright retained by original ".
	  "providers. Downloaded and converted by snarfnews; see ".
	  "$main::SNARFURL )".
	  "\n<$main::bookmark_char>\n";

	close OUTFILE || warn "Failed to write to $tmpfile";

	if ($main::dumptxt) {
	  open (IN, "< $tmpfile");
	  while (<IN>) { print STDOUT; }
	  close IN; unlink ($tmpfile);

	} else {
	  unlink ($outfile);
	  rename ($tmpfile, $outfile);
	}

	if ($main::dumpprc) {
	  $file2pilotfilename{$outfile} = $tmpfile;	# reuse it!
	} else {
	  $file2pilotfilename{$outfile} = $pilotinstdir.$slash.$filedesc.'.prc';
	}
	$file2title{$outfile} = $secttitle;

      } else {
	close OUTFILE;
	warn "$secttitle: no new stories, ignoring.\n";
	unlink ($tmpfile);
      }
    }
  }
}

# ---------------------------------------------------------------------------

sub convert_output {
  my $failed_to_cvt = 0;

  if ($main::will_makedoc) {
    if (!-d $pilotinstdir) {
      mkdir ($pilotinstdir, 0755) || die "failed to mkdir '$pilotinstdir'\n";
    }

    foreach $outfile (sort keys %file2title) {
      unlink $file2pilotfilename{$outfile};
      $cmd = "$makedoc $outfile ".$file2pilotfilename{$outfile}." '".
		    $file2title{$outfile}."'";
      warn "Running: $cmd\n";
      system $cmd;
      print "\n";		# needed on UNIX, makedoc doesn't do this ;)
      if (($? >> 8) != 0) {
	warn "command failed: $cmd\n";
      }
      unlink ($outfile);	# don't keep .txt files around

      if ($main::dumpprc) {
	open (IN, "< ".$file2pilotfilename{$outfile});
	while (<IN>) { print STDOUT; }
	close IN;
	unlink $file2pilotfilename{$outfile};
      }
    }
  }

  if (!$failed_to_cvt) {
    # only write alreadyseen if the files converted successfully, otherwise
    # the user may lose some recent news due to a makedoc screwup.
    #
    my $towrite = '';
    foreach $_ (@seen_this_time) {
      $towrite .= $_." lastmod=".(defined $last_modtime{$_}
		  ? $last_modtime{$_}+0 : 0)."\n";
    }
    open (OUT, ">> $newalreadyseen") || warn "Cannot append to $newalreadyseen\n";
    print OUT $towrite;	# do it as one big atomic write, for safety
    close OUT || warn "Cannot append to $newalreadyseen\n";
  }
}

# ---------------------------------------------------------------------------
# Note on levels: a 2-level site has a contents page and stories off that;
# 3-level has issue links page, per-issue contents page and stories.
# 1-level has only the story page, no links.

sub download_front_page {
  my $url = shift;
  my $baseurl = shift;
  my $level = shift;
  my ($cachefile, $page);
  my $key = "$level $baseurl";

  if (defined $links_limit_to{$key}) {
    if ($url !~ m#^${links_limit_to{$key}}$#) {
      &log ("front page URL $url does not match ".${links_limit_to{$key}}.", ignoring.");
      return;
    }
  }

  if (defined $links_skip{$key}) {
    if ($url =~ m#^${links_skip{$key}}$#) {
      warn "Skipping: $url\n"; return;
    }
  }

  warn "Reading level-".($level+2)." front page: $url\n";

  my $is_dynamic_html;
  if (defined $cacheable{$key}) {
    $is_dynamic_html = ($cacheable{$key} == 0);
  } elsif (defined $links_diff{$key} && $links_diff{$key} != 0) {
    $is_dynamic_html = 1;	# pages that need diff'ing are dynamic
  } elsif ($level < $levels{$baseurl}) {
    # second-level or deeper front pages are usually not dynamic, more
    # likely to be a static table of contents.
    $is_dynamic_html = 0;
  } else {
    $is_dynamic_html = 1;	# front pages are usually dynamic
  }

  $page = &get_page ($url, $is_dynamic_html);
  return unless defined $page;
  $page = &strip_front_page ($url, $key, $baseurl, $page);

  my $cachedpage;
  if (defined $links_diff{$key} && $links_diff{$key} != 0) {
    $cachedpage = &strip_front_page ($url, $key, $baseurl,
    					&get_cached_page ($url, 1));
  }

  $page = &get_new_bits ($cachedpage, $page);

  if (defined $links_print{$key} && $links_print{$key} != 0) {
    my $txtpage = &html_to_text ($url, $baseurl, $page);

    my $outme = 1;
    if ($is_dynamic_html && defined $cachedpage && !$main::refresh) {
      # ensure that the cleaned-up HTML doesn't match the cleaned-up cached
      # HTML. Sometimes the ad banners will be the only things that have
      # changed between retrieves, and html_to_text will have stripped those
      # out.
      my $cachedtxt = &html_to_text ($url, $baseurl, $cachedpage);
      if (&text_equals ($txtpage, $cachedtxt)) {
	warn "Not printing contents (text has not changed): $url\n";
	$outme = 0;
      }
    }

    if ($outme) {
      warn "Printing: $url\n";
      &write_as_story ($url, $baseurl, $txtpage, undef);
    }
  }

  while (1) {
    if ($page =~ s/^.*?<a\s+[^>]*href=\"([^\"]+)\"[^>]*>.*?<\/a>//is
       || $page =~ s/^.*?<a\s+[^>]*href=([^\s+>]+)[^>]*>.*?<\/a>//is

       # support for frames
       || $page =~ s/^.*?<frame\s+[^>]*src=\"([^\"]+)\"[^>]*>//is
       || $page =~ s/^.*?<frame\s+[^>]*src=([^\s+>]+)[^>]*>//is
       )
    {
      &follow_front_link ($baseurl, $url, $level, $1, undef);
      next;
    }

    # rudimentary support for my-netscape-style RDF files
    if ( $page =~ s/^.*?<item>(.*?)<link\s*[^>]*>(.+?)<\/link>.*?<\/item>//is)
    {
      my ($title, $link) = ($1, $2);
      if ($title =~ /<title>(.*)?<\/title>/) {
	$title = $1;
      } else {
	$title = undef; 
      }
      &follow_front_link ($baseurl, $url, $level, $link, $title);
      next;
    }

    last;
  }
}

# ---------------------------------------------------------------------------

sub follow_front_link {
  my ($baseurl, $url, $level, $nextpage, $title) = @_;
  $nextpage = &AbsoluteURL ($url, $nextpage);

  &main::dbg ("Link found on $baseurl: $nextpage");

  if (defined $title) { $url_title{$nextpage} = $title; }

  # should we download the next front page?
  if (defined $links_start{($level-1)." $baseurl"}) {
    &download_front_page ($nextpage, $baseurl, $level-1);
    next;
  }

  # nope, we're onto the stories already
  if (defined $printable_sub{$baseurl}) {
    my $new = $nextpage;
    my $sub = $printable_sub{$baseurl};
    $sub =~ s/\\(\d+)/\$$1/g;	# avoid warnings

    eval '$new =~ '.$sub.'; 1;'
      or warn "Printable substitution failed! ($!)\n";

    if ($nextpage ne $new) {
      # warn "Using printable version instead: $new\n";
      if (defined $story_limit_to{$baseurl} &&
	      $new !~ m#^${story_limit_to{$baseurl}}$#)
      {
	warn "Printable version does not match StoryURL".
	      "pattern, reverting to $nextpage\n";
      } else {
	$nextpage = $new;
      }
    }
  }

  &download_story_page ($nextpage, $baseurl, 0);
}

# ---------------------------------------------------------------------------

sub download_story_page {
  my $url = shift;
  my $baseurl = shift;
  my $is_dynamic_html = shift;
  my ($cachefile, $page);

  $url =~ s/#.*$//g;		# strip references

  my $cacheflag = $cacheable{"s $baseurl"};
  if (defined $cacheflag) {
    # user setting overrides our heuristics
    $is_dynamic_html = ($cacheflag==0);
  }
  if (defined $story_diff{$baseurl} && $story_diff{$baseurl}) {
    $is_dynamic_html = 1;	# diff pages are always dynamic
  }

  if (defined $story_limit_to{$baseurl}) {
    if ($url !~ m#^${story_limit_to{$baseurl}}$#) {
      if (!defined $output_storyurl_warning{$baseurl}) {
	&main::dbg ("(StoryURL for $url: ${story_limit_to{$baseurl}})");
	$output_storyurl_warning{$baseurl} = 1;
      }
      &main::dbg ("Non-story URL ignored: $url");
      return;
    }
  }
  if ($url =~ m,^(ftp|mailto|https|gopher|pnm)://,) {
    &main::dbg ("Non-story URL ignored: $url");
    return;
  }

  if (defined $story_skip{$baseurl}) {
    if ($url =~ m#^${story_skip{$baseurl}}$#) {
      warn "Skipping: $url\n"; return;
    }
  }

  if (!$is_dynamic_html && $already_seen {$url}) {
    &main::dbg ("skipping, already seen: $url");
    return;
  }

  push (@seen_this_time, $url);
  $already_seen {$url} = 1;

  &get_story_page ($url, $baseurl, $is_dynamic_html);
}

# ---------------------------------------------------------------------------

sub get_story_page {
  my $url = shift;
  my $baseurl = shift;
  my $is_dynamic_html = shift;
  my @turnoverlinks;
  my $headline;

  warn "Reading: $url\n";

  my $cachedpage;
  if ($is_dynamic_html ||
	defined $story_diff{$baseurl} && $story_diff{$baseurl})
  {
    $cachedpage = &strip_story ($url, $baseurl,
    	&get_cached_page ($url, 1), " (cached)");
  }


  my $origpage = &get_page ($url, $is_dynamic_html);
  return unless defined $origpage;

  # get headline before stripping StoryStart and StoryEnd
  $headline = &get_headline ($url, $baseurl, $origpage);
  my $page = &strip_story ($url, $baseurl, $origpage, "");

  if (defined $story_diff{$baseurl} && $story_diff{$baseurl}) {
    $page = &get_new_bits ($cachedpage, $page);
  }
  &cache_page ($url, $origpage);

  # get turn-over links after stripping StoryStart and StoryEnd
  @turnoverlinks = &get_turnover_links ($url, $baseurl, $page);
  $page = &html_to_text ($url, $baseurl, $page);

  if ($is_dynamic_html && defined $cachedpage && !$main::refresh) {
    # ensure that the cleaned-up HTML doesn't match the cleaned-up cached
    # HTML. Sometimes the ad banners will be the only things that have
    # changed between retrieves, and html_to_text will have stripped those
    # out.
    $cachedpage = &html_to_text ($url, $baseurl, $cachedpage);
    if (&text_equals ($page, $cachedpage)) {
      warn "Skipping (text has not changed): $url\n";
      return;
    }
  }

  &write_as_story ($url, $baseurl, $page, $headline);

  if ($#turnoverlinks >= 0) {
    my $link;
    for $link (@turnoverlinks) {
      $link = &AbsoluteURL ($url, $link);
      &download_story_page ($link, $baseurl, 0);	# right now
    }
  }
}

# ---------------------------------------------------------------------------

sub get_new_bits {
  my ($oldfile, $newfile) = @_;

  if (!defined $oldfile || $oldfile =~ /^\s*$/) { return $newfile; }

  warn "Finding differences between current page and cached version\n";

  # it's important to keep these names 8.3 for Windows-95 compatibility,
  # as some Windoze diffs may not be able to handle them otherwise!
  # This also requires that we are chdir'd into the temporary directory
  # to avoid hassles with long filenames in the args when we run the
  # diff command. What a pain!
  #
  my $oldf = "a$$.tmp";		# we are already chdir'ed
  my $newf = "b$$.tmp";
  open (F1, "> $oldf") || warn "cannot write to $oldf\n";
  open (F2, "> $newf") || warn "cannot write to $newf\n";

  # Split the file lines at probable story-header endpoints.
  # This makes them more amenable to diffing, hopefully without
  # losing bits we don't want to lose, or gaining bits we don't
  # want to gain. Also try to keep cross-line-split HTML tags
  # together.
  $oldfile =~ s/(<(br|p|hr|table|td|\/td|\/table|\/p|\/tr)\s*[^>]*>)/$1\n/gi;
  $newfile =~ s/(<(br|p|hr|table|td|\/td|\/table|\/p|\/tr)\s*[^>]*>)/$1\n/gi;
  1 while $oldfile =~ s/<([^\n>]+)\n+([^>]*)>/<$1 $2>/gis;
  1 while $newfile =~ s/<([^\n>]+)\n+([^>]*)>/<$1 $2>/gis;
  $oldfile =~ s/\s*\n+/\n/gis;
  $newfile =~ s/\s*\n+/\n/gis;
  1 while $oldfile =~ s/\n\n+/\n/gis;
  1 while $newfile =~ s/\n\n+/\n/gis;

  print F1 $oldfile; close F1;
  print F2 $newfile; close F2;

  my $page = '';
  open (DIFF, "$diff $oldf $newf |") || warn "cannot run $diff\n";
  while (<DIFF>) {
    /^>/ || next;
    $page .= $';
  }
  close DIFF;		# ignore exit status -- exit 1 only means no diffs.

  # warn "$diff $oldf $newf, breaking for debug (REVISIT)"; &cleanexit;
  unlink $oldf; unlink $newf;
  $page;
}

# ---------------------------------------------------------------------------

sub text_equals {
  my ($t1, $t2) = @_;
  $t1 =~ s/[\s\r\n]+/ /gs; $t1 =~ s/^\s+//g; $t1 =~ s/\s+$//g;
  $t2 =~ s/[\s\r\n]+/ /gs; $t2 =~ s/^\s+//g; $t2 =~ s/\s+$//g;
  ($t1 eq $t2);
}

# ---------------------------------------------------------------------------
# Strip a story page from StoryStart to StoryEnd.
# In addition, strip out non-story sidebar table items.
#
sub strip_story {
  my $url = shift;
  my $baseurl = shift;
  my $page = shift;
  my $comment = shift;

  if (!defined $page) { return undef; }

  # ok, now strip the headers and footers
  my $pat = $story_start{$baseurl}; if (defined $pat) {
    ($page =~ s#^.*?${pat}##gs) ||
	warn "StoryStart pattern \"$pat\" not found in page $url$comment\n";
    $page =~ s#^[^<]*?>##gs;		# strip superfluous ends of tags
  }
  $pat = $story_end{$baseurl}; if (defined $pat) {
    ($page =~ s#${pat}.*?$##gs) ||
	warn "StoryEnd pattern \"$pat\" not found in page $url$comment\n";
    $page =~ s#<[^>]*?$##gs;		# strip superfluous starts of tags
  }

  $page =~ s/<td\s+([^>]+)>(.*?)<\/td>/
		&smart_clean_table($baseurl, $1, $2, $baseurl);
	/gies;

  $page =~ s/\r/ /g;	# strip CRs
  $page;
}

sub strip_front_page {
  my $url = shift;
  my $key = shift;
  my $baseurl = shift;
  my $page = shift;

  if (!defined $page) { return undef; }

  my $pat = $links_start{$key}; if (defined $pat) {
    ($page =~ s#^.*?${pat}##gs) ||
	warn "ContentsStart pattern \"$pat\" not found in page $url\n";
    $page =~ s#^[^<]*?>##gs;		# strip cut-in-half tags
  }
  $pat = $links_end{$key}; if (defined $pat) {
    ($page =~ s#${pat}.*?$##gs) ||
	warn "ContentsEnd pattern \"$pat\" not found in page $url\n";
    $page =~ s#<[^>]*?$##gs;		# strip cut-in-half tags
  }

  $page =~ s/<td\s+([^>]+)>(.*?)<\/td>/
		&smart_clean_table($baseurl, $1, $2, $key);
	/gies;

  $page =~ s/\r/ /g;	# strip CRs
  $page;
}

# ---------------------------------------------------------------------------

sub get_headline {
  my $url = shift;
  my $baseurl = shift;
  my $page = shift;

  my $headline;

  if (defined $url_title{$url}) {
    $headline = &html_to_text ($url, $baseurl, $url_title{$url});
    &main::dbg ("StoryHeadline: (from RDF): $headline");

  } elsif (defined $head_pat{$baseurl}) {
    my $pat = $head_pat{$baseurl};
    if ($page !~ m#${pat}#m) {
      warn "StoryHeadline pattern \"$pat\" not found in page $url\n";
    } elsif (defined $1) {
      $headline = &html_to_text ($url, $baseurl, $1);
      &main::dbg ("StoryHeadline: $headline");
    } else {
      warn "StoryHeadline pattern \"$pat\" does not contain brackets!\n";
    }

  } elsif ($page =~ m#<meta name="PCTITLE" content="(.*)">#mi) {
    # try a fallback: search for PointCast headline tags
    $headline = &html_to_text ($url, $baseurl, $1);
    &main::dbg ("StoryHeadline (default, PointCast): $headline");
  }

  $headline;
}

# ---------------------------------------------------------------------------

sub get_turnover_links {
  my $url = shift;
  my $baseurl = shift;
  my $page = shift;

  my @turnoverlinks = ();

  while ($page =~ s,<a href=([^>]+)>([^<]+)</a>,,i) {
    my $link = $1;
    my $txt = $2;

    if (defined $story_follow_links {$baseurl} &&
      		$story_follow_links {$baseurl})
    {
      push (@turnoverlinks, $link);
      warn "(Following link: \"$txt\")\n";

    } elsif ($txt =~ m,(more|next|\d+ of \d+|&gt;&gt;),i) {
      my $urlguts = '.';
      ($baseurl =~ /^http:\/\/\S+\.([^\.\/]+\.[^\.\/]+\/).*$/) and
	  ($urlguts = $1);

      if (($txt !~ /[a-z0-9] [a-z0-9]+ [a-z0-9]+ [a-z0-9]/i) # 5 or more words
	  && (length ($txt) < 15)
	  && $link =~ m/$urlguts/)
      {
	push (@turnoverlinks, $link);
	warn "(Following 'next page' link: \"$2\")\n";
      }
    }
  }

  @turnoverlinks;
}

# ---------------------------------------------------------------------------

# We could do this smarter, but it looks really gross when converted to
# DOC format -- and this tool is primarily for that conversion. Sorry!
#
sub clean_preformatted_text {
  my $txt = $_[0];
  $txt =~ s/\n[ \t]*\n+/<p>/g;
  $txt =~ s/\n/<br>/g;
  $txt =~ s/[ \t]+/ /g;
  $txt;
}

# Work out if we should strip table items based on their size -- well,
# their width at least.
#
sub smart_clean_table {
  my $baseurl = $_[0];
  my $contents = $_[2];
  my $key = $_[3];

  if ($use_table_smarts{$key}) {
    $_ = " $_[1] "; s/\s+/ /g; s/ = /=/g; s/"//g;

    #my $replace = ' ';
    #if (defined $main::debug && $main::debug) {
      #$replace = "[table item \&lt;td$_\&gt; omitted]\n";
    #}

    if (/ width=(\d+) /i) {
      if ($1+0 < 250) { return ' '; }
    } elsif (/ width=(\d+)% /i) {
      if ($1+0 < 40) { return ' '; }
    }
  }
  $contents;
}

sub html_to_text {
  my $url = shift;
  my $baseurl = shift;
  my $page = shift;

  $page =~ s/(<pre>|<code>)(.*?)(<\/pre>|<\/code>)/
		$1.&clean_preformatted_text($2).$3;
	/gies;

  # strip all existing line breaks, they will just confuse matters
  # when we convert to text.
  $page =~ s/[\r\n]/ /gs;

  # Create bookmarks at <a name> tags
  # From Brian Lalor <blalor@hcirisc.cs.binghamton.edu>
  # via Christopher Heschong's <chris@screwdriver.net>
  # webpage-to-prc converter. Nice one lads, good trick!
  $page =~ s/<a name.*?>/$main::bookmark_char /gis;

  # a sidebar enclosed by a table? separate it from the rest of the text.
  $page =~ s/<\/tr>/\n\n/gis;
  $page =~ s/<\/table>/\n\n/gis;	# end of <table>
  $page =~ s/<\/pre>/\n\n/gis;		# end of <pre> text
  $page =~ s/<(\/h\d|h\d)(\s*[^>]+|)>/\n\n/gis;	# headings
  $page =~ s/<\/?blockquote(\s*[^>]+|)>/\n\n/gis;	# quotes
  $page =~ s/<hr(\s*[^>]+|)>/\n\n/gis;	# horiz lines
  $page =~ s/<br(\s*[^>]+|)>/\n/gis;	# end-of-line markers
  $page =~ s/<li(\s*[^>]+|)>/\n/gis;	# list items

  $page =~ s/<\/?p(\s*[^>]+|)>/\n\n/gis;
  # don't worry, multiple blank lines are sorted later

  $page =~ s/<\/td>/ /gis;		# end-of-table-item

  # strip enclosed tags we know we don't want
  $page =~ s/<head(\s*[^>]+|)>.*?<\/head>//gis;
  $page =~ s/<form(\s*[^>]+|)>.*?<\/form>//gis;
  $page =~ s/<style(\s*[^>]+|)>.*?<\/style>//gis;
  $page =~ s/<script(\s+language=[^>]+|)>.*?<\/script>//gis;
  $page =~ s/<map(\s*[^>]+|)>.*?<\/map>//gis;
  $page =~ s/<applet(\s*[^>]+|)>.*?<\/applet>//gis;
  $page =~ s/<!--.*?>//gis;		# Netscape-style comments: TODO?

  1 while ($page =~ s/<[^>]+?>//gs);	# trim all other tags

  # do a few escapes here -- the commonly used ones, as they are most
  # likely to show up capitalised where they shouldn't be.
  # The spec seems confused on this point.
  $page =~ s/\&nbsp;/ /gi;
  $page =~ s/\&amp;/\&/gi;
  $page =~ s/\&quot;/\"/gi;
  $page =~ s/\&copy;/(c)/gi;
  $page =~ s/\&reg;/(r)/gi;
  $page =~ s/\&lt;/</gi;
  $page =~ s/\&gt;/>/gi;
  $page = &remove_html_escapes ($page);	# sort the lot of 'em out

  $page =~ s/[ \t]+/ /g;		# canonicalise down to one space
  $page =~ s/\n /\n/gs;			# leading w/s on each line
  $page =~ s/\n{3,}/\n\n/gs;		# too many blank lines
  $page =~ s/^\s+//gs;			# blank space at start of story
  $page =~ s/\s+$//gs;			# blank space at end of story

  # trim multiple (blank) bookmarks
  $page =~ s/($main::bookmark_char\s+){2,}/$main::bookmark_char /gs;

  $page;
}

sub remove_html_escapes {
  # Convert special HTML characters
  # This code was shamelessly
  # stolen from http://pilot.screwdriver.net/convert.pl.txt, 
  # Christopher Heschong's <chris@screwdriver.net> webpage-to-pilot
  # conversion tool. (whoops, reinvented the wheel again --j. ;)
  #
  # In turn, he credits the following folks:
  # From: "Yannick Bergeron" <bergery@videotron.ca>
  # And Especially:  Sam Denton <Sam.Denton@maryville.com>
  #
  # Cheers lads!

  my $page = shift;
  my %escapes = (
    # first, the big four HTML escapes
    'quot',       '"',    # quote
    'amp',        '&',    # ampersand
    'lt',         '<',    # less than
    'gt',         '>',    # greater than
    # Sam got most of the following HTML 4.0 names from
    # http://spectra.eng.hawaii.edu/~msmith/ASICs/HTML/Style/allChar.htm
    'emsp',       "\x80", # em space (HTML 2.0)
    'sbquo',      "\x82", # single low-9 (bottom) quotation mark (U+201A)
    'fnof',       "\x83", # Florin or Guilder (currency) (U+0192)
    'bdquo',      "\x84", # double low-9 (bottom) quotation mark (U+201E)
    'hellip',     "\x85", # horizontal ellipsis (U+2026)
    'dagger',     "\x86", # dagger (U+2020)
    'Dagger',     "\x87", # double dagger (U+2021)
    'circ',       "\x88", # modifier letter circumflex accent
    'permil',     "\x89", # per mill sign (U+2030)
    'Scaron',     "\x8A", # latin capital letter S with caron (U+0160)
    'lsaquo',     "\x8B", # left single angle quotation mark (U+2039)
    'OElig',      "\x8C", # latin capital ligature OE (U+0152)
    'diams',      "\x8D", # diamond suit (U+2666)
    'clubs',      "\x8E", # club suit (U+2663)
    'hearts',     "\x8F", # heart suit (U+2665)
    'spades',     "\x90", # spade suit (U+2660)
    'lsquo',      "\x91", # left single quotation mark (U+2018)
    'rsquo',      "\x92", # right single quotation mark (U+2019)
    'ldquo',      "\x93", # left double quotation mark (U+201C)
    'rdquo',      "\x94", # right double quotation mark (U+201D)
    'endash',     "\x96", # dash the width of ensp (Lynx)
    'ndash',      "\x96", # dash the width of ensp (HTML 2.0)
    'emdash',     "\x97", # dash the width of emsp (Lynx)
    'mdash',      "\x97", # dash the width of emsp (HTML 2.0)
    'tilde',      "\x98", # small tilde
    'trade',      "\x99", # trademark sign (HTML 2.0)
    'scaron',     "\x9A", # latin small letter s with caron (U+0161)
    'rsaquo',     "\x9B", # right single angle quotation mark (U+203A)
    'oelig',      "\x9C", # latin small ligature oe (U+0153)
    'Yuml',       "\x9F", # latin capital letter Y with diaeresis (U+0178)
    'ensp',       "\xA0", # en space (HTML 2.0)
    'thinsp',     "\xA0", # thin space (Lynx)
   # from this point on, we're all (but 2) HTML 2.0
    'nbsp',       "\xA0", # non breaking space
    'iexcl',      "\xA1", # inverted exclamation mark
    'cent',       "\xA2", # cent (currency)
    'pound',      "\xA3", # pound sterling (currency)
    'curren',     "\xA4", # general currency sign (currency)
    'yen',        "\xA5", # yen (currency)
    'brkbar',     "\xA6", # broken vertical bar (Lynx)
    'brvbar',     "\xA6", # broken vertical bar
    'sect',       "\xA7", # section sign
    'die',        "\xA8", # spacing dieresis (Lynx)
    'uml',        "\xA8", # spacing dieresis
    'copy',       "\xA9", # copyright sign
    'ordf',       "\xAA", # feminine ordinal indicator
    'laquo',      "\xAB", # angle quotation mark, left
    'not',        "\xAC", # negation sign
    'shy',        "\xAD", # soft hyphen
    'reg',        "\xAE", # circled R registered sign
    'hibar',      "\xAF", # spacing macron (Lynx)
    'macr',       "\xAF", # spacing macron
    'deg',        "\xB0", # degree sign
    'plusmn',     "\xB1", # plus-or-minus sign
    'sup2',       "\xB2", # superscript 2
    'sup3',       "\xB3", # superscript 3
    'acute',      "\xB4", # spacing acute
    'micro',      "\xB5", # micro sign
    'para',       "\xB6", # paragraph sign
    'middot',     "\xB7", # middle dot
    'cedil',      "\xB8", # spacing cedilla
    'sup1',       "\xB9", # superscript 1
    'ordm',       "\xBA", # masculine ordinal indicator
    'raquo',      "\xBB", # angle quotation mark, right
    'frac14',     "\xBC", # fraction 1/4
    'frac12',     "\xBD", # fraction 1/2
    'frac34',     "\xBE", # fraction 3/4
    'iquest',     "\xBF", # inverted question mark
    'Agrave',     "\xC0", # capital A, grave accent
    'Aacute',     "\xC1", # capital A, acute accent
    'Acirc',      "\xC2", # capital A, circumflex accent
    'Atilde',     "\xC3", # capital A, tilde
    'Auml',       "\xC4", # capital A, dieresis or umlaut mark
    'Aring',      "\xC5", # capital A, ring
    'AElig',      "\xC6", # capital AE diphthong (ligature)
    'Ccedil',     "\xC7", # capital C, cedilla
    'Egrave',     "\xC8", # capital E, grave accent
    'Eacute',     "\xC9", # capital E, acute accent
    'Ecirc',      "\xCA", # capital E, circumflex accent
    'Euml',       "\xCB", # capital E, dieresis or umlaut mark
    'Igrave',     "\xCC", # capital I, grave accent
    'Iacute',     "\xCD", # capital I, acute accent
    'Icirc',      "\xCE", # capital I, circumflex accent
    'Iuml',       "\xCF", # capital I, dieresis or umlaut mark
    'Dstrok',     "\xD0", # capital Eth, Icelandic (Lynx)
    'ETH',        "\xD0", # capital Eth, Icelandic
    'Ntilde',     "\xD1", # capital N, tilde
    'Ograve',     "\xD2", # capital O, grave accent
    'Oacute',     "\xD3", # capital O, acute accent
    'Ocirc',      "\xD4", # capital O, circumflex accent
    'Otilde',     "\xD5", # capital O, tilde
    'Ouml',       "\xD6", # capital O, dieresis or umlaut mark
    'times',      "\xD7", # multiplication sign
    'Oslash',     "\xD8", # capital O, slash
    'Ugrave',     "\xD9", # capital U, grave accent
    'Uacute',     "\xDA", # capital U, acute accent
    'Ucirc',      "\xDB", # capital U, circumflex accent
    'Uuml',       "\xDC", # capital U, dieresis or umlaut mark
    'Yacute',     "\xDD", # capital Y, acute accent
    'THORN',      "\xDE", # capital THORN, Icelandic
    'szlig',      "\xDF", # small sharp s, German (sz ligature)
    'agrave',     "\xE0", # small a, grave accent
    'aacute',     "\xE1", # small a, acute accent
    'acirc',      "\xE2", # small a, circumflex accent
    'atilde',     "\xE3", # small a, tilde
    'auml',       "\xE4", # small a, dieresis or umlaut mark
    'aring',      "\xE5", # small a, ring
    'aelig',      "\xE6", # small ae diphthong (ligature)
    'ccedil',     "\xE7", # small c, cedilla
    'egrave',     "\xE8", # small e, grave accent
    'eacute',     "\xE9", # small e, acute accent
    'ecirc',      "\xEA", # small e, circumflex accent
    'euml',       "\xEB", # small e, dieresis or umlaut mark
    'igrave',     "\xEC", # small i, grave accent
    'iacute',     "\xED", # small i, acute accent
    'icirc',      "\xEE", # small i, circumflex accent
    'iuml',       "\xEF", # small i, dieresis or umlaut mark
    'dstrok',     "\xF0", # small eth, Icelandic (Lynx)
    'eth',        "\xF0", # small eth, Icelandic
    'ntilde',     "\xF1", # small n, tilde
    'ograve',     "\xF2", # small o, grave accent
    'oacute',     "\xF3", # small o, acute accent
    'ocirc',      "\xF4", # small o, circumflex accent
    'otilde',     "\xF5", # small o, tilde
    'ouml',       "\xF6", # small o, dieresis or umlaut mark
    'divide',     "\xF7", # division sign
    'oslash',     "\xF8", # small o, slash
    'ugrave',     "\xF9", # small u, grave accent
    'uacute',     "\xFA", # small u, acute accent
    'ucirc',      "\xFB", # small u, circumflex accent
    'uuml',       "\xFC", # small u, dieresis or umlaut mark
    'yacute',     "\xFD", # small y, acute accent
    'thorn',      "\xFE", # small thorn, Icelandic
    'yuml',       "\xFF", # small y, dieresis or umlaut mark
  );
  foreach $_ (32..126, 160..255) { $escapes{'#'.$_} = pack('c',$_); }
 
  $page =~ s/&((\w*)|(\#\d+));/$escapes{$1} || $&/egi;
  $page;
}


# ---------------------------------------------------------------------------

sub cachefilename {
  my $url = shift;

  my $cachefile;
  undef $cachefile;
  if (defined $cachedir) {
    $cachefile = $url;
    $cachefile =~ s/[^-_A-Za-z0-9]/_/g;
    $cachefile = $cachedir."/".$cachefile.".txt";
  }
}

sub newcachefilename {
  my $url = shift;

  my $cachefile;
  undef $cachefile;
  if (defined $newcachedir) {
    $cachefile = $url;
    $cachefile =~ s/[^-_A-Za-z0-9]/_/g;
    $cachefile = $newcachedir."/".$cachefile.".txt";
  }
}

sub get_cached_page {
  my $url = shift;
  my $is_dynamic_html = shift;

  my $cachefile = &cachefilename ($url);
  my $cachedpage = '';

  if (defined $cachefile && open (IN, "< $cachefile")) {
    $cachedpage = join ("\n", <IN>); close IN;
    $cachedpage;
  } else {
    undef;
  }
}

sub get_page {
  my $url = shift;
  my $is_dynamic_html = shift;
  my $page = '';

  my $cachefile = &cachefilename ($url);
  my $cachedpage = &get_cached_page ($url, $is_dynamic_html);

  if (defined $cachefile && defined $cachedpage) {
    if ($is_dynamic_html == 0) {
      &main::dbg("cached version exists");
      return $cachedpage;

    } elsif (-M $cachefile < $main::cached_front_page_lifetime
	&& -M $cachefile > 0)		# just make sure the clock is sane
    {
      &main::dbg("cached version is new enough: ".(-M $cachefile)." days");
      return $cachedpage;
    }
  }

  my $req = new HTTP::Request (GET => $url);	# TODO - support POST
  $req->headers->header ("Accept-Language" => "en",
	"Accept-Charset" => "iso-8859-1,*,utf-8");

  my $resp = $main::useragent->request ($req);
  if (!$resp->is_success) {
    warn "HTTP GET failed: ".$resp->status_line." ($url)\n";
    return undef;
  }
  $page = $resp->content;

  # REVISIT - use $resp->base as new base url

  if (defined $resp->last_modified) {
    $lastmod = undef;

    # protect against a nasty die in Time::Local::timegm().
    my $x = $SIG{__DIE__}; $SIG{__DIE__} = 'warn';
    eval {
      $lastmod = str2time ($resp->last_modified);
    };
    $SIG{__DIE__} = $x;		# a bit absurd all that, really

    if (defined $last_modtime{$url} && defined($lastmod)
      && $lastmod <= $last_modtime{$url} && !$main::refresh)
    {
      warn "Skipping (no mod since last download): $url\n";
      return undef;
    }
    $last_modtime{$url} = $lastmod;
  } else {
    $last_modtime{$url} = time;
  }

  if ($is_dynamic_html && defined $cachedpage && $cachedpage eq $page
    	&& !$main::refresh)
  {
    warn "Skipping (HTML has not changed): $url\n";
    return undef;
  }
  $page;
}

# ---------------------------------------------------------------------------
 
sub cache_page {
  my ($url, $page) = @_;
  my $cachefile = &newcachefilename ($url);
  open (OUT, "> $cachefile"); binmode OUT; print OUT $page; close OUT;
  $page;
}

# ---------------------------------------------------------------------------

sub write_as_story {
  local ($_);
  my ($url, $baseurl, $page, $headline) = @_;
  my $sitename = $name{$baseurl};

  if (defined $story_postproc{$baseurl}) {
    my $bookmark_char = $main::bookmark_char;	# convenience for PostProc
    $_ = $page;
    if (!eval $story_postproc{$baseurl}."; 1;") {
      warn "StoryPostProc failed: $@";
      # and keep the original $page
    } else {
      $page = $_;
    }
  }

  print OUTFILE "------------\n$sitename: $url\n\n";

  if (defined $headline) {
    warn "(Headline: $headline)\n";
    print OUTFILE "$main::bookmark_char $headline\n";
  } else {
    # use the first line in the story instead
    print OUTFILE "$main::bookmark_char ";
  }

  foreach $_ (split (/\n/, $page)) {
    if (!$main::longlines) {
      # wrap each line after 70 columns
      while (s/^(.{70}\S*)\s+//) {
	print OUTFILE $1."\n";
      }
    }
    print OUTFILE $_."\n";
  }

  print OUTFILE "\n\n\n";
  $stories_found++;
}

# ---------------------------------------------------------------------------

sub warn_log {
  my $msg = join ('', @_); chomp $msg;
  &log ("Warning: ", $msg);
  print STDERR @_;
}

sub die_log {
  my $msg = join ('', @_); chomp $msg;
  &log ("fatal: ", $msg);
  print STDERR @_; &cleanexit(2);
}

sub log {
  if (defined fileno LOGFILE) { print LOGFILE @_, "\n"; }
}

sub dbg {
  if (defined $main::debug && $main::debug != 0) { warn join('', @_)."\n"; }
}

sub cleanexit {
  $SIG{__WARN__} = '';
  $SIG{__DIE__} = '';
  exit @_;
}

sub AbsoluteURL {
  local ($baseurl, $_) = @_;
  s/^"//; s/"$//;	# trim quotes if necessary
  s/#.*$//g;		# we can't get bits of docs (yet)
  my $url = new URI::URL ($_, $baseurl);
  return $url->abs->as_string;
}

#===========================================================================

package Portability;

sub MyOS {
  if (defined ($Portability::MY_OS)) { return $Portability::MY_OS; }

  # FIGURE OUT THE OS WE'RE RUNNING UNDER
  # Some systems support the $^O variable.  If not available then require()
  # the Config library.  [nicked from CGI.pm -- jmason]

  my $os;
  unless ($os) {
    unless ($os = $^O) {
      require Config;
      $os = $Config::Config{'osname'};
    }
  }

  if ($os=~/win/i) {
    $os = 'Win32';
  } elsif ($os=~/vms/i) {
    $os = 'VMS';
  } elsif ($os=~/mac/i) {
    $os = 'Mac';
  } elsif ($os=~/os2/i) {
    $os = 'OS2';
  } else {
    $os = 'UNIX';
  }
  $Portability::MY_OS = $os;
}

1;

#---------------------------------------------------------------------------

package SnarfHTTP::UserAgent;
use LWP::UserAgent;

BEGIN {
  @ISA = qw(LWP::UserAgent);
  @SnarfHTTP::UserAgent::PasswdMask =
  	unpack ("c*", "IshOulDReallY#BeDoING05thISwiThSomEThInG+STrONgeRIkNoWiKNOw!");
}

sub new {
  my($class) = @_;
  my $self = new LWP::UserAgent;
  $self = bless $self, $class;
  $self;
}

sub get_basic_credentials {
  my ($self, $realm, $uri, $proxy) = @_;

  if (defined $site_passes{$realm}) {
    warn ("(using password for $uri $realm)\n");

  } else {
    warn ("Need a password to access $uri $realm.\n");
    if ($main::cgimode || !-t) { return undef; }

    print STDERR ("Username: ");
    my $user = <STDIN>; chop $user;

    print STDERR ("Password: ");
    (&Portability::MyOS eq 'UNIX') and system ("stty -echo");
    my $pass = <STDIN>; chop $pass;
    (&Portability::MyOS eq 'UNIX') and system ("stty echo"); print "\n";

    $site_logins{$realm} = $user;
    $site_passes{$realm} = $pass;
  }

  ($site_logins{$realm}, $site_passes{$realm});
}

sub load_logins {
  if (defined %site_logins) { return %site_logins; }

  open (IN, '< '.$main::user_tmpdir.'/site_logins') or return undef;
  %site_logins = ();
  %site_passes = ();

  #$site_logins{'tst'} = $site_passes{'tst'} = "jmason"; &save_logins; #JMD

  while (<IN>) {
    s/[\r\n]+$//g;
    my ($ver, $user, $pass, $realm) = split (/###/);
    if (defined $realm && $ver+0 == 0) {
      $site_logins{$realm} = $user;

      my @mask = @SnarfHTTP::UserAgent::PasswdMask;
      my @input = split (' ', $pass);
      my $pass_open = '';
      my $i = 0;

      foreach $_ (@input) {
	my $ch = (($_ ^ $mask[$i++ % $#mask]) ^ 0xaa);
	last if ($ch == 0);
	$pass_open .= sprintf ("%c", $ch);
      }

      $site_passes{$realm} = $pass_open;
    }
  }
  close IN;

  #print "[", $site_logins{'tst'}, "][", $site_passes{'tst'}, "]\n"; exit; #JMD
}

sub save_logins {
  if (!defined %site_logins) { return; }
  my $towrite = '';

  foreach $realm (sort keys %site_logins) {
    my @mask = @SnarfHTTP::UserAgent::PasswdMask;
    my @input = (unpack ("c*", $site_passes{$realm}));
    my $pass_disguised = '';
    my $i = 0;

    foreach $_ (@input) {
      $pass_disguised .= (($_ ^ 0xaa) ^ $mask[$i++ % $#mask]) . " ";
    }
    while ($i < int(($#input / 16) + 1) * 16) {
      $pass_disguised .= ((0 ^ 0xaa) ^ $mask[$i++ % $#mask]) . " ";
    }
    chop $pass_disguised;

    $towrite .= "0###". $site_logins{$realm}. "###". $pass_disguised.
    		"###". $realm. "\n";
  }

  # again, all at once to minimise contention
  open (OUT, '> '.$main::user_tmpdir.'/site_logins') or
  	(warn ("failed to write to site_logins file!\n"), return);
  print OUT $towrite;
  close OUT or warn ("failed to write to site_logins file!\n");
}

1;

#---------------------------------------------------------------------------

package SnarfCGI;

$cgi_cookie = undef;

sub set_cookie {
  my ($userid) = @_;
  $cgi_cookie = $main::cgi->cookie(-name=>'snarfnews', -value=>"$userid");
  print $main::cgi->header(-cookie=>$cgi_cookie);
}

sub get_cookie {
  my $cookie = $main::cgi->cookie('snarfnews');
  return unless defined ($cookie);

  my ($uid, $x) = split ('#', $cookie);
  ($uid =~ /(\d+)/) and ($main::userid = $1);
}

sub print_input_form {
  # REVISIT
}

sub print_results_links {
  # REVISIT
}

sub get_prc_file {
  # REVISIT
}

1;

# TODO:
#
# finish CGI support
# CGI: finish cookie userid support -- passwords
#
#---------------------------------------------------------------------------
# vim:sw=2:tw=74:
