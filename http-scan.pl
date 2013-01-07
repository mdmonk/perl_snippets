#!/usr/bin/perl
#---------------------------------------
#
# Basic scanner.
#   Writen by MadHat (madhat@unspecific.com)
# http://www.unspecific.com/scanner/
#
# Accepts an XML conf file for rules of
# what to look for and what to expect.
#
# Both command line and web based interface.
#
# Copyright (c) 2001-2002, MadHat (madhat@unspecific.com)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the 
#     distribution.
#   * Neither the name of MadHat Productions nor the names of its
#     contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#---------------------------------------

# Location of nmap is you wish to use that functionality
##$nmap = '/usr/local/bin/nmap';
$nmap = '/sw/bin/nmap';


# status page is the page that may contain info about version (useful on
# custom Apache builds that try to hide version from the banner).
my $status_pages = "status|server-status|sstatus";
# The "UserAgent" that will be sent with a -H to hide the real version info
my $hidden_agent = 'Mozilla/4.0 (compatible; MSIE 5.5; AOL 7.0; Windows 98; Compaq)';
# The default config file
my $default_config = './http-scan.xml';
##my $default_config = '/sw/etc/http-scan.xml';
# in the CLI mode, what to use to seperate the fields returned
my $delimiter = ' | ';
# Added SMTP testing, including Relay testing, this is the email address to send to
##my $relay_mail = 'madhat@unspecific.com';
my $relay_mail = 'scanner@dftech.org';

#
#
@cgi_dirs = ('bin', 
             'cgi', 
             'mpcgi', 
             'cgi-bin', 
             'cgi-bin-sbd', 
             'cfide', 
             '_mem_bin', 
             '_vti_bin', 
             '_vti_pvt', 
             '_cti_pvt', 
             '_vti_cnf', 
             '_vti_log', 
             '_vti_txt', 
             '_vti_inf', 
             '_vti_script', 
             'msadc', 
             'IISADMPWD', 
             '_vti_bin/_vti_adm', 
             '_vti_bin/_vti_aut', 
             'cgi-sys', 
             'cgi-local', 
             'htbin', 
             'cgibin', 
             'cgis', 
             'Mail', 
             'News', 
             'scripts', 
             'script', 
             'certsrv', 
             'cgi-win', 
             'cgi-dos', 
             'cgi-shl', 
             'fcgi-bin');


#---------------------------------------
# Don't change anything below here unless you know what you are doing.
#---------------------------------------


# scanner version string
#---------------------------------------
my $VERSION = '3.6.70';

# we need at least this version of perl
#---------------------------------------
require v5.6.0;

# what modules do we need
#---------------------------------------
use CGI qw/:standard/;
use LWP::UserAgent;
use Net::FTP;
use Net::SMTP;
use Crypt::SSLeay;
use Net::SSLeay qw(sslcat);
use Getopt::Std;
use Time::HiRes qw(alarm);
use POSIX qw(:sys_wait_h);
use Socket qw(:DEFAULT :crlf);
use XML::Parser;
use locale;
use HTML::Parser;
use Digest::MD5  qw(md5_hex);

# how to handle certain signals
#---------------------------------------
$SIG{CHLD}='IGNORE';
$SIG{USR1}=\&vulns_found;
$SIG{USR2}=\&live_host;
$SIG{ALRM}=\&ALARM;


# basic info intialization
#---------------------------------------
($cli_exec, @cli_options) = split(' ', $0);
my @path = split('/', $cli_exec);
$cli_exec = pop @path;
my $cli_path = join('/', @path) . '/';
$agent = "http-scan/$VERSION (http://www.unspecific.com/scanner/)";
$update_url = "http://www.unspecific.com/scanner/$default_config";
$| = 42;
$start_time = time;
$parent = $$;
alarm(0);

#---------------------------------------
# MAIN STUFF
#---------------------------------------


#---------------------------------------
my @CHILDREN, @scans, @check_cgi, @iplist;
my $HTML, $CGI, $add_all, $finger;
my %fingered;

# determine if it is a CGI, if so print necessary info for
# CGI output
#---------------------------------------
if ($ENV{'GATEWAY_INTERFACE'} =~ /CGI/) {
  $| = $CGI = 1;
}


# creation of the scanner or show the usage if not enough info
#---------------------------------------
if (!$CGI) {
  getopts("aC:d:De:Ff:hH:i:I:l:LmM:n:No:O:p:PrsS:t:T:u:UvVw:");
  
  if ($opt_V) {
    print "\n : The Scanner v$VERSION - MadHat (at) Unspecific.com\n";
    print " : http://www.unspecific.com/scanner\n\n";
    exit;
  }
# show usage if -h or not -i or -l as well as default vaules for
# number of processes and the timeout and port used
#---------------------------------------
  &update_config if ( defined($opt_U) );
  &scan_usage if ( defined($opt_h) );
  &show_vulns if ( defined($opt_L) );
  if ( !( defined($opt_i) xor defined($opt_l) ) ) {
    if ($#ARGV == 0) {
      $opt_v = 1;
      $opt_S = 'a';
      $opt_l = $ARGV[0];
    } else {
      &scan_usage ;
    }
  }
  $opt_n = 16  if ( ! defined($opt_n) );
  $opt_t = 2  if ( ! defined($opt_t) );
  if ($opt_T and !$opt_S) {
    $opt_S = 'a';
  }
  if (!$opt_S and !$opt_e and !$opt_u) {
    $opt_v++;
  }
  if (!$opt_p) { $no_port++; }
  if ( defined($opt_s) and ! defined($opt_p) ) {
    $opt_p = 443;
  } elsif (! defined($opt_p) ) {
    if ($opt_w eq 'ftp' or $cli_exec =~ /^ftp/) {
      $opt_p = 21;
    } elsif ($opt_w eq 'smtp' or $cli_exec =~ /^smtp/) {
      $opt_p = 25;
    } elsif ($opt_w eq 'sql' or $cli_exec =~ /^sql/) {
      $opt_p = 1434;
    } elsif ($opt_w =~ /http|all/ or $cli_exec =~ /^http/ ) {
      $opt_p = 80;
    }
    print STDERR "$cli_exec ($$): set \$opt_p to $opt_p from options\n"
      if ($opt_d > 1);
  } 
# what kind of output do we want to use
#---------------------------------------
  if ($opt_O eq 'h') {
    $HTML = 1;
    my $JS = &load_javascript;
    my $CSS = &load_css;
    print start_html(-title=>"http-scan/$VERSION", 
      -script=>$JS, -style=>{-code=>$CSS}, -onLoad=>'javascript:hideScanning()'
      ), '<div class="helpMenu" id="temp"></div><pre>';
  }
  $XML = 1 if ($opt_O eq 'x');
  $agent = $opt_D?$hidden_agent:$agent;
  if ($opt_d > 1) {
    print STDERR "$cli_exec ($$): \$opt_l = $opt_l\n";
    print STDERR "$cli_exec ($$): \$opt_v = $opt_v\n";
    print STDERR "$cli_exec ($$): \$opt_f = $opt_f\n";
    print STDERR "$cli_exec ($$): \$opt_p = $opt_p\n";
    print STDERR "$cli_exec ($$): \$opt_O = $opt_O\n";
    print STDERR "$cli_exec ($$): \$opt_n = $opt_n\n";
    print STDERR "$cli_exec ($$): \$opt_N = $opt_N\n";
    print STDERR "$cli_exec ($$): \$opt_F = $opt_F\n";
    print STDERR "$cli_exec ($$): \$opt_m = $opt_m\n";
    print STDERR "$cli_exec ($$): \$opt_t = $opt_t\n";
    print STDERR "$cli_exec ($$): \$opt_i = $opt_i\n";
    print STDERR "$cli_exec ($$): \$opt_a = $opt_a\n";
    print STDERR "$cli_exec ($$): \$opt_C = $opt_C\n";
    print STDERR "$cli_exec ($$): \$opt_s = $opt_s\n";
    print STDERR "$cli_exec ($$): \$opt_S = $opt_S\n";
    print STDERR "$cli_exec ($$): \$opt_u = $opt_u\n";
    print STDERR "$cli_exec ($$): \$opt_e = $opt_e\n";
    print STDERR "$cli_exec ($$): \$opt_M = $opt_M\n";
    print STDERR "$cli_exec ($$): \$opt_T = $opt_T\n";
    print STDERR "$cli_exec ($$): \$opt_H = $opt_H\n";
    print STDERR "$cli_exec ($$): \$opt_D = $opt_D\n";
    print STDERR "$cli_exec ($$): \$opt_U = $opt_U\n";
    print STDERR "$cli_exec ($$): \$opt_L = $opt_L\n";
    print STDERR "$cli_exec ($$): \$opt_w = $opt_w\n";
  }
# take the input from the HTML input and convert to the 
# command line input values (so we just have one scanner)
#---------------------------------------
} elsif ( param('l') or param('L') ) {
  $HTML = 1;
  my $JS = &load_javascript;
  my $CSS = &load_css;
  print header, start_html(-title=>"http-scan/$VERSION", 
    -script=>$JS, -style=>{-code=>$CSS}, -onLoad=>'javascript:hideScanning()'
    ), '<div class="helpMenu" id="temp"></div><pre>';
  # temp fix/workaround
  $opt_w = 'all';
  #
  $opt_l = param('l');
  $opt_v = param('v')?param('v'):'';
  $opt_d = param('d')?param('d'):'0';
  $opt_e = param('e')?param('e'):'';
  $opt_t = param('t')?param('t'):'2';
  $opt_f = param('f')?param('f'):'';
  $opt_s = param('s')?param('s'):'';
  $opt_m = param('m')?param('m'):'';
  $opt_M = param('M')?param('M'):'';
  $opt_N = param('N')?param('N'):'';
  $opt_n = param('n')?param('n'):'16';
  $opt_F = param('F')?param('F'):'';
  $opt_u = param('u')?param('u'):'';
  $opt_p = param('p')?param('p'):'';
  $opt_a = param('a')?param('a'):'';
  $opt_L = param('L')?param('L'):'';
  $opt_S = param('S')?join(',',param('S')):'';
  $opt_T = param('T')?join('|',param('T')):'';
  if (!$opt_S and $opt_f) { undef $opt_S }
  $agent = param('D')?$hidden_agent:$agent;
  $opt_l =~ s/\s*//g;
  $date = scalar localtime;
  @options = split('\/', $cli_exec);
  $cli_exec  = @options[-1];
  print STDERR "[$date] HTTP Scanning $opt_l from $ENV{'REMOTE_ADDR'} by $ENV{'REMOTE_USER'}\n";
  open (STDERR, ">&STDOUT") or die ("$!\n") if ($opt_d);
  if ($opt_d > 1) {
    print STDERR "$cli_exec ($$): \$opt_l = $opt_l\n";
    print STDERR "$cli_exec ($$): \$opt_v = $opt_v\n";
    print STDERR "$cli_exec ($$): \$opt_f = $opt_f\n";
    print STDERR "$cli_exec ($$): \$opt_p = $opt_p\n";
    print STDERR "$cli_exec ($$): \$opt_O = $opt_O\n";
    print STDERR "$cli_exec ($$): \$opt_n = $opt_n\n";
    print STDERR "$cli_exec ($$): \$opt_N = $opt_N\n";
    print STDERR "$cli_exec ($$): \$opt_F = $opt_F\n";
    print STDERR "$cli_exec ($$): \$opt_m = $opt_m\n";
    print STDERR "$cli_exec ($$): \$opt_t = $opt_t\n";
    print STDERR "$cli_exec ($$): \$opt_i = $opt_i\n";
    print STDERR "$cli_exec ($$): \$opt_a = $opt_a\n";
    print STDERR "$cli_exec ($$): \$opt_C = $opt_C\n";
    print STDERR "$cli_exec ($$): \$opt_s = $opt_s\n";
    print STDERR "$cli_exec ($$): \$opt_S = $opt_S\n";
    print STDERR "$cli_exec ($$): \$opt_u = $opt_u\n";
    print STDERR "$cli_exec ($$): \$opt_e = $opt_e\n";
    print STDERR "$cli_exec ($$): \$opt_M = $opt_M\n";
    print STDERR "$cli_exec ($$): \$opt_T = $opt_T\n";
    print STDERR "$cli_exec ($$): \$opt_H = $opt_H\n";
    print STDERR "$cli_exec ($$): \$opt_D = $opt_D\n";
    print STDERR "$cli_exec ($$): \$opt_U = $opt_U\n";
    print STDERR "$cli_exec ($$): \$opt_L = $opt_L\n";
    print STDERR "$cli_exec ($$): \$opt_w = $opt_w\n";
  }
  &show_vulns if ( $opt_L == 1 );
# HTML interface for choosing the scan and hosts
#---------------------------------------
} else {
  $HTML = 1;
  my $JS = &load_javascript;
  my $CSS = &load_css;
  %debug_labels = (''=>'none', '1'=>'Low', 
                   '2'=>'Detail level 2', 
                   '3'=>'Detail level 3', 
                   '4'=>'Detail level 4', 
                   '5'=>'Detail level 5', 
                   '6'=>'Detail level 6', 
                   '7'=>'Detail level 7', 
                   '8'=>'Detail level 8', 
                   '9'=>'Annoying');
  print header, start_html(-title=>"http-scan/$VERSION Input Form", 
    -script=>$JS, -style=>{-code=>$CSS}), '<div class="helpMenu" id="temp"></div>',
    "<h2 align=center>http-scan/$VERSION</h2><br>",
    "<b>Welcome $ENV{'REMOTE_USER'}</b>",
    "<table><tr><td width=50%><table>\n",
    start_form(-name=>"scanner"), 
    "<tr><td>Host List (see examples below): </td><td>",
    textfield(-name=>'l', -value=>$ENV{'REMOTE_ADDR'}), "</td></tr>\n",
    "<tr><td>Port to check on each host: </td><td>",
    textfield(-name=>'p',-value=>'80',-size=>'4'), "</td></tr>\n",
    "<tr><td>Request Method to use: </td><td>",
    textfield('M'), "</td></tr>\n",
    "<tr><td>URL to look for on each host: </td><td>",
    textfield('u'), "</td></tr>\n",
    "<tr><td>Expression to look for in the URL: </td><td>",
    textfield('e'), "</td></tr>\n",
    "<tr><td>Timeout for each request: </td><td>",
    textfield(-name=>'t',
    -value=>'2', -size=>'3'), "sec</td></tr>\n",
    "<tr><td>Number of parallel processes: </td><td>",
    textfield(-name=>'n', -value=>'16', -size=>'3'), "</td></tr>\n",
    "</table>",
    checkbox(-name=>'f', -value=>$default_config, -label=>'Use default Scans', -checked=>'checked'), br,
    checkbox(-name=>'s', -label=>'Use SSL (https), works on ANY port',
      -onClick=>"change_port()"), br,
    checkbox(-name=>'N', -label=>'Lookup NetBIOS name via NBT (can slow it down)'), br,
    checkbox(-name=>'F', -label=>'Show FIX with results'), br,
    checkbox(-name=>'a', -label=>'Force scan ALL vulns reguardless of server version returned'), br,
    checkbox(-name=>'m', -label=>'Show last-modified date when matches are found'), br,
    checkbox(-name=>'v', -label=>'Verbose output', -checked=>'checked',),br,
    checkbox(-name=>'D', -label=>"Disguise the request as $hidden_agent"), br,
    "Debug Level: ", popup_menu(-name=>'d', -values=>['','1','2','3','4','5','6','7','8','9'],
    -labels=>\%debug_labels), br,
    submit('Scan'),
    "</td><td valign=top><font size=-2>
<pre>Host List Syntax:
   a.b.c.d/n       - 10.0.0.1/25
   a.b.c.*         - 10.0.0.* (0-255) same as /24
   a.b.c.d/w.x.y.z - 10.0.0.0/255.255.224.0 (standard format)
   a.b.c.d/w.x.y.z - 10.0.0.0/0.0.16.255    (cisco format)
   a.b.c.d-z       - 10.1.2.0-12
   a.b.c-x.*       - 10.0.0-3.*  (last octet has to be * or 0)
   a.b.c-x.d       - 10.0.0-3.0
   hostname        - www.unspecific.com

   /30    255.255.255.252        4 IPs
   /29    255.255.255.248        8 IPs
   /28    255.255.255.240       16 IPS
   /27    255.255.255.224       32 IPs
   /26    255.255.255.192       64 IPs
   /25    255.255.255.128      128 IPs
   /24    255.255.255.0        256 IPs
   /23    255.255.254.0        512 IPs
   /22    255.255.252.0       1024 IPs
   /21    255.255.248.0       2048 IPs
   /20    255.255.240.0       4096 IPs
   /19    255.255.224.0       8192 IPs
   /18    255.255.192.0      16384 IPs
   /17    255.255.128.0      32768 IPs
   /16    255.255.0.0        65536 IPs</pre></font><br>",
    checkbox(-name=>'T', -value=>'HIGH' , -label=>"Scan HIGH Level Vulns"), br,
    checkbox(-name=>'T', -value=>'Medium' , -label=>"Scan Medium Level Vulns"), br,
    checkbox(-name=>'T', -value=>'Low' , -label=>"Scan Lows Level Vulns"), br,
    checkbox(-name=>'T', -value=>'Informational' , -label=>"Scan Informational Level Vulns"), br,
    "<em>Not checking any will scan everything.</em><br><br>
<a href=?L=1&S=1>Search Vulnerability Database</a>
</td></tr></table>
";
}

# as seen in lwp-request
{
  package RequestAgent;
  @ISA = qw(LWP::UserAgent);
  sub new {
        my $self = LWP::UserAgent::new(@_);
        $self;
  }
  sub get_basic_credentials {
    if ($main::user and $main::pass) {
      print STDERR "$main::cli_exec ($$): Passworded, using "
        . " $main::user:$main::pass.\n" 
        if ($main::opt_d > 1);
      return($main::user, $main::pass);
    } else {
      print STDERR "$main::cli_exec ($$): Passworded, no password provided.\n" 
        if ($main::opt_d > 1);
      return (undef, undef);
    }
  }
}

# basic scan calls and final process management as well as
# output management
#---------------------------------------
if ( defined($opt_o) ){
  open(STDOUT, ">$opt_o") || die ("Cannot open output file $opt_o\n")
}
select(STDOUT);
$scanned_count = 0;

print "A Scanner (v$VERSION) by MadHat (at) Unspecific.com\n" if ($opt_v);

&doScan;
# wait for all the children to die and kill off any lingering processes
#---------------------------------------
WAIT: while ( $#CHILDREN >= 0 ){
  my $CHILD_pos = 0;
  my $CHILD_count = $#CHILDREN + 1;
  for $pid (@CHILDREN) {
    print STDERR "$cli_exec ($$): verifying child $pid \n"
      if ($opt_d > 5);
    $waitpid = waitpid($pid, WNOHANG);
    if ($waitpid != 0) {
      print STDERR "$cli_exec ($$): child $pid exited, cleaning up ($? $waitpid)\n"
        if ($opt_d > 1);
      
      splice(@CHILDREN, $CHILD_pos, 1);
      kill 9, $pid;
      next WAIT;
      $CHILD_count = $#CHILDREN + 1;
    } else {
      $CHILD_pos++;
    }
  }
  print STDERR "$cli_exec ($$): sleep waiting to exit for $CHILD_count children $CHILDREN[-1]\n"
    if ($opt_d > 5);
  sleep 1 if ( $#CHILDREN );
}

if ($opt_v and @report_cgi) {
  my $CGIs = "\nPossible CGI Directories Found: ";
  $CGIs .= join ', ', @report_cgi;
  $CGIs .= "\n";
  $CGIs = swrite(<<'END', "$CGIs");
^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ~~
END
  print $CGIs;
} elsif ($opt_v and !@report_cgi and $#iplist == 0 and $opt_S) {
  print "\nNo valid CGI directories found to be testable.\n";
}

# print the stats if necessary and finished messages
#---------------------------------------
print "<pre>\n" if ($HTML);
print "\n--\nScan Finished.\n";
$end_time = time;
$timediff = $end_time - $start_time;
$timediff = $timediff?$timediff:1;
$ipcount = $#totallist + 1;
$total_count = $total_count?$total_count:0;
$total_vulns = $total_vulns?$total_vulns:0;
$lookingfor = @scans?'vulnerabilities':'matches';
print "Scan of $ipcount ip(s) took $timediff seconds\n" if ($opt_v);
print "Of $ipcount ip(s), $total_count are listening\n" if ($opt_v and $#iplist > 0);
print "$vuln_count vulnerabilities examined on these $total_count hosts\n" if ($opt_v and $vuln_count);
print "$real_scanned vulnerabilities actually tested\n" if ($opt_v
and $real_scanned and $#iplist == 0);
if ($#iplist > 0) {
  print "A possible $total_vulns $lookingfor found on these $total_count hosts\n" if ($opt_v and $total_vulns);
} else {
  print "A possible $total_vulns $lookingfor found on this host\n" if ($opt_v and $total_vulns);
}
printf ("%.1f ips/sec - %.1f hosts/sec\n", $ipcount/$timediff, $total_count/$timediff)  if ($opt_v and $#iplist > 0);
printf ("%.1f checks/sec\n", $vuln_count/$timediff)  if ($opt_v and $vuln_count > 0);
print "</pre>\n</body>\n</html>\n\n" if ($HTML);
close(STDOUT);

# preparing the scan by generatig the complete IP list
# and grabbing the config
#---------------------------------------
sub doScan{
  print "Initalizing" if ($opt_v and !$HTML);
  print "<div id=init1 align=center><b>Initalizing Scanner...</b></div>" 
    if ($opt_v and $HTML);
  print "<div id=hint class=hint align=center>"
    if ($HTML and !$opt_F);
  print "<table><tr><td>Hold cursor over a vulnerability to show information "
    . "about the vulnerability, including FIX, severity and external "
    . "inforamtion.\n If your browser does not support CSS and/or Javascript,"
    . "go back and check, 'Show Fix' to enable displaying basic fix info.\n"
    . "</td></tr></table><hr width=40% noshade size=1>" 
    if ($HTML and ($opt_T or $opt_f or $opt_S) and !$opt_F);
  print "<b>Scan Finished</b></div>\n"
    if ($HTML and !$opt_F);
  if ($opt_w =~ /http/) {
    print "Scanning " . ($opt_u?"for the URL '/$opt_u'":'the default webpage') 
      . " looking for " .  ($opt_e?$opt_e:'versioning info') 
      .  ($opt_s?' w/ SSL':'') . "\n" 
      if ( defined($opt_v)  and (!$opt_f and !$opt_S));
  }
  print STDERR "Debug Level: " . $opt_d . "\n" if ($opt_d);
  print STDERR "Running as a CGI\n" if ($opt_d and $HTML);
# initialize the RequestAgent, 'Agent' and TimeOut vaules
  $ua = RequestAgent->new;
  $ua->agent($agent);
  $ua->timeout($opt_t);
  print "." if ($opt_v and !$HTML);
# Load everything
  if ($opt_f or $opt_S) {
    if (!$opt_f and -e $default_config ) {
      $opt_f = $default_config;
      print STDERR "$cli_exec ($$): setting -f to $opt_f\n"
        if ( $opt_d );
    } elsif (!$opt_f and -e "$cli_path/$default_config") {
      $opt_f = "$cli_path/$default_config";
      print STDERR "$cli_exec ($$): setting -f to $opt_f\n"
        if ( $opt_d );
    }
    if ($opt_S) {
      print STDERR "$cli_exec ($$): Using scans $opt_S\n"
        if ( $opt_d );
      @Tscans = split(',', $opt_S);
    }
    if ($opt_I) {
      print STDERR "$cli_exec ($$): Ignoring scans $opt_I\n"
        if ( $opt_d );
      my @Iss = split(',', $opt_I);
      for my $Is (@Iss) {
        if ($Is =~ /^(\d+)\-(\d+)$/) {
          for ($1..$2) {
            push @Iscans, $_;
          }
        } elsif ($Is =~ /^\d+$/) {
          push @Iscans, $Is;
        }
      }
    }
    SCANID: for my $vid (@Tscans) {
      if ($vid =~ /^\d+$/ and ! grep /^$vid$/, @Iscans) {
        print STDERR "$cli_exec ($$): Adding Scan \#$vid to \@scans\n"
          if ( $opt_d > 4 );
        push @scans, $vid;
      } elsif ($vid =~ /^(\d+)\-(\d+)$/) {
        for $rid ($1..$2) { 
          if (grep /^$rid$/, @Iscans) {
            print STDERR "$cli_exec ($$): Ignoring Scan \#$rid \n"
              if ( $opt_d > 4 );
          } else {
            print STDERR "$cli_exec ($$): Adding Scan \#$rid to \@scans\n"
              if ( $opt_d > 4 );
            push @scans, $rid;
          }
        }
      } elsif ($vid eq 'a') {
        print STDERR "$cli_exec ($$): Adding ALL SCANS to \@scans\n"
          if ( $opt_d );
        @scans = ('a');
        last SCANID;
      }
    }
    print STDERR "$cli_exec ($$): Opening $opt_f with XMLin\n"
      if ( $opt_d );
    print "." if ($opt_v and !$HTML);
    &load_vulns;
    %rules = %vulns;
  }
  if ($opt_f or -e $default_config) {
    $opt_f = $default_config if (!$opt_f);
    print STDERR "$cli_exec ($$): setting -f to $opt_f\n"
      if ( $opt_d );
    print "." if ($opt_v and !$HTML);
    &load_vulns(1);
  }
  if (!$opt_f and -e "$cli_path/$default_config") {
    $opt_f = "$cli_path/$default_config";
    print STDERR "$cli_exec ($$): setting -f to $opt_f\n"
      if ( $opt_d );
    print "." if ($opt_v and !$HTML);
    &load_vulns(1);
  }
# generate the list of IPs
  my @nets;
  if ( defined($opt_i) ){
    open(FIN, "$opt_i" ) || die "cannot open $opt_i\n";
    @nets=<FIN>;
    close(FIN);
  } elsif ( defined($opt_l) ) {
    if ($opt_l eq '-') {
      print "\nEnter your IPs now (end with ^D):\n";
      $opt_l = join(',', <STDIN>);
    }
    @nets = split(',', $opt_l);
  }
  print ".\n" if ($opt_v and !$HTML);
  if ($ENV{HTTP_USER_AGENT} =~ /MSIE/) {
    $open_action = "<marquee behavior=scroll direction=left loop=infinite scrollamount=3 scrolldelay=50 width=200>";
    $close_action = "</marquee>";
  } else {
    $open_action = "<blink>";
    $close_action = "</blink>";
  }
  print "<div id=init2 align=center>$open_action<b>" if ($opt_v and $HTML);
  foreach $net (@nets){
    chomp $net;
    next if ($net =~ /^#/ or $net =~ /^$/);
    if (defined($opt_v) and $#nets < 5) {
      print "Scanning $net\n" 
    }
    @cur_iplist = calculate_ip_range($net);
    push(@totallist, @cur_iplist);
  }
  if ($opt_v and $#nets > 4) {
    print "Scanning Targets\n";
  }
  print "</b>$close_action</div>\n" if ($opt_v and $HTML);
  if (!@totallist) { 
    if ($opt_l =~ /^[\w\.]+$/) {
      die "Unable to find host $opt_l\n";
    } else {
      die "Error in the IP list. Check syntax.
    IP list entered: $iplist
    Allowed Syntax:
    a.b.c.d/n       - 10.0.0.1/25
    a.b.c.*         - 10.0.0.* (0-255) same as /24
    a.b.c.d/w.x.y.z - 10.0.0.0/255.255.224.0 (standard format)
    a.b.c.d/w.x.y.z - 10.0.0.0/0.0.16.255    (cisco format)
    a.b.c.d-z       - 10.1.2.0-12
    a.b.c-x.*       - 10.0.0-3.*  (last octet has to be * or 0)
    a.b.c-x.d       - 10.0.0-3.0
    hostname        - www.unspecific.com
  \n"; 
    }
  }
# do the real scanning
  scanNet(@totallist);
}

# main body of the code for checking vulns and process management
#---------------------------------------
sub scanNet{
  @iplist = @_;
  my $prnt = 1;  # 
  for ( $i = 0; $i<=$#iplist; $i++ ){
    my $ipaddr = $iplist[$i];
    chomp $ipaddr;
    WAIT: while ( $#CHILDREN >= $opt_n ){
      print STDERR "$cli_exec ($$): Parent waiting. $i of "
        . ($#iplist + 1) . " ($#CHILDREN Running)\n" 
        if ($opt_d > 1);
      my $CHILD_pos = 0;
      for $pid (@CHILDREN) {
        $waitpid = waitpid($pid, WNOHANG);
        if ($waitpid != 0) {
          print STDERR "$cli_exec ($$): child $pid exited, cleaning up ($?)\n"
            if ($opt_d > 1);
          splice(@CHILDREN, $CHILD_pos, 1);
          kill 9, $pid;
          next WAIT;
        }
        $CHILD_pos++;
      } 
      sleep 1;
    }
    my $thisthread = fork unless ($#iplist == 0);
    if ( !defined($thisthread) and $#iplist >= 1 ) {
      print "FORK Died $ipaddr <=========\n"; 
    } else {
      if ( $thisthread == 0 ) {
        my $port_status;
        my $opt_p = $opt_p;
        if ($ipaddr =~ s/^(.+):(\d{1,5})/$1/) { $opt_p = $2 }
        add_debug("$cli_exec ($$): HELP ME\n") if ($opt_d);
        if ($opt_P and -e $nmap) {
          add_debug("$cli_exec ($$): Scanning for open ports with NMAP\n") 
            if ($opt_d);
          if ($no_port) {
            $nmap_data = `$nmap -sV -oG - $ipaddr`;
          } else {
            $nmap_data = `$nmap -sV -oG - $ipaddr -p$opt_p`;
          }
          add_debug("$nmap_data") if ($opt_d > 3);
          my ($host, $ports, @ignored) = split ("\t", $nmap_data);
          my ($title, $port_info) = split(': ', $ports);
          for my $ports (split ', ', $port_info) {
            my ($port, $state, $protocol, $owner, $service, $rpc_info, $version)
              = split('/', $ports);
            if ($state eq 'open' and $service eq 'http') {
              push(@opt_p, $port);
              add_debug("$cli_exec ($$): Adding $port to list of ports\n")
                if ($opt_d);
            }
          }
        } elsif ($opt_P and ! -e $nmap) {
          die "$cli_exec ($$): NMAP not found at $nmap, check your settings\n";
        } else {
          add_debug("$cli_exec ($$): Not scanning for open ports with
NMAP\n") 
            if ($opt_d);
        }
        if (!@opt_p) { @opt_p = split(',', $opt_p); }
        for $opt_p (@opt_p) {
          $0 = "http-scanning $ipaddr:$opt_p";
          $output = '';
          print STDERR "$cli_exec ($$): http-scanning $ipaddr:$opt_p\n"
            if ($opt_d);
          if ( ! check_port($ipaddr, $opt_p, 'TCP', $opt_t) ) {
            print STDERR "$cli_exec ($$): Scan completed for $ipaddr:$opt_p\n" 
              if ($opt_d);
            $port_status = 1;
            # exit 0 unless ($#iplist ==0);
          }
          kill USR2, $parent unless ($port_status);
          #
          # $total_count++;
          $dnsaddr = inet_aton($ipaddr);
          $dnsname = gethostbyaddr($dnsaddr, AF_INET);
          $dnsname = $dnsname?$dnsname:'NOT_IN_DNS';
          print STDERR "$cli_exec ($$): got $dnsname from DNS server for $ipaddr\n" 
            if ($opt_d);
          $output .= "<b><a target=\"_blank\" href=\"$cli_exec?v=$opt_v" . 
            "&l=$ipaddr&N=$opt_N&f=$opt_f&t=$opt_t&p=$opt_p&M=$opt_M" . 
            "&e=$opt_e&u=$opt_u&F=$opt_F&n=1&s=$opt_s&m=$opt_m&T=$opt_T\">"
               if ($HTML);
          $output .= "$ipaddr ($dnsname)";
          $output .= "</a></b><br>" if ($HTML);
          $output .= "<hr noshade>" if ($opt_d > 2 and ($HTML));
          $output .= "\n";
          my $tried_detect;
          if ($opt_N) {
            add_debug("$cli_exec ($$): Getting NetBIOS data for $ipaddr\n")
              if ($opt_d > 1);
            $netbios = &nbtscan($ipaddr);
          }
          $output .= "\n<table border=0 cellpadding=2 cellspacing=0 class=vulnInfo width=100%>" if ($HTML);
          ########
          # Do SQL Scan
          if (
            ( $cli_exec =~ /sql/ and !$opt_w )
            or $opt_w =~ /sql|all/
          ) {
            my $opt_p = $opt_p;
            if ($opt_w ne 'sql') {
              $opt_p = 1434;
            }
            print STDERR "$cli_exec ($$): SQL Scan of $ipaddr:$opt_p\n" 
              if ($opt_d);
            &scan_sql($ipaddr,$opt_p,%rules);
          }
          ########
          # Do FTP Scan
          if (
            ( $cli_exec =~ /ftp/ and !$opt_w )
            or $opt_w =~ /ftp|all/
          ) {
            my $opt_p = $opt_p;
            print STDERR "$cli_exec ($$): FTP Scan of $ipaddr\n" 
              if ($opt_d);
            if ($opt_w ne 'ftp') {
              $opt_p = 21;
            }
            my $ftp_status = check_port($ipaddr, $opt_p, 'TCP', $opt_t);
            if ($ftp_status) {
              &scan_ftp($ipaddr, $opt_p, %rules);
            }
          }
          ########
          # Do SMTP Scan
          if (
            ( $cli_exec =~ /smtp/ and !$opt_w )
            or $opt_w =~ /smtp|all/
          ) {
            my $opt_p = $opt_p;
            print STDERR "$cli_exec ($$): SMTP Scan of $ipaddr\n" 
              if ($opt_d);
            if ($opt_w ne 'smtp') {
              $opt_p = 25;
            }
            my $smtp_status = check_port($ipaddr, $opt_p, 'TCP', $opt_t);
            if ($smtp_status) {
              &scan_smtp($ipaddr, $opt_p, %rules);
            }
          }
          ########
          # Do HTTP Scan
          if (
            ( $cli_exec =~ /http/ and !$opt_w )
            or $opt_w =~ /http|all/
          ) {
            print STDERR "$cli_exec ($$): HTTP Scan of $ipaddr,$opt_p, $port_status\n" 
              if ($opt_d);
            &scan_http($ipaddr, $opt_p, $port_status, %rules);
          }
        # end the Multiple Port scanning
        }
        if ( 
          ( split("\n", $output) > 1 and !$HTML )
          or 
          ( split("\n", $output) > 3 and $HTML )
        ) {
          print "</pre>\n<!-- START $ipaddr -->\n" if ($HTML);
          print "$output\n";
          print "</table>\n<!-- END $ipaddr -->\n<pre>" if ($HTML);
          print "<hr noshade>\n" if ($opt_d > 2 and ($HTML));
        }
###############################################################3
        exit 0 unless ($#iplist == 0);
      } else {
        # parent
        push ( @CHILDREN, $thisthread);
        print STDERR "$cli_exec ($$): Parent for pid $thisthread scanning $ipaddr ($#CHILDREN in que)\n" 
          if ($opt_d > 1);
      }
    }
  }
}

# to check it a port is open before continuing the scan
#---------------------------------------
sub check_port {
  # sent IP, port, proto('byname') and timeout
  # returns 1 or 0, 1 for open, 0 for not open
  my($ip, $port, $proto, $timeout) = @_;
  $0 = "http-scanning $ip:$port - PortScan";
  print STDERR "$cli_exec ($$): $ip:$port - PortScan\n"
    if ($opt_d);
  my $p_addr = sockaddr_in($port, inet_aton($ip) );
  my $type;
  my $exitstatus;
  if ($proto =~ /^udp$/i) {
    $type = SOCK_DGRAM;
  } elsif ($proto =~ /^tcp$/i) {
    $type = SOCK_STREAM;
  }
  print STDERR "$cli_exec ($$): creating socket ($ip, $port, $proto)\n" 
    if ($opt_d > 1);
  ##################################################################
  eval { 
    local $SIG{__WARN__};
    local $SIG{'__DIE__'} = "DEFAULT";
    local $SIG{'ALRM'} = sub { die "Timeout Alarm" };
    socket(TO_SCAN,PF_INET,$type,getprotobyname($proto))
      or die "Error: Unable to open socket: $@";
    alarm($opt_t);
    print STDERR "$cli_exec ($$): connecting to port $port on $ip\n" 
      if ($opt_d > 1);
    connect(TO_SCAN, $p_addr)
      or die "Error: Unable to open socket: $@";
    close (TO_SCAN);
    alarm(0);     
  };
  if ($@ =~ /^Error:/) {
    print STDERR "$cli_exec ($$): Unable to connect to $port on $ip\n"
      if ($opt_d > 1);
    $exitstatus = 0;
  } elsif (!$@) {
    print STDERR "$cli_exec ($$): $port on $ip is open\n"
      if ($opt_d > 1);
    $exitstatus = 1;
  }
  ##################################################################
  print STDERR "$cli_exec ($$): Returning ($exitstatus)\n" 
    if ($opt_d > 1);
  return($exitstatus);
}

# usage output for command line, if not enough input is given
#---------------------------------------
sub VERSION_MESSAGE {
  print "\n The Scanner v$VERSION - MadHat (at) Unspecific.com\n";
  print " http://www.unspecific.com/scanner\n";
  print " Use -h for help\n\n";
  exit 0;
}

sub scan_usage {
  print "\n : The Scanner v$VERSION - MadHat (at) Unspecific.com\n";
  print " : http://www.unspecific.com/scanner\n\n";
  print "$cli_exec < -hmFsavUDL > -i <filename> |  -l <host_list> \\
         [ -o <filename>] [ -t <timeout>] [ -M <method> ] \\
         [ -f <rules_file>] [ -u <URI_Query>] \\
         [ -n <num_children>] [ -p <port_num>] \\
         [ -e <expression>] \\   <=== can be regex
         [ -d <debug_level>] [ -T ScanType ]\\
         [ -w <what_scan_to_use> ] [ -O <output_type> ]\\
         [ -S <list_of_vulns> ] [ -I <list_of_vulns> ]\n";
  print "options:\n";
  print "  -h   help (this stuff)\n";
  print "  -L   list all scans (with ID Number) and exit\n";
  print "  -U   Update the $default_congfig config file (fetch a new version)\n";
  print "  -a   force scan ALL checks regardless of version\n";
  print "  -s   use SSL (sets port to 443, unless -p is given) BUGGY\n";
  print "  -m   Show Last-modified date when a match is found\n";
  print "  -N   Lookup NetBIOS name using NBT (requires 137/udp access)\n";
  print "  -F   Show FIX with results\n";
  print "  -T   Only scan with certain scans (Proxy, PUT, DELETE, Apache, Microsoft)\n";
  print "  -v   verbose - will add details\n";
  print "  -d   add debuging info (value 1-9)\n";
  print "  -f   XML rules file that contains vulns to search for\n";
  print "  -S   from -f or the default XML, use the scans listed here in a\n";
  print "        comma seperated list.  List can be shown with -L\n";
  print "        use -Sa for all and it will use the default XML\n";
  print "  -I   same as above, but scans to Ignore from list given by -S or all\n";
  print "  -l   network list in comma delimited form: a.b.c.d/M,e.f.g.h/x.y.z.M,hostname\n";
  print "  -i   input file containing network list, one network per line\n";
  print "  -u   URL to look for on each host\n";
  print "       can not be used with conf file (-f)\n";
  print "  -e   perl regular expression to match\n";
  print "       if no -e is set, verification that the page exists\n";
  print "       can not be used with conf file (-f)\n";
  print "  -n   max number of children to fork\n";
  print "  -p   port number to scan for vulns on\n";
  print "  -t   timeout (in seconds)\n";
  print "  -w   what scan to use, valid options are http, ftp, sql, and all\n";
  print "       This is allowing me to add new scan types on the same frontend\n";
  print "       Web interface defaults to 'all'\n";
  print "       'ftp' look for FTP servers and anonymous access as well as wratability\n";
  print "       'sql' looks for vulnerable MS SQL servers right now, thanks SLAPPER\n";
  print "       'smtp' looks for enying and EXPN and VRFY enabled\n";
  print "  -D   Disguise the 'User-Agent' as a regular browser\n";
  print "  -M   Method to use, i.e. GET, HEAD, OPTIONS, etc...\n";
  print "       PUT and POST not 100% supported (yet)\n";
  print "       can not be used with conf file\n";
  print "  -o   output file\n";
  print "  -O   Output type, valid options are h for HTML and x for XML (XMP buggy)\n";
  print "  -C   Credentials in username:password format\n";
  exit 0;
}

# generate an array of IPs based on multiple input types
#---------------------------------------
sub calculate_ip_range {
  # 1st IP scalar
  #  formats allowed include
  #    a.b.c.d/n       - 10.0.0.1/25
  #    a.b.c.*         - 10.0.0.*
  #    a.b.c.d/w.x.y.z - 10.0.0.0/255.255.224.0 (standard format)
  #    a.b.c.d/w.x.y.z - 10.0.0.0/0.0.16.255    (cisco format)
  #    a.b.c.d-z       - 10.1.2.0-12
  #    a.b.c-x.*       - 10.0.0-3.*
  #    a.b.c-x.d       - 10.0.0-3.0
  #    hostname        - unspecific.com
  # 2nd wether or not to return an error message or nothing 
  #    default is to return nothing on error
  # 3rd is max number IPs to return 
  #    default max is 65536 and can not be raised at this time
  my ($ip, $return_error, $max_ip) = @_;
  my @msg = ();
  my $err = '';
  my $port;
  $max_ip = $max_ip || 65536;
  my $a, $b, $c, $d, $sub_a, $sub_b, $sub_c, $sub_d, $num_ip,
      $nm, $d_s, $d_f, $c_s, $c_f, @msg, $err, $num_sub,
      $start_sub, $count_sub;
  # lets start now...
  # does it look just like a single IP address?
  if ($ip =~ s/^(.+):(\d{1,5})/$1/) { $port = $2 }
  if ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/) {
    print STDERR "$cli_exec ($$): x.x.x.x format $ip\n" if ($opt_d);
    $a = $1; $b = $2; $c = $3; $d = $4;
    if ( $a > 255 or $a < 0 or $b > 255 or $b < 0 or $c > 255 or $c < 0 or 
         $d > 255 or $d < 0) {
      $err = "ERROR: Appears to be a bad IP address ($ip)";
    } else {
      if ($port) { push (@msg, "$ip:$port"); 
        } else { push (@msg, $ip); }
    }
  # does it look like the format x.x.x.x/n
  } elsif ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\/(\d{1,2})$/) {
    print STDERR "$cli_exec ($$): x.x.x.x/n format $ip\n" if ($opt_d);
    $a = $1; $b = $2; $c = $3; $d = $4; $nm = $5;
    if ( $a > 255 or $a < 0 or $b > 255 or $b < 0 or $c > 255 or $c < 0 or 
         $d > 255 or $d < 0 or $nm > 32 or $nm < 0) {
      $err = "ERROR: Something appears to be wrong ($ip)";
    } else {
      $num_ip = 2**(32-$nm);
      if ($num_ip > $max_ip) {
        $err = "ERROR: Too many IPs returned ($num_ip)";
      } elsif ($num_ip <= 256) {
        $num_sub = 256/$num_ip;
        SUBNET: for $count_sub (0..($num_sub - 1)) {
          $start_sub = $count_sub * $num_ip;
          if ($d > $start_sub and $d < ($start_sub + $num_ip)) {
            $d = $start_sub;
            last SUBNET;
          }
        }
        for $d ($d..($d + $num_ip - 1)) {
          $ip = "$a.$b.$c.$d";
          if ($port) { push (@msg, "$ip:$port"); 
            } else { push (@msg, $ip); }
        }
      } elsif ($num_ip <= 65536) {
        $num_sub = 256/($num_ip/256); $num_ip = $num_ip/256;
        SUBNET: for $count_sub (0..($num_sub - 1)) {
          $start_sub = $count_sub * $num_ip;
          if ($c > $start_sub and $c < ($start_sub + $num_ip)) {
            $c = $start_sub;
            last SUBNET;
          }
        }
        for $c ($c..($c + $num_ip - 1)) {
          for $d (0..255) {
            $ip = "$a.$b.$c.$d";
            if ($port) { push (@msg, "$ip:$port"); 
              } else { push (@msg, $ip); }
          }
        }
      }
    }
  # does it look like the format x.x.x.x-y
  } elsif ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\-(\d{1,3})$/) {
    print STDERR "$cli_exec ($$): x.x.x.x-y format $ip\n" if ($opt_d);
    $a = $1; $b = $2; $c = $3; $d_s = $4; $d_f = $5;
    if ( $d_f > 255 or $d_s > 255 or $d_s < 0 or $d_f < 0 or $a < 0 or 
         $a > 255 or $b < 0 or $b > 255 or $c < 0 or $c > 255 ) {
      $err = "ERROR: Something appears to be wrong ($ip).";
    } elsif ($d_f < $d_s) {
      LOOP: for $d ($d_f .. $d_s) {
        if ($#msg > $max_ip) { 
          $err = "ERROR: Too many IPs returned ($#msg+)"; 
          last LOOP;
        }
        $ip = "$a.$b.$c.$d";
        if ($port) { push (@msg, "$ip:$port"); 
          } else { push (@msg, $ip); }
      }
      # $err = "Sorry, we don't count backwards.";
    } elsif ($d_f == $d_s) {
      $ip = "$a.$b.$c.$d_s";
      if ($port) { push (@msg, "$ip:$port"); 
        } else { push (@msg, $ip); }
    } else {
      LOOP: for $d ($d_s .. $d_f) {
        if ($#msg > $max_ip) { 
          $err = "ERROR: Too many IPs returned ($#msg+)"; 
          last LOOP;
        }
        $ip = "$a.$b.$c.$d";
        if ($port) { push (@msg, "$ip:$port"); 
          } else { push (@msg, $ip); }
      }
    }
      # does it look like the format x.x.x-y.*
  } elsif ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\-(\d{1,3})\.(.*)$/) {
    print STDERR "$cli_exec ($$): x.x.x-y.* format $ip\n" if ($opt_d);
    $a = $1; $b = $2; $c_s = $3; $c_f = $4; $d = $5;
    if ( $c_f > 255 or $c_s > 255 or $c_s < 0 or $c_f < 0 or 
         $a < 0 or $a > 255 or $b < 0 or $b > 255 or 
         ( ($d < 0 or $d > 255) and $d ne "*") ) {
      $err = "ERROR: Something appears to be wrong ($ip)";
    } elsif ($c_f < $c_s) {
      LOOP: for $c ($c_f .. $c_s) {
        for $d (0..255) {
          if ($#msg > $max_ip) { 
            $err = "ERROR: Too many IPs returned ($#msg+)"; 
            last LOOP;
          }
          $ip = "$a.$b.$c.$d";
          if ($port) { push (@msg, "$ip:$port"); 
            } else { push (@msg, $ip); }
        }
      }
    } elsif ($c_f == $c_s) {
      $ip = "$a.$b.$c_s.$d";
      if ($port) { push (@msg, "$ip:$port"); 
        } else { push (@msg, $ip); }
    } else {
      LOOP: for $c ($c_s .. $c_f) {
        for $d (0..255) {
          if ($#msg > $max_ip) { 
            $err = "ERROR: Too many IPs returned ($#msg+)"; 
            last LOOP;
          }
          $ip = "$a.$b.$c.$d";
          if ($port) { push (@msg, "$ip:$port"); 
            } else { push (@msg, $ip); }
        }
      }
    }
  # does it look like the format x.x.x.*
  } elsif ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.\*$/) {
    print STDERR "$cli_exec ($$): x.x.x.* format $ip\n" if ($opt_d);
    $a = $1; $b = $2; $c = $3;
    if ( $a < 0 or $a > 255 or $b < 0 or $b > 255 or $c < 0 or $c > 255 ) {
      $err = "ERROR: Something appears to be wrong ($ip)";
    } else {
      LOOP: for $d (0 .. 255) {
        if ($#msg > $max_ip) { 
          $err = "ERROR: Too many IPs returned ($#msg+)"; 
          last LOOP;
        }
        $ip = "$a.$b.$c.$d";
        if ($port) { push (@msg, "$ip:$port"); 
          } else { push (@msg, $ip); }
      }
    }
  # does it look like the format x.x.x.x/y.y.y.y
  } elsif ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/) {
    print STDERR "$cli_exec ($$): x.x.x.x/y.y.y.y format $ip\n" if ($opt_d);
    $a = $1; $b = $2; $c = $3; $d = $4; 
    $sub_a = $5; $sub_b = $6; $sub_c = $7; $sub_d = $8;
    # if it appears to be in "cisco" format, convert it
    if ($sub_a == 0 and $sub_b == 0) {
      $sub_a = 255 - $sub_a; $sub_b = 255 - $sub_b;
      $sub_c = 255 - $sub_c; $sub_d = 255 - $sub_d;
    }
    # check to see if the input looks valid
    if ( $a > 255 or $a < 0 or $b > 255 or $b < 0 or $c > 255 or $c < 0 or 
         $d > 255 or $d < 0 or $sub_a > 255 or $sub_a < 0 or
         $sub_b > 255 or $sub_b < 0 or $sub_c > 255 or $sub_c < 0 or 
         $sub_d > 255 or $sub_d < 0 or ($sub_d < 255 and $sub_c != 255 and 
         $sub_b != 255 and $sub_a != 255) or ($sub_d != 0 and 
         $sub_c == 0 and $sub_b < 255 and $sub_a == 255) or 
         ($sub_d != 0 and $sub_c < 255 and $sub_b == 255 and 
         $sub_a == 255)) {
      $err = "ERROR: Something appears to be wrong ($ip)";
    # if it looked valid, but it appears to be an IP, return that IP
    } elsif ($sub_d == 255) {
      $ip = "$a.$b.$c.$d";
      if ($port) { push (@msg, "$ip:$port"); 
        } else { push (@msg, $ip); }
    # if the range appears to be part of a class C
    } elsif ($sub_d < 255 and $sub_d >= 0 and $sub_c == 255) {
      $num_ip = 256 - $sub_d; $num_sub = 256/$num_ip;
      if ($num_ip > $max_ip) {
        $err = "ERROR: Too many IPs returned ($num_ip)";
      } else {
        SUBNET: for $count_sub (0..($num_sub - 1)) {
          $start_sub = $count_sub * $num_ip;
          if ($d > $start_sub and $d < ($start_sub + $num_ip)) {
            $d = $start_sub;
            last SUBNET;
          }
        }
        LOOP: for $d ($d..($d + $num_ip - 1)) {
          if ($#msg > $max_ip) { 
            $err = "ERROR: Too many IPs returned ($#msg+)"; 
            last LOOP;
          }
          $ip = "$a.$b.$c.$d";
          if ($port) { push (@msg, "$ip:$port"); 
            } else { push (@msg, $ip); }
        }
      }
      # if the range appears to be part of a class B
    } elsif ($sub_c < 255 and $sub_c >= 0) {
      $num_ip = 256 - $sub_c; $num_sub = 256/$num_ip;
      if ($num_ip > $max_ip) {
        $err = "ERROR: Too many IPs returned ($num_ip)";
      } else {
        SUBNET: for $count_sub (0..($num_sub - 1)) {
          $start_sub = $count_sub * $num_ip;
          if ($c > $start_sub and $c < ($start_sub + $num_ip)) {
            $c = $start_sub;
            last SUBNET;
          }
        }
        LOOP: for $c ($c..($c + $num_ip - 1)) {
          for $d (0..255) {
            if ($#msg > $max_ip) { 
              $err = "ERROR: Too many IPs returned ($#msg+)"; 
              last LOOP;
            }
            $ip = "$a.$b.$c.$d";
            if ($port) { push (@msg, "$ip:$port"); 
              } else { push (@msg, $ip); }
          }
        }
      }
    }
  } elsif ($ip =~ /[\w\.]+/)  {
    print STDERR "$cli_exec ($$): DNS name $ip\n" if ($opt_d);
    if ($ip =~ /^(\w+)\[(\d{1,})\-(\d{1,})\]([\w\.]+)$/) {
      print "$1, $2, $3, $4\n" if ($opt_d);
      if ($3 <= $2) {
        return 0;
      } else {
        for $current ($2..$3) {
          my $ip = "$1$current$4";
          my ($name,$aliases,$type,$len,@thisaddr) = gethostbyname($ip);
          my ($a,$b,$c,$d) = unpack('C4',$thisaddr[0]);
          if ($a and $b and $c and $d) {
            if (calculate_ip_range("$a.$b.$c.$d")) {
              print STDERR "$cli_exec ($$): $ip points to $a.$b.$c.$d\n"
                if ($opt_d);
              $ip = "$a.$b.$c.$d";
              if ($port) { push (@msg, "$ip:$port"); 
                } else { push (@msg, $ip); }
            }
          } else {
            $err = "ERROR: Something appears to be wrong ($ip)";
          }
        }
      }
    } else {
      my ($name,$aliases,$type,$len,@thisaddr) = gethostbyname($ip);
      my ($a,$b,$c,$d) = unpack('C4',$thisaddr[0]);
      if ($a and $b and $c and $d) {
        if (calculate_ip_range("$a.$b.$c.$d")) {
          print STDERR "$cli_exec ($$): $ip points to $a.$b.$c.$d\n" 
            if ($opt_d);
          $ip = "$a.$b.$c.$d";
          if ($port) { push (@msg, "$ip:$port"); 
            } else { push (@msg, $ip); }
        }
      } else {
        $err = "ERROR: Something appears to be wrong ($ip)";
      }
    }
  # if it doesn't match one of those...
  } else {
    print STDERR "$cli_exec ($$): Not Recognised $ip\n" if ($opt_d);
    $err = "ERROR: Something appears to be wrong ($ip)";
  }
  if ($err and $return_error) { 
    return "$err\n"; 
  } elsif (@msg) {
    return @msg;
  } else {
    return;
  }
}

# do an NBT Scan to get the hostname via UDP port 137
#---------------------------------------
sub nbtscan {
  $/ = CRLF;
  ($ip) = @_;
  $0 = "http-scanning $ip:$opt_p - NBTScan";
  print STDERR "$cli_exec ($$): NBTScan $ip\n" if ($opt_d > 1);
  my $senddata = "\x01\x4d\x00\x10\x00\x01\x00\x00\x00\x00\x00" .
    "\x00\x20\x43\x4b\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41" .
    "\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41" .
    "\x41\x41\x41\x41\x00\x00\x21\x00\x01";
  my $nbtdata;
 
  eval {
    local $SIG{__WARN__};
    local $SIG{'__DIE__'} = "DEFAULT";
    local $SIG{'ALRM'} = sub { die "Timeout Alarm" };
    print STDERR "$cli_exec ($$): Creating Socket $ip\n" if ($opt_d > 2);
    alarm($opt_t);
    socket(SOCK, AF_INET, SOCK_DGRAM, getprotobyname('udp') ) 
      or die "Error: $!";
    my $dest_addr = sockaddr_in( '137', inet_aton($ip) );
    print STDERR "$cli_exec ($$): Sending Request $ip\n" if ($opt_d > 2);
    send(SOCK,$senddata,0,$dest_addr)
      or die "Error: $!";
    print STDERR "$cli_exec ($$): Receiving Data $ip\n" if ($opt_d > 2);
    recv(SOCK,$nbtdata,283,0)
      or die "Error: $!";
    close (SOCK);
    alarm(0);
  };
  if ($nbtdata and $@ !~ /^Error/) {
    print STDERR "$cli_exec ($$): NBTScan Data returned\n"
      if ($opt_d > 2);
    my $startpoint = 57;
    $machinename = substr $nbtdata, $startpoint, 16; 
    while ($machinename =~ /~/) {
      $startpoint = $startpoint + 18;
      $machinename = substr $nbtdata, $startpoint, 16; 
    }
    $machinename =~ s/([\w-]+)\W*/$1/g;
    my $MAC0 = substr $nbtdata, -64, 1;
    my $MAC1 = substr $nbtdata, -63, 1;
    my $MAC2 = substr $nbtdata, -62, 1;
    my $MAC3 = substr $nbtdata, -61, 1;
    my $MAC4 = substr $nbtdata, -60, 1;
    my $MAC5 = substr $nbtdata, -59, 1;
    $mac = unpack('H*', $MAC0) . "-" . 
           unpack('H*', $MAC1) . "-" . 
           unpack('H*', $MAC2) . "-" . 
           unpack('H*', $MAC3) . "-" . 
           unpack('H*', $MAC4) . "-" . 
           unpack('H*', $MAC5);
  } 

  print STDERR "$cli_exec ($$): NBTData $machinename\n" 
    if ($opt_d and $machinename);
  print STDERR "$cli_exec ($$): MAC $mac\n" 
    if ($opt_d and $mac);
  return ($machinename);
}

# raw request using sslcat or raw sockets for things 
# that can't easily be done with LWP
#---------------------------------------
sub raw_request {
  my ($ip, $port, $request) = @_;
  my $rawdata = @rawdata = ();
  my $senddata = "$request\r\n\r\n";
  my $EOT = "\015\012";
  print STDERR "$cli_exec ($$): RAW request of '$request' being sent\n"
    if ($opt_d > 1);
  if ($opt_s) {
    print STDERR "$cli_exec ($$): RAW request using Net::SSLeay\n"
      if ($opt_d > 1);
    eval { 
      local $SIG{__WARN__};
      local $SIG{'__DIE__'} = "DEFAULT";
      local $SIG{'ALRM'} = sub { die "Timeout Alarm" };
      alarm($opt_t);
     $rawdata = sslcat($ip, $port, $senddata); 
      alarm(0);
    };
    print STDERR "$cli_exec ($$): $rawdata\n"
      if ($opt_d > 2);
  } else {
    eval { 
      local $SIG{__WARN__};
      local $SIG{'__DIE__'} = "DEFAULT";
      local $SIG{'PIPE'}='IGNORE';
      local $SIG{'ALRM'} = sub { die (join '', @rawdata) };
      alarm($opt_t);
      print STDERR "$cli_exec ($$): Creating RAW Socket\n"
        if ($opt_d > 1);
      socket(SOCK, AF_INET, SOCK_STREAM, getprotobyname('tcp') ) ;
      my $dest_addr = sockaddr_in( $port, inet_aton($ip) );
      print STDERR "$cli_exec ($$): Connection to RAW Socket\n"
        if ($opt_d > 1);
      connect(SOCK, $dest_addr) or die ($!);
      print STDERR "$cli_exec ($$): Sending request to RAW Socket\n"
        if ($opt_d > 1);
      send(SOCK,$senddata,0,$dest_addr) or die ($!);
      print STDERR "$cli_exec ($$): Reading response from RAW Socket\n"
        if ($opt_d > 1);
      READSOCK: while (!eof(SOCK)) {
        read(SOCK,$rawdata,1);
        push @rawdata, $rawdata;
        if ($senddata =~ /RTSP/ 
              and $rawdata eq "\n" 
              and $rawdata[-2] eq "\r"
              and $rawdata[-3] eq "\n"
              and $rawdata[-4] eq "\r"
           ) {
          die (join '', @rawdata);
        }
      }
      print STDERR "$cli_exec ($$): Closing RAW Socket\n"
        if ($opt_d > 1);
      close (SOCK);
      alarm(0);
      $rawdata = join('', @rawdata);
    };
  }
  if ($@) { 
    if ( $@ =~ /Server:/ or $@ =~ /SMTP/ ) {
      $rawdata = $@; 
    } else {
      $rawdata = '.'; 
    }
    print STDERR "$cli_exec ($$): RAW request error ($@)\n"
      if ($opt_d > 1);
  }
  $raw_length = length($rawdata);
  print STDERR "$cli_exec ($$): RAW RETURN ($raw_length bytes)\n"
    if ($opt_d > 1);
  print STDERR "$cli_exec ($$): $rawdata\n\n"
    if ($opt_d > 2);
  return ($rawdata);
}

# adding a host data for output and formatting of that output
#---------------------------------------
sub add_host {
  my ($name, $prefix, $ipaddr, $get, $port, $netbios, $current_version, 
    $method_send, $LastModified, $Allow, $code, $fix, $content, $id,
    $info, $version, $level, $CVE, $description, $proto, $BID, $MS) = @_;
  add_debug("$cli_exec ($$): Running sub add_host($name)\n") if ($opt_d);
  my $CVE_URL = ''; my $BID_URL = ''; my $MS_URL = '';
  my $CA_URL = ''; my $CAN_URL = '';
  my $lvl = substr($level,0,1);
  if ($opt_F) { 
    if ($HTML) { $delimiter = "<br>\n  "; } else { $delimiter = "\n  "; }
  }
  if (!$proto) { $proto = 'tcp' }
  my $div_id = $id;
  if ($id =~ /^(\d{1,4})[\D\-]+$/) { $id = $1; }
  $name = "$id) $name" if ($id);
  $vuln{$ipaddr}++;
  if ($#iplist == 0) {
    $total_vulns++;
    add_debug("$cli_exec ($$): Vuln found, incrementing total_vulns ($total_vulns, $vuln{$ipaddr})\n")
      if ($opt_d > 1);
  } else {
    add_debug("$cli_exec ($$): Vuln found, sending USR1 to parrent($parent)\@1022\n") 
      if ($opt_d > 1);
    kill USR1, $parent;
  }
  if (!$current_version) { 
    # BUG.
    # on large scans I am having a problem with false positives where
    # it appears no current version is found, but this should never
    # be the case.  So for a temp work around, I am implimenting this
    # one line fix of dropping anything without a current_version
    # I think it could be a memort management issue
    return if ($opt_S and $name !~ /^Port \d+ Not Open$/); 
    $current_version = 'UNKNOWN'; 
    
  }
  if ($HTML) {
    $current_version =~ s/\</&lt;/g;
    $name =~ s/\</&lt;/g;
    $content =~ s/\</&lt;/g;
    if ($level eq 'HIGH') {
      $output .= "<tr class='levelHigh'><td valign=top>";
    } elsif ($level eq 'Medium') {
      $output .= "<tr class='levelMedium'><td valign=top>";
    } elsif ($level eq 'Informational') {
      $output .= "<tr class='levelInfo'><td valign=top>";
    } else {
      $output .= "<tr class='levelLow'><td valign=top>";
    }
    if ($id) {
      $level = $level?$level:'Unspecified';
      $version = $version?$version:'Multiple Versions Effected';
      my @CVE =  split(',',$CVE);
      for my $CVE (@CVE) {
        $CVE =~ s/\s//g;
        if ($CVE =~ /^CA\-/) { 
          $CVE_URL .= "<b>CERT Advisory</b>: <a href='http://www.cert.org/advisories/$CVE.html' target='_blank'>$CVE</a><br>\n";
        } elsif ($CVE =~ /^CA/) {
          $CVE_URL .= "<b>CVE Candidate</b>: <a href='http://icat.nist.gov/icat.cfm?cvename=$CVE' target='_blank'>$CVE</a><br>\n";
        } elsif ($CVE) {
          $CVE_URL .= "<b>CVE Information</b>: <a href='http://icat.nist.gov/icat.cfm?cvename=$CVE' target='_blank'>$CVE</a><br>\n";
        }
      }
      my @BID =  split(',',$BID);
      for my $BID (@BID) {
        $BID =~ s/\s//g;
        if ($BID) { 
          $BID_URL .= "<b>BubtraqID</b>: <a href='http://online.securityfocus.com/bid/$BID' target='_blank'>$BID</a><br>\n";
        }
      }
      my @MS =  split(',',$MS);
      for my $MS (@MS) {
        $MS =~ s/\s//g;
        if ($MS) { 
          $MS_URL .= "<b>Microsoft</b>: <a href='http://www.microsoft.com/technet/security/bulletin/$MS.mspx' target='_blank'>$MS</a><br>\n";
        }
      }
      if (length $info > 60) {
        $info_name = substr($info, 0, 60) . '...';
      } else {
        $info_name = $info;
      }
      if ($info =~ /^https?:\/\//) {
        $echo_info = "<a href='$info' target='_blank'><b>$info_name</b></a>";
      } else {
        $echo_info = "<b>$info_name</b>";
      }
      $description = swrite(<<'END', "$description");
    ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ~~
END
      $output .= <<_EOF_;
<div class="helpMenu" id="id$div_id">
<table width=400><tr><td width=395><font size=+1><b>$name</b></font><br>
$description<br><br>
Severity: <b>$level</b><br>
Version Effected: <b>$version</b><br>
Fix: <b>$fix</b><br>
$echo_info
$CVE_URL $BID_URL $MS_URL
</td><td align=right valign=top><a href="javascript:hideHelp();" class="helpClose">X</a></td></tr></table>
</div>
_EOF_
    }
    $get =~ s/</%3C/g;
    $get =~ s/>/%3E/g;
    $output .= "<nobr><a href=\"$prefix://$ipaddr:$port/$get\" target='_blank'>"
      if ($prefix and $method_send ne 'RAW');
  }
  $output .=  "$lvl $ipaddr";
  $output .= "</a>" if ($HTML);
  $output .= " $proto $port";
  if ($HTML) {
    $output .= "</nobr>&nbsp;&nbsp;</td>";
  } else {
    $output .= $delimiter;
  }
  if ($opt_N) {
    if ($opt_F and $netbios) {
      $output .= "NetBIOS Name:$delimiter  ";
    }
    $output .= "<td valign=top>" if ($HTML);
    $output .= $netbios;
    if ($HTML) {
      $output .= "&nbsp;&nbsp;</td>";
    } else {
      $output .= $delimiter unless ($opt_F and !$netbios);
    }
  }
  if (defined($opt_v)) {
    $output .= "<td valign=top>" if ($HTML);
    if ($opt_F) {
      $output .= "Server Version:$delimiter  ";
    }
    $output .= $current_version;
    $output .= " w/ SSL" 
      if ($opt_s);
    if ($HTML) {
      $output .= "&nbsp;&nbsp;</td>";
    } else {
      $output .= $delimiter;
    }
  }
  $output .= "<td valign=top>" if ($HTML);
  $output .= "<a href=\"javascript://\" class=\"helpLink\"
onMouseOver=\"javascript:hideHelp();prepareHelp('id$div_id');\"
onMouseOut=\"javascript:killHelp();\">" if ( ($HTML) and $div_id);
  if ($opt_F) {
    $output .= "Vulnerability:$delimiter  ";
  }
  $output .= $name;
  $output .= "</a>" if ($HTML);
  if ($HTML) {
    $output .= "&nbsp;&nbsp;</td>";
  } else {
    $output .= $delimiter;
  }
  if ($opt_F) {
    $output .= "Level:$delimiter  $level$delimiter" if ($level);
    $output .= "Example:$delimiter  $prefix://$ipaddr:$port/$get$delimiter"
      if ($method_send ne 'RAW' and $prefix);
    if ($CVE) {
      my @CVE =  split(',',$CVE);
      for my $CVE (@CVE) {
        $CVE =~ s/\s//g;
        if ($CVE =~ /^CA\-/) { 
          if (!$CA_URL) {
            $CA_URL = "CERT Advisory Information:$delimiter";
          }
          $CA_URL .= "  http://www.cert.org/advisories/$CVE.html$delimiter";
        } elsif ($CVE =~ /^CA/) {
          if (!$CAN_URL) {
            $CAN_URL = "CVE Candidate Information:$delimiter";
          }
          $CAN_URL .= "  http://icat.nist.gov/icat.cfm?cvename=$CVE$delimiter";
        } elsif ($CVE) {
          if (!$CVE_URL) {
            $CVE_URL = "CVE Entry Information:$delimiter";
          }
          $CVE_URL .= "  http://icat.nist.gov/icat.cfm?cvename=$CVE$delimiter";
        }
      }
      $CVE_URL = $CVE_URL . $CAN_URL . $CA_URL;
    }
    if ($BID) {
      $BID_URL = "BugtraqID:$delimiter";
      my @BID =  split(',',$BID);
      for my $BID (@BID) {
        $BID =~ s/\s//g;
        if ($BID) { 
          $BID_URL .= "  http://online.securityfocus.com/bid/$BID$delimiter";
        }
      }
    }
    if ($MS) {
      $MS_URL = "Microsoft Security Bulletin:$delimiter";
      my @MS =  split(',',$MS);
      for my $MS (@MS) {
        $MS =~ s/\s//g;
        if ($MS) { 
          $MS_URL .= "http://www.microsoft.com/technet/security/bulletin/$MS.mspx$delimiter";
        }
      }
    }
    $output .= "<td valign=top>" if ($HTML);
    # $output .= "\n";
    if ($description) {
      $output .= "DESCRIPTION:\n";
      $output .= swrite(<<'END', "$description");
    ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ~~
END
      # $output .= $delimiter;
      $output .= "  ";
    }
    if ($fix) {
      $output .= "FIX:\n";
      $output .= swrite(<<'END', "$fix");
    ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ~~
END
      # $output .= $delimiter;
      $output .= "  ";
    }
    if ($CVE_URL) { $output .= $CVE_URL; }
    if ($BID_URL) { $output .= $BID_URL; }
    if ($MS_URL) { $output .= $MS_URL; }
    if ($info) {
      $output .= "More Information:$delimiter  $info$delimiter";
    }
    if ($HTML) {
      $output .= "&nbsp;&nbsp;</td>";
    } else {
      # $output .= "\t$delimiter";
    }
  }
  if ($opt_m and $LastModified) {
    $output .= "<td valign=top>" if ($HTML);
    $output .= $LastModified;
    if ($HTML) {
      $output .= "&nbsp;&nbsp;</td>";
    } else {
      $output .= $delimiter;
    }
  }
  if ($opt_d > 1 and $code) {
    $output .= "<td valign=top>\n" if ($HTML);
    $output .= "\n$cli_exec ($$): RC $code for '$name' " ;
    $output .= "&nbsp;&nbsp;</td>\n" if ($HTML);
  }
  if ( ($method_send ne "GET" and $method_send ne 'RAW')
    and $opt_d and $Allow) {
    $output .= "<td valign=top>" if ($HTML);
    $output .= $Allow;
    if ($HTML) {
      $output .= "&nbsp;&nbsp;</td>";
    } else {
      $output .= $delimiter;
    }
  }
  if ( $opt_d > 2 ) {
    $output .= "<tr><td colspan=6 valign=top><pre id=1108>" if ($HTML);
    $output .= "Data Returned:\n" . '-' x 70 . "\n$content\n" . '-' x 70;
    $output .= "</pre></td></tr>" if ($HTML);
  }
  $output .= "</tr>\n&nbsp;" if ($HTML);
  $output .= "\n";
}

# compare version detected with the vulnerable version listed
# in the conf file
#---------------------------------------
sub check_version {
  my ($current_version, $version, $vid) = @_;
  if (!$current_version) {
    add_debug("$cli_exec ($$): Unable to test version, none found\n")
      if ($opt_d > 1);
    return (0);
  }
  if ($current_version =~ /\*$/) {
    add_debug("$cli_exec ($$): Version is a guess and not accurate to test\n")
      if ($opt_d > 1);
    return (0);
  }
  add_debug("$cli_exec ($$): Vuln Version ID: $version $vid\n")
    if ($opt_d > 1);
  $current_version =~ /$version[\/\s](\d+\.\S+) /;
  $cvid = $1;
  add_debug("$cli_exec ($$): Current Version ID: $cvid\n")
    if ($opt_d > 1);
# we split each version on the . and compair each number
  @cvid = split('\.', $cvid);
  @vid = split('\.', $vid);
  for my $loc (0..$#cvid) {
    if ($loc == 0 and $vid[$loc] > $cvid[$loc]) {
      print STDERR "$cli_exec ($$): Primary version different- $vid[$loc] > $cvid[$loc]\n"
        if ($opt_d > 1);
      return(0);
    
    }
    if ($vid[$loc] > $cvid[$loc] and $loc != 0) {
      print STDERR "$cli_exec ($$): Version Results - $vid[$loc] > $cvid[$loc]\n"
        if ($opt_d > 1);
      return(1);
    } elsif ($cvid[$loc] > $vid[$loc]) {
      return(0);
    }
  }
  print STDERR "$cli_exec ($$): Version Results - NOT old, returning 0\n"
    if ($opt_d > 1);
  return (0);
}

# backup old XML config and download new config
#---------------------------------------
sub update_config {
  my $date = time;
# copy the old config
  if (! rename $default_config, "$default_config.$date") {
    print "Looks like we can't create a backup of the existing config file.\n";
    print "Do you want to continue? (y/n) : ";
    my $answer = <STDIN>;
    if ($answer !~ /y/i) {
      print "Will not continue.\n";
      exit 0;
    }
  }
# grab the new config and write it to the proper file name
  $ua = RequestAgent->new;
  $ua->agent($agent);
  $res = $ua->mirror($update_url, $default_config);
  if ($res->is_error) {
    print "Unable to create $default_config, or overwrite existing file\n";
  } else {
    print "Update appears to be successful.\n\n"
      . "  Run '$cli_exec -h' for help on running http-scan or visit\n"
      . "  http://www.unspecific.com/scanner/\n\n"
      . " Thanks\n- MadHat (at) Unspecific.com\n\n";
  }
  exit 0;
}

# when capturing SIG_USR2 increment total hosts found listening
# to the specified port
#---------------------------------------

sub live_host {
  $total_count++;
}

# when capturing SIG_USR1 increment total vulns found
#---------------------------------------
sub vulns_found {
  $total_vulns++;
}

sub load_javascript {
  my $jscript = <<_EOF_;
var currentHelp = 'temp'
var helpTimer = 0

var isIE = document.all?true:false;
var mouseX;
var mouseY;
document.onmousemove = getMouse;
function getMouse(e) {
  if (!isIE) {
    mouseX = e.pageX;
    if (mouseX + 400 > window.innerWidth) mouseX = window.innerWidth - 450
    mouseY = e.pageY;
    if (mouseY + 150 > window.innerHeight) mouseY -= 200
  }else{
    mouseX = event.clientX + document.body.scrollTop + 10;
    if (mouseX + 400 > document.body.offsetWidth) mouseX = document.body.offsetWidth - 450
    mouseY = event.clientY + document.body.scrollTop + 10;
    if (mouseY + 150 > document.body.offsetHeight) mouseY -= 200
  }
  // window.status=mouseX + "X" + mouseY;
}
function change_port() {
  if ( window.document.scanner.s.checked == true ) {
    window.document.scanner.p.value = 443;
  } else {
    window.document.scanner.p.value = 80;
  }
}
function showHelp(helpName) {
  currentHelp = helpName;
  getMouse;
  if (document.all) {
    var ieHelp = document.all[currentHelp];
    ieHelp.style.left = mouseX + "px";
    ieHelp.style.top = mouseY;
    ieHelp.style.visibility = 'visible';
    return false;
  } else if (document.layers) {
    var nsHelp = document.layers[currentHelp];
    nsHelp.left = mouseX + "px";
    nsHelp.top = mouseY;
    nsHelp.visibility = 'show';
    return false;
  } else if (document.getElementById) {
    var mozHelp = document.getElementById(currentHelp);
    mozHelp.style.left = mouseX + "px";
    mozHelp.style.top = mouseY;
    mozHelp.style.visibility = 'visible';
    return false;
  }
  return true;
}
function hideScanning(){
  if (document.all) {
    var ieScan = document.all['init1'];
    ieScan.style.visibility = 'hidden';
    var ieScan = document.all['init2'];
    ieScan.style.visibility = 'hidden';
    var ieScan = document.all['hint'];
    ieScan.style.visibility = 'visible';
  } else if (document.layers){
    var nsScan = document.layers['init1'];
    nsScan.visibility = 'hide';
    var nsScan = document.layers['init2'];
    nsScan.visibility = 'hide';
    var nsScan = document.layers['hint'];
    nsScan.visibility = 'show';
  } else if (document.getElementById) {
    document.getElementById('init1').style.visibility = 'hidden';
    document.getElementById('init2').style.visibility = 'hidden';
    document.getElementById('hint').style.visibility = 'visible';
  }
}
function hideHelp(){
  if (document.all) {
    var ieHelp = document.all[currentHelp];
    ieHelp.style.visibility = 'hidden';
  } else if (document.layers){
    var nsHelp = document.layers[currentHelp];
    nsHelp.visibility = 'hide';
  } else if (document.getElementById) {
    document.getElementById(currentHelp).style.visibility = 'hidden';
  }
}
function killHelp(){
  window.clearTimeout(helpTimer);
  //hideHelp();
}

function prepareHelp(helpName){
  killHelp();
  currentHelp = helpName;
  helpTimer = window.setTimeout('hideHelp();showHelp("'+helpName+'")', 1000);
  window.status='Holding the cursor over a vulnerability will display help information';
  return false;
}

function contractall() {
  if (document.getElementById){
    var inc=0;
    while (document.getElementById("vuln"+inc)) {
      document.getElementById("vuln"+inc).style.display="none";
      inc++;
    }
  }
}

function switchdetails() {
  if (document.getElementById) {
    var selectedItem=document.vulnselectform.vulnselect[document.vulnselectform.vulnselect.selectedIndex].value;
    contractall();
    document.getElementById(selectedItem).style.display="block";
  }
}


_EOF_
  return($jscript);
}

sub load_css {
  my $css = <<_EOF_;
.helpMenu {
  left: 400px;
  position:absolute;
  visibility:hidden;
  border: 2px outset #AAAAAA;
  font-size: 10pt;
  font-family: Arial, Helvetica, sans-serif;
  background-color:#CCCCCC;
  layer-background-color:#CCCCCC;
  cursor:default;
  padding-left:5px;
  padding-right:5px;
  padding-top:2px;
  padding-bottom:2px;
  width:400px;
}
.vulnDetails {
  border: 1px outset #444444;
  font-size: 10pt;
  font-family: Arial, Helvetica, sans-serif;
  background-color:#CCCCCC;
  layer-background-color:#CCCCCC;
  cursor:default;
  padding-left:5px;
  padding-right:5px;
  padding-top:2px;
  padding-bottom:2px;
  width:500px;
}
.hint {
  visibility:hidden;
  position:relitive;
  border: 2px outset #AAAAAA;
  font-size: 8pt;
  font-family: Arial, Helvetica, sans-serif;
  background-color:#CCCCCC;
  layer-background-color:#CCCCCC;
  cursor:default;
  padding-left:5px;
  padding-right:5px;
  padding-top:0px;
  padding-bottom:2px;
}
.levelHigh {
  background-color:#FF6666;
}
.levelMedium {
  background-color:#8899FF;
}
.levelInfo {
  background-color:#88FF99;
}
.levelLow {
  background-color:#EEEEEE;
}
.helpLink {
  cursor:help;
  color:black;
  text-decoration:none
}
.helpClose {
  color:black;
  text-decoration:none
}
.vulnInfo {
  font-family: Courier, Courier New, Terminal;
  font-size: 12pt;
  color:black;
}
_EOF_
  return($css);
}

sub load_vulns {
  ($finger) = @_;
  if ($finger) {
    print STDERR "$cli_exec ($$): Loading Fingerprints\n" if ($opt_d);
  } else {
    print STDERR "$cli_exec ($$): Loading Rules\n" if ($opt_d);
  }
  $conf = new XML::Parser;
  $conf->setHandlers (
        Start   => \&startElement,
        End     => \&endElement,
        Char    => \&characterData,
  );
  if (!@scans or ($scans[0] eq 'a') ) { 
    print STDERR "$cli_exec ($$): Adding ALL RULES to list\n" if ($opt_d);
    @scans = ();
    $add_all++;
  }
  print STDERR "$cli_exec ($$): Parsing XML File\n" if ($opt_d);
  $conf->parsefile($opt_f);
  return;
}

# Start Custom XML Parsing Stuff....
sub startElement {
  my($parseinst, $element, %attrs) = @_;
  print STDERR "$cli_exec ($$): Start new XML Element ($id->$element)\n" 
    if ($opt_d > 7);
  if ($element eq 'scan') {
    if ($finger) {
      return;
    }
    $id = $attrs{'id'};
    $vulns{$id}{'name'} = $attrs{'name'};
    if ($add_all and $id and ! grep /^$id$/, @Iscans ) { 
      chomp $id; 
      print STDERR "$cli_exec ($$): Adding $id to \@scans\n" 
        if ($opt_d > 5);
      push @scans, $id 
    }

  } elsif ($element eq 'fingerprint') {
    $id = '';
    $fingerprint = $attrs{'name'};
  } else {
    if ($element eq 'method') {
      $cur_ele = 'method_send';
    } elsif ($element eq 'send') {
      $cur_ele = 'get';
    } elsif ($element eq 'versionID') {
      $cur_ele = 'vid';
    } else {
      $cur_ele = $element;
    }
  }
}

sub endElement {
  my ($parseinst, $element, %attrs) = @_;
  print STDERR "$cli_exec ($$): End XML Element ($id->$element)\n" 
    if ($opt_d > 7);
  if ($element eq 'scan') {
    print STDERR "$cli_exec ($$): Tiding UP ($id->$element)\n" 
      if ($opt_d > 7);
    if (!$vulns{$id}{method_send}) {
      if ($vulns{$id}{expect} or $vulns{$id}{ignore}) {
        $vulns{$id}{method_send} = 'GET';
      } else {
        $vulns{$id}{method_send} = 'GET';
      }
    }
    $vulns{$id}{contenttype} = 'text/html|plain' if (!$vulns{$id}{contenttype});
    $vulns{$id}{description} .= 'The %CGI% notation in a name or other areas denotes that this vulneability will be looked for in existing CGI directories, like /cgi-bin and /bin.  The scanner has a list of CGI directories to check for and each scan that has a %CGI% in it gets checked for each directory that exists.' if ($vulns{$id}{name} =~ /\%CGI\%/);
    $vulns{$id}{version} = 'Unspecific' unless $vulns{$id}{version};
    $vulns{$id}{level} = 'Unspecified' unless $vulns{$id}{level};
    $vulns{$id}{info} = 'No other information is available at this time.' unless $vulns{$id}{info};
    $vulns{$id}{get} =~ s/^\/?(.*)$/$1/;
    $id = '';
  }
  $cur_ele = '';
}

sub characterData {
  my($parseinst, $data) = @_;
  if ($cur_ele and $id and !$finger) {
    $vulns{$id}{$cur_ele} .= $data;
    print STDERR "$cli_exec ($$): Set XML Element Data $id->$cur_ele->$data\n" 
      if ($opt_d > 7 and $data =~ /\S/);
    if ($cur_ele eq 'get' and $data =~ /\%CGI\%/ and (grep /^$id$/, @scans or $add_all)) {
      print STDERR "$cli_exec ($$): $id added to \@check_cgi\n" 
        if ($opt_d > 5);
      push @check_cgi, $id;
    }
  } elsif ($cur_ele and $fingerprint and $finger) {
    $fingerprints{$fingerprint}{$cur_ele} = $data;
    print STDERR "$cli_exec ($$): Set XML Element Data $fingetprint->$cur_ele->$data\n" 
      if ($opt_d > 7 and $data =~ /\S/);
  }
}

# END Custom XML Parsing Stuff....

sub show_vulns {
  # if ($opt_S) {
    # print STDERR "$cli_exec ($$): Using scans $opt_S\n"
      # if ( $opt_d );
    # @scans = split(',', $opt_S);
  # } else {
    $add_all++;
  # }
  print "Loading Vulnerability Database\n" if ($opt_d);
  if (!$opt_f and -e $default_config ) {
    $opt_f = $default_config;
    print STDERR "$cli_exec ($$): setting -f to $opt_f\n"
      if ( $opt_d );
  } elsif (!$opt_f and -e "$cli_path/$default_config") {
    $opt_f = "$cli_path/$default_config";
    print STDERR "$cli_exec ($$): setting -f to $opt_f\n"
      if ( $opt_d );
  }
  &load_vulns;
  for $id ( sort {$a <=> $b} @scans ) {
    print STDERR "$cli_exec ($$): Adding $id\n"
      if ( $opt_d );
    if ($HTML) {
      my $CVE_URL = $MS_URL = $BID_URL = '';
      if ($vulns{$id}{CVE} =~ /^CA\-/) { 
        $CVE_URL = "<b>CERT Advisory:</b> <a href='http://www.cert.org/advisories/$vulns{$id}{CVE}.html' target='_blank'>$vulns{$id}{CVE}</a>\n";
      } elsif ($vulns{$id}{CVE} =~ /^CAN/) {
        $CVE_URL = "<b>CVE Candidate:</b> <a href='http://icat.nist.gov/icat.cfm?cvename=$vulns{$id}{CVE}' target='_blank'>$vulns{$id}{CVE}</a>\n";
      } elsif ($vulns{$id}{CVE}) {
        $CVE_URL = "<b>CVE:</b> <a href='http://icat.nist.gov/icat.cfm?cvename=$vulns{$id}{CVE}' target='_blank'>$vulns{$id}{CVE}</a>\n";
      } else {
        $CVE_URL = "";
      }
      my @BID =  split(',',$vulns{$id}{BID});
      for my $BID (@BID) {
        $BID =~ s/\s//g;
        if ($BID) { 
          $BID_URL .= "<b>BubtraqID</b>: <a href='http://online.securityfocus.com/bid/$BID' target='_blank'>$BID</a>\n";
        }
      }
      my @MS =  split(',',$vulns{$id}{MS});
      for my $MS (@MS) {
        $MS =~ s/\s//g;
        if ($MS) { 
          $MS_URL .= "<b>Microsoft</b>: <a href='http://www.microsoft.com/technet/security/bulletin/$MS.mspx' target='_blank'>$MS</a>\n";
        }
      }
      my $descript = swrite(<<'END', "$vulns{$id}{description}");
    ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ~~
END
      my $fix = swrite(<<'END', "$vulns{$id}{fix}");
    ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ~~
END
      my $info = $vulns{$id}{info};
      if (length $info > 60) {
        $info_name = substr($info, 0, 40) . '...';
      } else {
        $info_name = $info;
      }
      if ($info =~ /^https?:\/\//) {
        $echo_info = "<a href='$info' target='_blank'><b>$info_name</b></a>";
      } else {
        $echo_info = "<b>$info_name</b>";
      }
      my $name = $vulns{$id}{name};
      if (length $name > 60) {
        $short_name = substr($name, 0, 40) . '...';
      } else {
        $short_name = $name;
      }
      $information{$id} = <<_EOF_;
<div class="vulnDetails" id="id$id">
<table width=500><tr><td width=495>$id) <font size=+1><b>$name</b></font><br>
$descript
Severity: <b>$vulns{$id}{level}</b>
Version Effected: <b>$vulns{$id}{version}</b>
Fix: <b>$fix</b>
Info: $echo_info

$CVE_URL
$BID_URL
$MS_URL
</td><!-- td align=right valign=top><a href="javascript:hideHelp();" class="helpClose">X</a></td --></tr></table>
</div>
_EOF_
      if ($opt_S == $id) {
        $select .= "<option value=\"$ENV{SCRIPT_NAME}?L=1&S=$id\" selected>$id) $short_name";
      } else {
        $select .= "<option value=\"$ENV{SCRIPT_NAME}?L=1&S=$id\">$id) $short_name";
      }
    } else {
      print "$id) $vulns{$id}{name}\n";
      print "   Severity       $vulns{$id}{level}\n";
      print "   Server         $vulns{$id}{version}\n" if ($opt_v);
      print "   Request Type   $vulns{$id}{method_send}\n" if ($opt_v);
    }
  }
  if ($HTML) {
    print STDERR "$cli_exec ($$): Printing HTML Output\n"
      if ( $opt_d );
    print "<center><form name=vulnselectform>
<select name=\"vulnselect\" size=\"1\" style=\"width:300\"
onchange=\"location.href=document.vulnselectform.vulnselect[document.vulnselectform.vulnselect.selectedIndex].value;\">\n$select</select><br><br>";
    for my $S_id (split(',', $opt_S)) {
      print "$information{$S_id}<br>\n";
    }
    print "</center>", end_form, end_html;
  }
  exit 0;
}

sub get_server_type {
  print STDERR "$cli_exec ($$): Searching for Server type\n"
    if ($opt_d);
  my ($ip, $port, $content, $ignore_server) = @_;
  my $server;
  if ($content and !$ignore_server) {
    print STDERR "$cli_exec ($$): No Server field"
      . " - Going to search for it in the response\n" 
      if ($opt_d >2);
    @data = split '\n', $content;
    for $i (0..5) { 
      print STDERR "$cli_exec ($$): LINE $i:  $data[$i]\n" 
        if ($opt_d > 2);
      $data[$i] =~ s/[\n\r]//g;
      if ($data[$i] =~ /^Server: (.+)$/) { 
        $server = $1; 
        return $server;
      } elsif ($data[$i] =~ /^Servlet-Engine: (.+)$/) { 
        $server = $1; 
        return $server;
      }
    }
  }
  if (!$ignore_server) {
    STATUS: for $status_page (split '\|', $status_pages) {
      print STDERR "$cli_exec ($$): Still No Server field"
        . " - Going to search for it in the '/$status_page' page\n"
          if ($opt_d > 1);
      my $tmpreq;
      if ($opt_s) {
        $tmpreq = HTTP::Request->new(GET, "https://$ip:$port/$status_page");
        print STDERR "$cli_exec ($$): GET https://$ip:$port/$status_page\n"
          if ($opt_d > 1);
      } else {
        $tmpreq = HTTP::Request->new(GET, "http://$ip:$port/$status_page");
        print STDERR "$cli_exec ($$): GET http://$ip:$port/$status_page\n"
          if ($opt_d > 1);
      }
      my $tmpres = $ua->simple_request($tmpreq);
      if (!$tmpres->is_error) {
        my @data = split '\n', $tmpres->content;
        HEADER: for $line (0..10) {
          my ($key, $value, $version) = split(':', $data[$line]);
          if ($key =~ 'Server Version') {
            print STDERR "$cli_exec ($$): Got server version ($value) from /$status_page page\n"
              if ($opt_d);
            $server = $value;
            $server =~ s/\<br\>/**/i;
            return $server;
            last HEADER;
            last STATUS;
          }
        }
      } else {
        my $code = $tmpres->code;
        my $content = $tmpres->content;
        print STDERR "$cli_exec ($$): /$status_page page returned $code\n"
          if ($opt_d);
        print STDERR "$cli_exec ($$): /$status_page page returned $content\n"
          if ($opt_d > 3);
      }
    }
  }
#############################################
#
# Finger printing via OPTIONS
#
#####
  print STDERR "$cli_exec/2096 ($$): Still No Server field"
    . " - Going to try finger printing\n"
      if ($opt_d > 1);
  my $data = raw_request($ip, $port, "OPTIONS / HTTP/1.0\r\nHost: $ip");
  my %header = (); my @order = ();;
  $tried_detect{$ip} = 1;
  LINE: for my $line (split "\n", $data) {
    chomp $line;
    $line =~ s/\r//g;
    last LINE if ($line =~ /^$/);
    my ($key, $value) = split (':', $line);
    if (!$value) {
      if ($key !~ /^HTTP\/1/) {
        last LINE;
      } elsif ($key =~ /^HTTP\/1/) {
        $header{response} = $key;
        print STDERR "$cli_exec/2110 ($$): FINGERPRINT - response : $key\n"
          if ($opt_d > 4);
      }
      next LINE;
    }
    push @order, $key;
    $value =~ s/^\s//;
    if (
         ($key eq 'Server' or $key eq 'Servlet-Engine') 
         and $value ne "HTTP/1.0"
       ) {
        print STDERR "$cli_exec/2121 ($$): Looks like Server was retured '$value'\n"
          if ($opt_d > 1);
      return $value unless ($ignore_server);
    }
    $header{$key} = $value;
    print STDERR "$cli_exec/2126 ($$): FINGERPRINT - $key : $value\n"
      if ($opt_d > 4);
  }
  if (@order) {
    print STDERR "$cli_exec/2130 ($$): FINGERPRINT - Order : " . join (', ', @order)
      . "\n" if ($opt_d > 4);
    $header{order} = join (', ', @order);
    for $test_server (keys %fingerprints) {
      print STDERR "$cli_exec ($$): FINGERPRINTING\n"
        if ($opt_d > 4);
      print STDERR "$cli_exec ($$): FINGERPRINT - checking $test_server \n"
        if ($opt_d > 4);
      for my $key (keys %header) {
        print STDERR "$cli_exec ($$): FINGERPRINT - checking $key against $test_server \n"
          if ($opt_d > 5);
        print STDERR "$cli_exec ($$): FINGERPRINT - Does '$header{$key}' eq '$fingerprints{$test_server}{$key}' ?\n"
          if ($opt_d > 6);
        
        if ($header{$key} eq $fingerprints{$test_server}{$key} 
            and $fingerprints{$test_server}{$key} ) {
          print STDERR "$cli_exec ($$): Looks like $test_server from $key\n"
            if ($opt_d > 1);
          $weight{$test_server} += 5;
        } elsif ($key eq 'response' and 
            ($header{$key} ne $fingerprints{$test_server}{$key}
            and $fingerprints{$test_server}{$key} ) ) {
          $weight{$test_server} -= 3;
        }
        if ($key eq 'order'
            and $fingerprints{$test_server}{$key}) {
          my @current_order = split(', ', $header{$key});
          my @finger_order = split(', ', $fingerprints{$test_server}{$key});
          for $i (0..$#finger_order) {
            if ($finger_order[$i] eq 'Server'){
              splice(@finger_order, $i, 1);
            }
          }
          for $i (0..$#current_order) {
            my $field = $current_order[$i];
            if ( grep(/^$field$/, @finger_order) == 1 ) {
              print STDERR "$cli_exec ($$): FINGERPRINT - ++ $field is in order\n"
                if ($opt_d > 4);
              $weight{$test_server}++;
            }
            if ($current_order[$i] eq $finger_order[$i]) {
              print STDERR "$cli_exec ($$): FINGERPRINT - ++ $i pos match for $field\n"
                if ($opt_d > 5);
              $weight{$test_server}++;
            }
          }
        }
      }
    }
    for my $test_server (sort {$weight{$a} <=> $weight{$b}} keys %weight) {
      $server = "$test_server *";
      print STDERR "$cli_exec/2181 ($$): FINGERPRINT - $test_server == $weight{$test_server}\n"
        if ($opt_d > 3);
    }
    if ($server) {
      $fingerprinted{$ip}++;
      return $server;
    }
  }
#############################################
  if (!$server) {
    print STDERR "$cli_exec ($$): STILL No Server field"
      . " - Going to try one more thing...\n" 
      if ($opt_d >2);
    my $content = raw_request($ip, $port, "OPTIONS rtsp://$ip:$port/ RTSP/1.0\r\nCSeq: 1\r\nSession: 1234567890\r\n\r\n");
    if ($content =~ /Server: /) {
      @data = split '\n', $content;
      for $i (0..5) { 
        print STDERR "$cli_exec ($$): LINE $i:  $data[$i]\n" 
          if ($opt_d > 3);
        $data[$i] =~ s/[\n\r]//g;
        if ($data[$i] =~ /^Server: (.+)$/) { 
          $server = $1; 
          $server =~ s/ Version /\//;
          return $server;
        }
      }
    } else {
      print STDERR "$cli_exec ($$): Still No Server field"
        . " - Giving up - Leaving Server blank\n"
          if ($opt_d > 1);
    }
  }
  return $server;
}

sub scan_http {
  my ($ipaddr, $opt_p, $port_status, %rules) =@_;
  $0 = "http-scanning $ipaddr:$opt_p";
  print STDERR "$cli_exec ($$): Scanning $ipaddr:$opt_p\n" 
    if ($opt_d);
  if ($port_status) {
    add_debug("$cli_exec ($$): Port closed skipping tests.\n")
      if ($opt_d > 1);
    add_host("Port $opt_p Not Open", $prefix, $ipaddr, $get, $opt_p, $netbios)
      if ( ($#iplist == 0 and $opt_v) or $opt_d);
    print STDERR "#" x 72 . "\n" if ($opt_d);
    add_debug("<hr noshade>\n") if ($opt_d > 2 and ($HTML));
  } elsif (%rules) {
    my $current_version;
    my @valid_cgi;
    add_debug("$cli_exec ($$): Used Rules file for scanning $ipaddr\n")
      if ($opt_d > 1);
    if (@check_cgi) {
      print STDERR "$cli_exec ($$): Have checks with cgi directories,\n"
        if ($opt_d > 1);
      my @cgi_dirs = @cgi_dirs;
      for $cgi (@cgi_dirs) {
        my $req = HTTP::Request->new(GET, "http://$ipaddr:$opt_p/$cgi/");
        my $res = $ua->simple_request($req);
        if ($res->code ne '404' and $res->code ne '401') {
          print STDERR "$cli_exec ($$): $cgi looks valid (" . $res->code . ")\n"
            if ($opt_d > 1);
          push @valid_cgi, $cgi;
          for $cgi_id (@check_cgi) {
            $id = "$cgi_id$cgi"; 
            push @scans, $id;
            $rules{$id}{name} = $rules{$cgi_id}{name};
            $rules{$id}{get} = $rules{$cgi_id}{get};
            $rules{$id}{expect} = $rules{$cgi_id}{expect};
            $rules{$id}{return_code} = $rules{$cgi_id}{return_code};
            $rules{$id}{ignore} = $rules{$cgi_id}{ignore};
            $rules{$id}{post} = $rules{$cgi_id}{post};
            $rules{$id}{version} = $rules{$cgi_id}{version};
            $rules{$id}{method_send} = $rules{$cgi_id}{method_send};
            $rules{$id}{user} = $rules{$cgi_id}{user};
            $rules{$id}{pass} = $rules{$cgi_id}{pass};
            $rules{$id}{fix} = $rules{$cgi_id}{fix};
            $rules{$id}{vid} = $rules{$cgi_id}{vid};
            $rules{$id}{contenttype} = $rules{$cgi_id}{contenttype};
            $rules{$id}{info} = $rules{$cgi_id}{info};
            $rules{$id}{description} = $rules{$cgi_id}{description};
            $rules{$id}{CVE} = $rules{$cgi_id}{CVE};
            $rules{$id}{BID} = $rules{$cgi_id}{BID};
            $rules{$id}{MS} = $rules{$cgi_id}{MS};
            $rules{$id}{level} = $rules{$cgi_id}{level};
            $rules{$id}{get} =~ s/\%CGI\%\/?/$cgi\//;
            $rules{$id}{name} =~ s/\%CGI\%/$cgi/;
            $rules{$id}{description} =~ s/\%CGI\%/$cgi/;
          }
        } else {
          print STDERR "$cli_exec ($$): $cgi not valid (" . $res->code . ")\n"
            if($opt_d > 1);
        }
      }
      if ($#iplist == 0) { @report_cgi = @valid_cgi }
    }
    CHECK: for $id (sort{$a <=> $b} @scans) {
      my $name = $rulename = $rules{$id}{name};
      my $get = $rules{$id}{get};
      next if ($get =~ /\%CGI\%/);
      print STDERR '#' x 50 . "\n" 
        if ($opt_d);
      print STDERR "$cli_exec ($$): $ipaddr:$opt_p - SCANID: $id\n"
        if ($opt_d);
      if ($get =~ /\%FILL\%(\d+)\%/) {
        my $filler;
        my $char = $1;
        for my $i (1..$char) {
          $filler .= chr(int(rand(26)) + 97 );
        }
        $get =~ s/\%FILL\%\d+\%/$filler/;
        my $count = length($filler);
        print STDERR "$cli_exec ($$): \%FILL\%$char\% replaced by $count random chrs \n"
          if ($opt_d > 1);
      }
      if ($get =~ /\%HEX\%(\w+)\%/) {
        my $filler;
        my $char = $1;
        $filler = chr(hex($char));
        $get =~ s/\%HEX\%\w+\%/$filler/;
        my $count = length($filler);
        print STDERR "$cli_exec ($$): \%HEX\%$char\% replaced by $count chrs\n"
          if ($opt_d > 1);
      }
      print STDERR "$cli_exec ($$): $name \$get = $get\n"
        if ($opt_d > 3);
      my $expect = $rules{$id}{expect};
      print STDERR "$cli_exec ($$): $name \$expect = $expect\n"
        if ($opt_d > 3);
      my $RC = $rules{$id}{return_code};
      print STDERR "$cli_exec ($$): $name \$RC = $RC\n"
        if ($opt_d > 3);
      my $ignore = $rules{$id}{ignore};
      print STDERR "$cli_exec ($$): $name \$ignore = $ignore\n"
        if ($opt_d > 3);
      my $post = $rules{$id}{post};
      print STDERR "$cli_exec ($$): $name \$post = $post\n"
        if ($opt_d > 3);
      my $version = $rules{$id}{version};
      print STDERR "$cli_exec ($$): $name \$version = $version\n"
        if ($opt_d > 3);
      $method_send = $rules{$id}{method_send};
      print STDERR "$cli_exec ($$): $name \$method_send = $method_send\n"
        if ($opt_d > 3);
      my $user = $rules{$id}{user};
      print STDERR "$cli_exec ($$): $name \$user = $user\n"
        if ($opt_d > 3);
      my $pass = $rules{$id}{pass};
      print STDERR "$cli_exec ($$): $name \$pass = $pass\n"
        if ($opt_d > 3);
      my $fix = $rules{$id}{fix};
      print STDERR "$cli_exec ($$): $name \$fix = $fix\n"
        if ($opt_d > 4);
      my $vid = $rules{$id}{vid};
      print STDERR "$cli_exec ($$): $name \$vid = $vid\n"
        if ($opt_d > 3);
      my $contenttype = $rules{$id}{contenttype};
      print STDERR "$cli_exec ($$): $name \$contenttype = $contenttype\n"
        if ($opt_d > 3);
      my $info = $rules{$id}{info};
      print STDERR "$cli_exec ($$): $name \$info = $info\n"
        if ($opt_d > 4);
      my $description = $rules{$id}{description};
      print STDERR "$cli_exec ($$): $name \$description = $description\n"
        if ($opt_d > 4);
      my $CVE = $rules{$id}{CVE};
      print STDERR "$cli_exec ($$): $name \$CVE = $CVE\n"
        if ($opt_d > 4);
      my $BID = $rules{$id}{BID};
      print STDERR "$cli_exec ($$): $name \$BID = $BID\n"
        if ($opt_d > 4);
      my $MS = $rules{$id}{MS};
      print STDERR "$cli_exec ($$): $name \$MS = $MS\n"
        if ($opt_d > 4);
      my $level = $rules{$id}{level};
      print STDERR "$cli_exec ($$): $name \$level = $level\n"
        if ($opt_d > 4);
      $0 = "http-scanning $ipaddr:$opt_p - $id) $rulename";
      print STDERR "$cli_exec ($$): $ipaddr:$opt_p - $rulename\n" 
        if ($opt_d);
      $expect =~ s/([\[\]\>\<\(\)\^\$\*\@\\\?\.])/\\$1/g;
      $expect =~ s/\%REG\%([\w\+\$]+)\%/\\$1/g;
      #
      if ($post =~ /\%FILL\%(\d+)\%/) {
        my $filler;
        my $char = $1;
        for my $i (1..$char) {
          $filler .= chr(int(rand(26)) + 97 );
        }
        $post =~ s/\%FILL\%\d+\%/$filler/;
        my $count = length($filler);
        print STDERR "$cli_exec ($$): \%FILL\%$char\% replaced by $count random chrs \n"
          if ($opt_d > 1);
      }
      #
      if ($opt_T ) {
        my $opt_T_flag;
        TYPETEST: for my $local_type (split(',', $opt_T)) {
          if ($local_type =~ /^!(\S+)/) {
            my $match = $1;
            if ( 
                 $method_send =~ /^$match/i
                 xor $version =~ /^$match/i
                 xor $match =~ /$version/i
                 xor $level =~ /^$match/i
               ) { 
              add_debug("$cli_exec ($$): Test does not match ($local_type $method_send|$version|$level)\n")
                if ($opt_d > 1);
              $opt_T_flag++;
            } else {
              add_debug("$cli_exec ($$): Test matches ($local_type $method_send|$version|$level)\n")
                if ($opt_d > 1);
              $opt_T_flag = '';
              last TYPETEST;
            }
          } else {
            if ( 
                 $method_send !~ /^$local_type/i
                 and $version !~ /^$local_type/i
                 and $local_type !~ /$version/i
                 and $level !~ /^$local_type/i
               ) { 
              add_debug("$cli_exec ($$): Test does not match ($local_type $method_send|$version|$level)\n")
                if ($opt_d > 1);
              $opt_T_flag++;
            } else {
              add_debug("$cli_exec ($$): Test matches ($local_type $method_send|$version|$level)\n")
                if ($opt_d > 1);
              $opt_T_flag = '';
              last TYPETEST;
            }
          }
        }
        if ($opt_T_flag) {
          next CHECK;
        }
      }
      $vuln_count++;
      add_debug("------------------------------------\n")
        if ($opt_d > 1);
      add_debug("$cli_exec ($$): Test \"$rulename\" on $ipaddr\n")
        if ($opt_d > 1);
      print STDERR "$cli_exec ($$): Running Test \"$rulename\" on $ipaddr\n" 
        if ($opt_d > 1);
      if ($method_send eq 'POST') {
        print STDERR "$cli_exec ($$): Test ($rulename) is using $method_send\n" 
          if ($opt_d > 2);
        if ($opt_s) {
          $req = HTTP::Request->new(POST, "https://$ipaddr:$opt_p/$get");
          $prefix = 'https';
        } else {
          $req = HTTP::Request->new(POST, "http://$ipaddr:$opt_p/$get");
          $prefix = 'http';
        }
        $req->header('Content-Type', "application/x-www-form-urlencoded");
        $req->header('Content-length', length $post);
        $req->content($post) if ($post);
      } elsif ($method_send eq 'PUT') {
        print STDERR "$cli_exec ($$): Test ($rulename) is using $method_send\n" 
          if ($opt_d > 2);
        my $tmpreq = HTTP::Request->new(OPTIONS, "http://$ipaddr:$opt_p/$get");
        my $tmpres = $ua->request($tmpreq);
        if ( $tmpres->header('Allow') =~ /PUT/ ) {
          my $date = scalar localtime;
          $req = HTTP::Request->new(PUT, "http://$ipaddr:$opt_p/$get"); 
          $req->content("YOU HAVE BEEN HACKED\n"
            . "Posted from: $ENV{HOSTNAME}\n"
            . "Posted with: PUT Method via HTTP\n"
            . "Scaned on: $date\n\n");
          $prefix = 'http';
        } else {
          print STDERR "$cli_exec ($$): Checking 'PUT'ability. "
            . "PUT not included in Allow Header\n"
            . "$cli_exec ($$): Allow: " . $tmpres->header('Allow')
            . "\n"
            if ($opt_d > 1 );
          next CHECK;
        }
      } elsif ($method_send eq 'DELETE') {
        print STDERR "$cli_exec ($$): Test ($rulename) is using $method_send\n" 
          if ($opt_d > 2);
        my $tmpreq = HTTP::Request->new(OPTIONS, "http://$ipaddr:$opt_p/$get");
        my $tmpres = $ua->request($tmpreq);
        if ( $tmpres->header('Allow') =~ /DELETE/ ) {
          my $date = scalar localtime;
          $req = HTTP::Request->new(PUT, "http://$ipaddr:$opt_p/$get"); 
          $req->content("YOU HAVE BEEN HACKED\n"
            . "Posted from: $ENV{HOSTNAME}\n"
            . "Posted with: PUT Method via HTTP\n"
            . "Scaned on: $date\n\n");
          $prefix = 'http';
        } else {
          print STDERR "$cli_exec ($$): Checking 'DELETE'ability."
            . "  DELETE not included in Allow Header\n"
            . "$cli_exec ($$): Allow: " . $tmpres->header('Allow')
            . "\n"
            if ($opt_d > 1 );
          next CHECK;
        }
      } elsif ($method_send eq 'OPTIONS') {
        print STDERR "$cli_exec ($$): Test ($rulename) is using $method_send\n" 
          if ($opt_d > 2);
        $req = HTTP::Request->new(OPTIONS, "http://$ipaddr:$opt_p/$get");
        $prefix = 'http';
      } elsif ($method_send eq 'Proxy') {
        print STDERR "$cli_exec ($$): Test ($rulename) is using $method_send\n" 
          if ($opt_d > 2);
        print STDERR "$cli_exec ($$): Checking for Proxy\n" 
          if ($opt_d > 1);
        print STDERR "$cli_exec ($$): using http://$ipaddr:$opt_p/ as http proxy server\n" 
          if ($opt_d > 2);
        $ua->proxy('http', "http://$ipaddr:$opt_p/");
        $req = HTTP::Request->new(GET, "$get");
        $prefix = 'http';
      } elsif ($method_send eq 'HEAD') {
        print STDERR "$cli_exec ($$): Test ($rulename) is using $method_send\n" 
          if ($opt_d > 2);
        if ($opt_s) {
          $req = HTTP::Request->new(HEAD, "https://$ipaddr:$opt_p/$get");
          $prefix = 'https';
        } else {
          $req = HTTP::Request->new(HEAD, "http://$ipaddr:$opt_p/$get");
          $prefix = 'http';
        }
      } elsif ($method_send eq 'GET') {
        print STDERR "$cli_exec ($$): Test ($rulename) is using $method_send\n" 
          if ($opt_d > 2);
        if ($opt_s) {
          $req = HTTP::Request->new(GET, "https://$ipaddr:$opt_p/$get");
          $prefix = 'https';
        } else {
          $req = HTTP::Request->new(GET, "http://$ipaddr:$opt_p/$get");
          $prefix = 'http';
        }
      } elsif ($method_send eq 'RAW') {
        print STDERR "$cli_exec ($$): Test ($rulename) using $method_send\n" 
          if ($opt_d > 2);
        $get =~ s/\%HOST\%/$ipaddr/g;
        if ($opt_s) {
          $req = HTTP::Request->new(GET, "https://$ipaddr:$opt_p/");
          $prefix = 'https';
        } else {
          $req = HTTP::Request->new(GET, "http://$ipaddr:$opt_p/");
          $prefix = 'http';
        }
      } else {
        print STDERR "$cli_exec ($$): Test ($rulename) is using $method_send\n" 
          if ($opt_d > 2);
        if ($opt_s) {
          $req = HTTP::Request->new($method_send, "https://$ipaddr:$opt_p/");
          $prefix = 'https';
        } else {
          $req = HTTP::Request->new($method_send, "http://$ipaddr:$opt_p/");
          $prefix = 'http';
        }
        print STDERR "$cli_exec ($$): Maybe unknown request type ($method_send). Try anyway.\n"
          if ($opt_d);
      }
      if ($opt_C) {
        ($user, $pass) = split('\:', $opt_C);
      }
      $output .= "<hr>\n" if ($opt_d > 2 and ($HTML));
      add_debug("$cli_exec ($$): '$method_send $prefix://$ipaddr:$opt_p/$get'"
        . " expecting '$expect' on $version\n")
        if ($opt_d > 1);
      if ( 
           ( 
             $current_version !~ /$version/i 
             and $version ne 'Unspecific'
             and (
               $current_version 
               #or $version =~ /^Microsoft/
             )
           ) and !$opt_a 
         ) {
        add_debug("$cli_exec ($$): Wrong server type(" . 
          $current_version . " !~ $version). Skiping rule($name).\n")
          if ($opt_d > 1);
        next CHECK;
      } else {
        $real_scanned++;
      }
      my $res, $return_code, $allow, $modifie, $current_type;
      if ($scanned{$ipaddr}{$get} and $method_send ne 'RAW') {
        # print "Dup scan $id => $scanned{$ipaddr}{$get}{'id'}
        # GET -> $get
        # $scanned{$ipaddr}{$get}{'id'} -> $rules{$scanned{$ipaddr}{$get}{'id'}}{'expect'} 
        # $id -> $expect\n";
        
        $res = $ua->simple_request($req);
        $return_code = $res->code;
        $allow = $res->header('Allow');
        $modified = $res->header('Last-Modified');
        $current_type = $res->header('Content-Type'); 
      } else {
        $scanned{$ipaddr}{$get}{'res'} = $res = $ua->simple_request($req);
        $scanned{$ipaddr}{$get}{'return_code'} = $return_code = $res->code;
        $scanned{$ipaddr}{$get}{'allow'} = $allow = $res->header('Allow');
        $scanned{$ipaddr}{$get}{'modified'} = $modified = $res->header('Last-Modified');
        $scanned{$ipaddr}{$get}{'current_type'} = $current_type = $res->header('Content-Type'); 
        $scanned{$ipaddr}{$get}{'id'} = $id;
        $scanned{$ipaddr}{$get}{'content'} = $res->content;
      }
      if (!$current_version) {
        if ( (
               !$res->header("Server") 
               or $res->header("Server") eq 'HTTP/1.0'
               or ($#scans == 0 and $scans[0] == 2)
             )
            and !$tried_detect{$ipaddr}
           ) {
          $current_version = get_server_type($ipaddr, $opt_p, $res->content);
        } else { 
          add_debug( "$cli_exec ($$): Using Server header field for Version\n" )
            if ($opt_d > 2);
          $current_version = $res->header("Server"); 
        }
        add_debug( "$cli_exec ($$): Current Version: $current_version\n" )
          if ($opt_d > 1);
      } else {
        add_debug( "$cli_exec ($$): Current Version already set: $current_version\n" )
          if ($opt_d > 5);
      }
      if ($current_type !~ m<^$contenttype>i
        and $current_type and $method_send ne 'RAW') {
        add_debug( "$cli_exec ($$): Skipping rule ($name): Wrong Content-Type\n")
          if ($opt_d > 1);
        add_debug( "$cli_exec ($$): Content-Type: $current_type returned\n" 
          . "$cli_exec ($$): Content-Type: $contenttype expected\n" )
          if ($opt_d > 1);
        next CHECK;
      } elsif ($method_send eq 'RAW') {
        add_debug( "$cli_exec ($$): RAW Request\n" )
          if ($opt_d > 1);
      } else {
        add_debug(  "$cli_exec ($$): Correct Content-Type Returned\n"
          . "$cli_exec ($$): EXPECTED: Content-Type: $contenttype\n" 
          . "$cli_exec ($$): RETURNED: Content-Type: $current_type\n" )
          if ($opt_d > 2);
      }
      if ( ! $res->is_error ) {
        print STDERR "$cli_exec ($$): Request returned successful ($return_code)\n"
          if ($opt_d > 2);
        if ($return_code eq 301 and $method_send ne 'RAW') { 
          print STDERR "$cli_exec ($$): Web server returned 301 (Moved)."
            . " Moving to next scan\n"
            if ($opt_d);
          next CHECK; 
        }
        if ($return_code eq 302 
            and $method_send ne 'RAW' 
            and $RC ne $return_code) { 
          print STDERR "$cli_exec ($$): Web server returned 302 (Moved)."
            . " Moving to next scan\n"
            if ($opt_d);
          next CHECK; 
        }
        if ($res->header("Refresh") =~ /URL=/i) {
          my ($time, $new_site) = split /URL=/i, $res->header("Refresh");
          if ($new_site eq $something_not_defined) {
            # if it is just a refresh and not a redirect.
            # working on the logic
          } else {
            print STDERR "$cli_exec ($$): Has Automatic Refresh to $new_site."
              . " Moving to next scan\n"
              if ($opt_d);
            next CHECK; 
          }
        }
        if ($res->content =~ /^RTSP\/1/ and $#iplist == 0) {
          print STDERR "$cli_exec ($$): Web server returned what looks"
            . " like streaming data. Skipping host ($ipaddr).\n"
            if ($opt_d);
          add_host("Streaming Server", $prefix, $ipaddr, $get, $opt_p, $netbios,
            $current_version, $method_send, $modified, $allow, 
            $return_code, $fix, 'N/A', $id, $info, 
            $version, 'Informational', '', 'Looks like a streaming server, not a web server' );
          print STDERR "$cli_exec ($$): Scan completed for $ipaddr:$opt_p\n" 
            if ($opt_d);
          last CHECK;
        }
        print STDERR "$cli_exec ($$): Checking for vulnerability ($name)\n" 
          if ($opt_d);
        if ($vid) {
          print STDERR "$cli_exec ($$): CV: $current_version, Vuln Ver: $version, $vid\n"
            if ($opt_d > 1 and $current_version);
          if ( $current_version and 
            check_version($current_version, $version, $vid) ) {
            print STDERR "$cli_exec ($$): Adding Old Version\n"
              if ($opt_d > 1);
            add_host("Vuln Ver $name", $prefix, $ipaddr, $get, $opt_p, $netbios, 
              $current_version, $method_send, $modified, $allow, 
              $return_code, $fix, $res->content, $id, $info, 
              $version, $level, $CVE, $description, $proto, $BID, $MS );
          }
          next CHECK;
        } 
        if ( 
            ( 
              $res->content =~ m<$expect>i
              and $method_send ne 'RAW' 
              and ($res->content !~ m<$ignore>i or !$ignore)
            ) or (
              $method_send eq "OPTIONS" 
              and $allow =~ m<$expect>i
            ) or (
              $method_send eq "GET" 
              and $RC eq $return_code
              and ($res->content !~ m<$ignore>i or !$ignore)
            ) 
          ) {
        # print STDERR "2042 - $name - " . md5_hex($res->content) . " - $ipaddr\n";
          print STDERR "$cli_exec ($$): So far, Looks vulnerable, let's keep checking\n"
            if ($opt_d > 3);
          if (
                ( 
                  $RC == 302 and
                  $res->header("Location") !~ m<$expect> 
                ) or ( 
                  $RC == 302 and
                  $res->header("Location") !~ m<$ignore> or
                  $res->content !~ m<$ignore> and $ignore
                )
              ) {
            add_debug("$cli_exec ($$): Redirect to wrong location (" 
              . $res->header("Location") . " != $expect)\n")
              if ($opt_d > 2);
            add_debug("$cli_exec ($$): Or Matched Ignore (" 
              . $res->header("Location") . " =~ $ignore)\n")
              if ($opt_d > 2);
            next CHECK;
          } elsif (
              $RC == 302 
              and $res->header("Location") =~ m<$expect>
            ) {
            add_debug("$cli_exec ($$): Redirected to right location (" 
              . $res->header("Location") . " =~ $expect ($ignore))\n")
              if ($opt_d > 2);
          }
          #
          print STDERR "$cli_exec ($$): Adding match $rulename\n"
            if ($opt_d > 1);
          add_host($name, $prefix, $ipaddr, $get, $opt_p, $netbios, 
            $current_version, $method_send, $modified, $allow, 
            $return_code, $fix, $res->content, $id, $info, 
            $version, $level, $CVE, $description, $proto, $BID, $MS);
        } elsif (!$expect 
            and $method_send ne 'RAW'
            and ($res->content !~ m<$ignore>i or !$ignore)
            and $res->content
          ) {
          print STDERR "$cli_exec ($$): Adding (no)match\n"
            if ($opt_d > 1);
          if (
               $res->content =~ m<file|page|document not found>i
              ) {
            print STDERR "$cli_exec ($$): looks like a custom 404 page\n"
              if ($opt_d > 1);
              next CHECK;
          }
          if ($res->header('Server') ne $current_version) {
            # print "May be an issue here\n";
          } 
##########################################################
          print STDERR "$cli_exec ($$): Checking HTML for an onLoad redirect\n"
            if ($opt_d > 1);
          $parser = HTML::Parser->new(api_version=>3,
            start_h=>[\&startTag, 'tag, attr'] ,
            end_h=>[\&endTag, 'tag'] ,
            text_h=>[\&textElem, 'text']
          );
          $parser->parse($res->content);
          if ($content{body}{onload}) {
            print STDERR "$cli_exec ($$): We have an onLoad, investigating\n"
              if ($opt_d > 1);
            for my $onload (split ';', $content{body}{onload}) {
              $onload =~ /(\w+)\(/;
              my $function = $1;
              my $within, $nf;
              for my $word (split ' ', $content{script}{text}) {
                if (!$within and lc($word) eq 'function') {
                  $nf = 1;
                  next;
                } elsif (!$within and $nf and $word =~ /$function/) {
                  $nf = 0; $within = 1;
                } elsif ($within) {
                  if ($word eq '{') {
                    next;
                  } elsif ($word eq '}') {
                    $within = 0;
                  } else {
                    push @routine, $word;
                  }
                } else {
                  $nf = 0; $within = 0;
                }
              }
              my $routine = join ' ', @routine;
              if ($routine =~ /location\.href\s?\=\"?/) {
                print STDERR "$cli_exec ($$): Looks like a possible redirect"
                  . " in JavaScript.  Skipping current test.\n"
                  if ($opt_d > 1);
              } else {
         # print STDERR "2092 - $name - " . md5_hex($res->content) . " - $ipaddr\n";
                add_host("Possible $name", $prefix, $ipaddr, $get, $opt_p, $netbios, 
                  $current_version, $method_send, $modified, $allow, 
                  $return_code, $fix, $res->content, $id, $info, 
                  $version, $level, $CVE, $description, $proto, $BID, $MS );
              }
            }
          } else {
##########################################################
         # print STDERR "\n2101 - $name - " . md5_hex($res->content) . " - $ipaddr\n";#  . $res->content . "\n";
          print STDERR "$cli_exec ($$): Adding Vuln ($name)\n"
            if ($opt_d > 1);
          add_host("$name.", $prefix, $ipaddr, $get, $opt_p, $netbios, 
            $current_version, $method_send, $modified, $allow, 
            $return_code, $fix, $res->content, $id, $info, 
            $version, $level, $CVE, $description, $proto, $BID, $MS );
          }
        } else {
          if ($res->content !~ m<$expect>i and $expect) {
            add_debug("$cli_exec ($$): REASON Content does not match expect\n")
              if ($opt_d > 2);
            add_debug("$cli_exec ($$): EXPECTING: $expect \n")
              if ($opt_d > 3);
          }
          add_debug( "$cli_exec ($$): Scan does not match\n" )
            if ($opt_d > 1);
          add_debug( "$cli_exec ($$): ReturnCode: " . $return_code 
            . " & Message: " . $res->message . "\n")
            if ($opt_d > 1);
          add_debug( "$cli_exec ($$): HTML Output:\n" . 
            $res->content . "-" x 30 . "\n")
            if ($opt_d > 2 and $return_code == 200);
          add_debug( "$cli_exec ($$): HTML Output:\n" . 
            $res->error_as_HTML . "-" x 30 . "\n")
            if ($opt_d > 2 and $return_code != 200);
        }
        if ($method_send eq 'RAW' ) {
          print STDERR "$cli_exec ($$): Testing RAW Request\n"
            if ($opt_d > 1);
          $raw_rc = raw_request($ipaddr, $opt_p, $get);
          my @return_data = split("\n", $raw_rc);
          if ($return_data[0] =~ /^HTTP\/\d\.\d (\d{3}) (.*)$/) {
            $return_code = $1;
            $return_msg = $2;
            $return_msg =~ s/\r$//;
            print STDERR "$cli_exec ($$): RAW Return Code $return_code\n"
              if ($opt_d > 1);
            print STDERR "$cli_exec ($$): RAW Return $return_msg\n"
              if ($opt_d > 1);
          }
          for my $return_line (@return_data) {
            $return_line =~ s/[\n\r\cM]//g;
            last if ($return_line =~ /^$/);
            my ($key, $value) = split(': ', $return_line);
            add_debug( "$cli_exec ($$): RAW-HEADER: $key -> $value\n")
              if ($opt_d > 4);
            if ($key eq "Content-Type" and $value !~ m<^$contenttype>i) {
              add_debug( "$cli_exec ($$): Skipping rule ($name): Wrong Content-Type\n")
                if ($opt_d > 1);
              add_debug( "$cli_exec ($$): Content-Type: $value returned\n"
                . "$cli_exec ($$): Content-Type: $contenttype expected\n" )
                if ($opt_d > 2);
              next CHECK;
            }
          }
          if ( $raw_rc =~ m<$ignore> and $ignore ) {
            print STDERR "$cli_exec ($$): RAW Request NOT vuln\n"
              if ($opt_d > 1);
            next CHECK;
          }
          if (
               ( $raw_rc =~ m<$expect>i and $expect ne 'NULL' )
               or 
               ( !$raw_rc and $expect eq 'NULL' )
             ) {
            print STDERR "$cli_exec ($$): RAW Request looks vuln, verifying\n"
              if ($opt_d > 1);
            my $tmpreq;
            if ($opt_s) {
              $tmpreq = HTTP::Request->new(GET, "https://$ipaddr:$opt_p/");
            } else {
              $tmpreq = HTTP::Request->new(GET, "http://$ipaddr:$opt_p/");
            }
            my $tmpres = $ua->simple_request($tmpreq);
            if ( $tmpres->content or $tmpres->header("Location") ) {
              print STDERR "$cli_exec ($$): Data returned, looks vuln (not empty reply)\n"
                if ($opt_d > 1);
         # print STDERR "2146 - $name - " . md5_hex($raw_rc) . " - $ipaddr\n";
              add_host("$name", $prefix, $ipaddr, $get, $opt_p, $netbios, 
                $current_version, $method_send, $modified, $allow, 
                $return_code, $fix, $raw_rc, $id, $info, 
                $version, $level, $CVE, $description, $proto, $BID, $MS );
            } else {
              print STDERR "$cli_exec ($$): NO Data returned, looks like a false positive\n"
                if ($opt_d > 1);
            }
          } else {
            print STDERR "$cli_exec ($$): Not Vuln to RAW Request\n"
              if ($opt_d > 1);
          } 
        }
      } else {
        print STDERR "$cli_exec ($$): Initial Request Not Successful\n"
          if ($opt_d > 3);
        if ($method_send eq 'RAW') {
          my $raw_data = raw_request($ipaddr, $opt_p, $get);
          if ($raw_data =~ m<$expect>i) {
            if ($raw_data =~ m<$ignore> and $ignore) {
              add_debug("$cli_exec ($$): ignore matched RAW\n") if ($opt_d >3);
              next CHECK;
            }
            for $return_line (split "\n", $raw_data) {
              $return_line =~ s/[\n\r\cM]//g;
              last if ($return_line =~ /^$/);
              my ($key, $value) = split(': ', $return_line);
              if ($key =~ /^HTTP\/1\.[01] (\d+) (.*)$/) {
                $return_code = $1;
              } else {
                print STDERR "$cli_exec ($$): RAW-HEADER: $key -> $value\n"
                 if ($opt_d > 3);
                if ($key eq "Content-Type" and $value !~ m<^$contenttype>i) {
                  add_debug( "$cli_exec ($$): Skipping rule ($name): Wrong Content-Type\n")
                    if ($opt_d > 1);
                  add_debug( "$cli_exec ($$): Content-Type: $value returned\n"
                    . "$cli_exec ($$): Content-Type: $contenttype expected\n" )
                    if ($opt_d > 2);

                  next CHECK;
                }
              }
            }
            print STDERR "$cli_exec ($$): Raw Request Found Vuln\n"
              if ($opt_d > 1);
            add_host("$name", $prefix, $ipaddr, $get, $opt_p, $netbios, 
              $current_version, $method_send, $modified, $allow, 
              $return_code, $fix, $res->content, $id, $info, 
              $version, $level, $CVE, $description, $proto, $BID, $MS );
            next CHECK;
          }
        }
        if ( $res->content =~ m<$expect>i and $expect
              and ($res->content !~ m<$ignore>i or !$ignore) 
              and $return_code ne $ignore
              and (!$RC or $RC eq $return_code)
              # and $res->content !~ m<404 Not Found|Not Found\(404\)|403 Forbidden>
           ) {
          print STDERR "$cli_exec ($$): $expect found in Error page\n"
            if ($opt_d > 1);
         # print STDERR "1971 - $name - " . md5_hex($res->content) . " - $ipaddr\n";
          add_host("$name", $prefix, $ipaddr, $get, $opt_p, $netbios, 
            $current_version, $method_send, $modified, $allow, 
            $return_code, $fix, $res->content, $id, $info, 
            $version, $level, $CVE, $description, $proto, $BID, $MS );
          next CHECK;
        } elsif ( $return_code eq 401 ) {
          if ( $auth = $res->headers()->{'www-authenticate'} ) {
            for my $auth_type ( @$auth ) {
              print STDERR "$cli_exec ($$): 401: WWW-Authenticate: $auth_type\n"
                if ($opt_d > 4);
              if ($expect eq "WWW-Authenticate: $auth_type") {
                add_host("$name", $prefix, $ipaddr, $get, 
                  $opt_p, $netbios, $current_version, $method_send, 
                  $modified, $allow, $return_code, $fix, $res->content, 
                  $id, $info, $version, $level, $CVE, $description, $proto, $BID, $MS );
              }
            }
          }
          print STDERR "$cli_exec ($$): Access Denied\n"
            if ($opt_d > 1);


          if ($opt_d) {
            add_host("access-denied $name", $prefix, $ipaddr, $get, 
              $opt_p, $netbios, $current_version, $method_send, 
              $modified, $allow, $return_code, $fix, $res->content, 
              $id, $info, $version, $level, $CVE, $description, $proto, $BID, $MS );
          }
        } elsif ( $return_code eq 403 and $opt_d ) {
          print STDERR "$cli_exec ($$): Access Denied\n"
            if ($opt_d > 1);
          add_host("access-denied $name", $prefix, $ipaddr, $get, 
            $opt_p, $netbios, $current_version, $method_send, 
            $modified, $allow, $return_code, $fix, $res->content, 
            $id, $info, $version, $level, $CVE, $description, $proto, $BID, $MS );
        }
        if ($vid) {
          print STDERR "$cli_exec ($$): CV: $current_version, Vuln Ver: $version, $vid\n"
            if ($opt_d > 1);
          if ( check_version($current_version, $version, $vid) ) {
            print STDERR "$cli_exec ($$): Adding Old Version\n"
              if ($opt_d > 1);
            add_host("$name", $prefix, $ipaddr, $get, $opt_p, $netbios, 
              $current_version, $method_send, $modified, $allow, 
              $return_code, $fix, $res->content, $id, $info, 
              $version, $level, $CVE, $description, $proto, $BID, $MS );
          }
          next CHECK;
        }
        if ($current_version =~ /$version/i 
            and !$expect 
            and (!$get or $get =~ /^\/$/) ) {
          print STDERR "$cli_exec ($$): Adding for some unknown reason\n"
            if ($opt_d > 1);
         # print STDERR "2002 - $name - " . md5_hex($res->content) . " - $ipaddr\n";
          add_host("$name", $prefix, $ipaddr, $get, $opt_p, $netbios, 
            $current_version, $method_send, $modified, $allow, 
            $return_code, $fix, $res->content, $id, $info, 
            $version, $level, $CVE, $description, $proto, $BID, $MS );
        } elsif ($opt_d > 1) {
          add_host("DEBUG $name", $prefix, $ipaddr, $get, $opt_p, $netbios,
            $current_version, $method_send, $modified, $allow, 
            $return_code, $fix, $res->content, $id, $info, 
            $version, $level, $CVE, $description, $proto, $BID, $MS );
        }
        add_debug( "$cli_exec ($$): HTML Output: " . $res->error_as_HTML )
          if ($opt_d > 2);
      }
      if ($#iplist == 0 and $vuln{$ipaddr} and !$HTML) {
        print $output;
        $output = '';
      }
    }
    add_debug( "$cli_exec ($$): Looks All Clear\n")
      if ($opt_d);
    if ($opt_v and !$vuln{$ipaddr} and $#iplist == 0) {
      add_host("All Clear", $prefix, $ipaddr, $get, $opt_p, $netbios,
        $current_version, $method_send, $modified, $allow, 
        $return_code, $fix, 'N/A', '', $info, 
        $version, $level, $CVE, $description, $proto, $BID, $MS );
    } elsif ($opt_v and $vuln{$ipaddr}) {
       print "$vuln{$ipaddr} vulns found on $ipaddr\n" if ($opt_d);
    }
    print STDERR "#" x 72 . "\n" if ($opt_d);
    print STDERR "$cli_exec ($$): Scan completed for $ipaddr:$opt_p\n" 
      if ($opt_d);
  ##################################################
  # 
  # No Rules
  #
  ###########
  } else {
    # $opt_e =~ s/([\/\>\<\(\)\^\$\*\@\\\?])/\\$1/g;
    if ($opt_e) {
      $opt_M =$opt_M?$opt_M:'GET';
      if ($opt_s) {
        $req = HTTP::Request->new($opt_M, "https://$ipaddr:$opt_p/$opt_u");
        $prefix = 'https';
      } else {
        $req = HTTP::Request->new($opt_M, "http://$ipaddr:$opt_p/$opt_u");
        $prefix = 'http';
      }
      $request_method = $opt_M;
      print STDERR "$cli_exec ($$): Expicting '$opt_e', using $opt_M\n" 
        if ($opt_d > 1);
    } else {
      $opt_M =$opt_M?$opt_M:'HEAD';
      if ($opt_s) {
        $req = HTTP::Request->new($opt_M, "https://$ipaddr:$opt_p/$opt_u");
        $prefix = 'https';
      } else {
        $req = HTTP::Request->new($opt_M, "http://$ipaddr:$opt_p/$opt_u");
        $prefix = 'http';
      }
      $request_method = $opt_M;
      print STDERR "$cli_exec ($$): Not expecting anything, using $opt_M\n" 
        if ($opt_d > 1);
    }
    if ($opt_C) {
      ($user, $pass) = split('\:', $opt_C);
    }
    print STDERR "$cli_exec ($$): Request: $request_method $prefix://$ipaddr:$opt_p/$opt_u\n" 
      if ($opt_d);
    my $res = $ua->simple_request($req);
    my $return_code = $res->code;
    my $allow = $res->header('Allow');
    my $modified = $res->header('Last-Modified');
    my $current_version =  $res->header("Server");
    my $name = "Found URL /$opt_u" if ($opt_u and !$opt_e);
    $name = "Found $opt_e on Default Page" if ($opt_e and !$opt_u);
    $name = "Found $opt_e on $opt_u" if ($opt_e and $opt_u);
    $name = "HTTP Version" if (!$opt_u and !$opt_e);
    print STDERR "$cli_exec ($$): Request sent to server\n" if ($opt_d > 2);
    if ( ! $res->is_error) {
      # print "$ipaddr, ", $res->header("Refresh"), "\n";
      print STDERR "$cli_exec ($$): Request was successfull\n" 
        if ($opt_d > 1);
      print STDERR "$cli_exec ($$): " . $res->content . "\n\n"
        if ($opt_d > 3);
      $current_version = $res->header("Server"); 
      if (!$current_version or $current_version eq "HTTP/1.0") {
        $current_version = get_server_type($ipaddr, $opt_p, $res->content);
        add_debug( "$cli_exec ($$): Server Type Set to $current_version 2339\n")
          if ($opt_d > 1);
      } else { 
        add_debug( "$cli_exec ($$): Using Server Header $current_version\n")
          if ($opt_d > 1);
        if ($opt_v and !$fingerprinted{$ipaddr}) {
          $expected_version = get_server_type($ipaddr, $opt_p, $res->content, 1);
          add_debug( "$cli_exec ($$): Fingerprint Version $expected_version\n")
            if ($opt_d > 1);
          if ($current_version !~ /$expected_version/) {
            if ($opt_d) {
              add_debug("$cli_exec ($$): WARNING $ipaddr reports $current_version\n");
              add_debug("$cli_exec ($$): WARNING $ipaddr fingerprints as $expected_version\n");
            }
            my($server, $version) = split('/', $current_version);
            my($fserver, $fversion) = split('/', $expected_version);
            $fserver =~ s/\(/\\\(/g 
              if ($fserver =~ /\(/ and $fserver !~ /\)/);
            $server =~ s/\(/\\\(/g
              if ($server =~ /\(/ and $server !~ /\)/);
            if (
                 ($server !~ /$fserver/ and $fserver !~ /$server/) and
                 $server ne $fserver
               ) {
              add_debug( "$cli_exec ($$): Fingerprinted version looks nothing like reported version\n")
                if ($opt_d > 2);
              $current_version .= " [$expected_version]";
            } elsif (!$version) {
              add_debug( "$cli_exec ($$): Reported Version is incomplete\n")
                if ($opt_d > 2);
              $current_version .= " [$expected_version]";
            } else {
              add_debug( "$cli_exec ($$): $server, $version <=> $fserver, $fversion\n")
                if ($opt_d > 2);
            }
          }
        }
      }
      if (
           ( $return_code eq 302 
           or $res->header("Refresh") =~ /URL=/i )
           and $opt_v
         ) {
        my $new_site = $res->header("Location");
        if ($res->header("Refresh") and !$new_site) {
          ($time, $new_site) = split /URL=/i, $res->header("Refresh");
        }
        add_host("Redirected to $new_site", $prefix, $ipaddr, $get, 
          $opt_p, $netbios, $current_version, $method_send, $modified, 
          $allow, $return_code, $fix, $res->content, $id, $info, 
          $version, $level, $CVE, $description, $proto, $BID, $MS );
        print STDERR "#" x 72 . "\n" if ($opt_d);
      } elsif ($return_code eq 307) {
        my $new_site = $res->header("Location");
        add_host("Temporarily Redirected to $new_site", $prefix, $ipaddr, $get, 
          $opt_p, $netbios, $current_version, $method_send, $modified, 
          $allow, $return_code, $fix, $res->content, $id, $info, 
          $version, $level, $CVE, $description, $proto, $BID, $MS );
        print STDERR "#" x 72 . "\n" if ($opt_d);
      } elsif ( $res->header('Content-Type') !~ m<^$contenttype>i ) {
        print STDERR "$cli_exec ($$): Does not return HTML or Text output. 'Content-Type: " 
          . $res->header('Content-Type') . "' Unexpected.\n" if ($opt_d);
      } elsif ( ($res->content =~ m<$opt_e>i 
        or $current_version =~ m<$opt_e>i) and $opt_e ) {
        add_host($name, $prefix, $ipaddr, $get, $opt_p, 
          $netbios, $current_version, $method_send, $modified, $allow, 
          $return_code, $fix, $res->content, $id, $info, 
          $version, $level, $CVE, $description, $proto, $BID, $MS );
        print STDERR "#" x 72 . "\n" if ($opt_d);
      } elsif ( !$opt_e ) {
        print STDERR "$cli_exec ($$): Positive RC without looking for content\n" 
          if ($opt_d);
        add_host($name, $prefix, $ipaddr, $get, $opt_p, $netbios, 
          $current_version, $method_send, $modified, $allow, 
          $return_code, $fix, $res->content, $id, $info, 
          $version, $level, $CVE, $description, $proto, $BID, $MS );
        print STDERR "#" x 72 . "\n" if ($opt_d);
      } else {
        print STDERR "$cli_exec ($$): Did not find what I was looking for ($opt_e)\n"
          if ($opt_d > 1);
      }
    } else {
      $current_version = $res->header("Server"); 
      if (!$current_version or $current_version eq "HTTP/1.0") {
        print STDERR "$cli_exec ($$): looking for version after erroring\n"
          if ($opt_d > 1);
        $current_version = get_server_type($ipaddr, $opt_p, $res->content);
        add_debug( "$cli_exec ($$): Server Type Set to $current_version 2390\n")
          if ($opt_d > 1);
      }
      if ($opt_v and !$fingerprinted{$ipaddr}) {
        $expected_version = get_server_type($ipaddr, $opt_p, $res->content, 1);
        add_debug( "$cli_exec ($$): Version from Fingerprint $expected_version\n")
          if ($opt_d > 1);
        if ($current_version !~ /$expected_version/) {
          if ($opt_d) {
            add_debug("$cli_exec ($$): WARNING $ipaddr reports $current_version\n");
            add_debug("$cli_exec ($$): WARNING $ipaddr fingerprints as $expected_version\n");
          }
          my($server, $version) = split('/', $current_version);
          my($fserver, $fversion) = split('/', $expected_version);
          $fserver =~ s/\(/\\\(/g 
            if ($fserver =~ /\(/ and $fserver !~ /\)/);
          $server =~ s/\(/\\\(/g
            if ($server =~ /\(/ and $server !~ /\)/);
          if (
               ($server !~ /$fserver/ and $fserver !~ /$server/) and
               $server ne $fserver
             ) {
            add_debug( "$cli_exec ($$): Fingerprinted version looks nothing like reported version\n")
              if ($opt_d > 2);
            $current_version .= " [$expected_version]";
          } elsif (!$version) {
            add_debug( "$cli_exec ($$): Reported Version is incomplete\n")
              if ($opt_d > 2);
            $current_version .= " [$expected_version]";
          } else {
            add_debug( "$cli_exec ($$): $server, $version <=> $fserver, $fversion\n")
              if ($opt_d > 2);
          }
        }
      }
      print STDERR "$cli_exec ($$): Request was NOT successfull\n" 
        if ($opt_d > 1);
      if (raw_request($ipaddr, $opt_p, "OPTIONS rtsp://$ipaddr:$opt_p/
RTSP/1.0\r\nCSeq: 1\r\nSession: 1234567890\r\n\r\n") =~ /^RTSP\/1/ 
          and $opt_v) {
        add_host("RTSP Streaming Server", $prefix, $ipaddr, $get, $opt_p, 
          $netbios, $current_version, $method_send, $modified, $allow, 
          $return_code, $fix, $res->content, $id, $info, 
          $version, $level, $CVE, $description, $proto, $BID, $MS );
      } elsif ( $return_code == 401 and $opt_v ) {
        add_host("Forbidden to Access($return_code)", $prefix, $ipaddr, 
          $get, $opt_p, $netbios, $current_version, $method_send, 
          $modified, $allow, $return_code, $fix, $res->content, 
          $id, $info, $version, $level, $CVE, $description, $proto, $BID, $MS );
      } elsif ( $return_code == 403 and $opt_v ) {
        add_host("Unauthorized to Access($return_code)", $prefix, $ipaddr, 
          $get, $opt_p, $netbios, $current_version, $method_send, 
          $modified, $allow, $return_code, $fix, $res->content, 
          $id, $info, $version, $level, $CVE, $description, $proto, $BID, $MS );
      } elsif ( $return_code == 500  and $res->content and $opt_v) {
        $res->content =~ /^500 ([\w\s]+)[\n\r]/;
        my $em =  $1;
        add_host("Error($return_code $em)", $prefix, $ipaddr, 
          $get, $opt_p, $netbios, $current_version, $method_send, 
          $modified, $allow, $return_code, $fix, $res->content, 
          $id, $info, $version, $level, $CVE, $description, $proto, $BID, $MS );
      } elsif ( ! $opt_e and ! $opt_u and $current_version) {
        add_host($name, $prefix, $ipaddr, $get, $opt_p, $netbios, 
          $current_version, $method_send, $modified, $allow, 
          $return_code, $fix, $res->content, $id, $info, 
          $version, $level, $CVE, $description, $proto, $BID, $MS );
      } elsif ($res->content =~ m<$opt_e>i and $opt_M != 'GET') {
        add_host("Found $opt_e using $opt_M", $prefix, $ipaddr, $get, 
          $opt_p, $netbios, $current_version, $method_send, $modified, 
          $allow, $return_code, $fix, $res->content, $id, $info, 
          $version, $level, $CVE, $description, $proto, $BID, $MS );
      } elsif ($opt_d > 1) {
        add_host("$name (DEBUG)", $prefix, $ipaddr, $get, $opt_p, $netbios, 
          $current_version, $method_send, $modified, $allow, 
          $return_code, $fix, $res->content, $id, $info, 
          $version, $level, $CVE, $description, $proto, $BID, $MS );
        print STDERR "#" x 72 . "\n" if ($opt_d);
      } elsif (!$opt_e and !$opt_u) {
        print STDERR "$cli_exec ($$): error classifying return code $return_code\n" 
          if ($opt_d > 1);
        add_host("Port Open, No Response from Server", $prefix, $ipaddr, $get,
          $opt_p, $netbios, "N/A", $method_send, $modified, $allow, 
          $return_code, $fix, $res->content, $id, $info, 
          $version, $level, $CVE, $description, $proto, $BID, $MS );
        print STDERR "#" x 72 . "\n" if ($opt_d);
      }
      print STDERR "$cli_exec ($$): ERROR HTML Output: " . $res->error_as_HTML 
        if ($opt_d > 2);
    }
  }
  print STDERR "$cli_exec ($$): Scan completed for $ipaddr:$opt_p \@2542 \n" 
    if ($opt_d);
}


sub startTag {
  my ($tag, $attrHash) = @_;
  $content{$tag} = $attrHash;
  $c_tag = $tag;
  print STDERR "$cli_exec ($$): startTag Parse HTML $tag\n" 
    if ($opt_d > 8);
}

sub endTag {
  my $tag = shift;
  $c_tag = 'text';
  print STDERR "$cli_exec ($$): endTag Parse HTML $tag\n" 
    if ($opt_d > 8);
}

sub textElem {
  my $text = shift;
  $content{$c_tag}{text} .= $text;
  print STDERR "$cli_exec ($$): textElem Parse HTML $text\n" 
    if ($opt_d > 8);
}

sub scan_sql {
  $/ = CRLF;
  my ($ip,$port,%rules) = @_;
  $0 = "sql-scanning $ip:$port";
  print STDERR "$cli_exec ($$): SQL_Scan $ip:$port\n" if ($opt_d > 1);
  my $senddata1 = "\x02";
  my $senddata2 = "\x0a";
  my $sqldata1;
  my $sqldata2;
  my %data;
  eval {
    local $SIG{__WARN__};
    local $SIG{'__DIE__'} = "DEFAULT";
    local $SIG{'ALRM'} = sub { die "Timeout Alarm" };
    print STDERR "$cli_exec ($$): Creating Socket $ip\n" if ($opt_d > 2);
    alarm($opt_t);
    socket(SOCK, AF_INET, SOCK_DGRAM, getprotobyname('udp') )
      or die "Error: $!";
    print STDERR "$cli_exec ($$): Creating \$dest_addr\n" if ($opt_d > 2);
    my $dest_addr = sockaddr_in('1434', inet_aton($ip) );
    print STDERR "$cli_exec ($$): Sending Request $ip\n" if ($opt_d > 2);
    send(SOCK,$senddata1,0,$dest_addr)
      or die "Error: $!";
    print STDERR "$cli_exec ($$): Receiving Data $ip\n" if ($opt_d > 2);
    recv(SOCK,$sqldata1,256,0)
      or die "Error: $!";
    close (SOCK);
    alarm(0);
  };
  if ($sqldata1 and $@ !~ /^Error/) {
    print STDERR "$cli_exec ($$): Scan Data returned $sqldata1\n"
      if ($opt_d > 2);
    %data = split ';', $sqldata1;
  }
  if ($opt_v and !%rules and %data) {
    my $content = '';
    for (keys %data) {
      $content .= "$_ - $data{$_}\n";
    }
    $current_version = "SQL/$data{'Version'}";
    add_host("MSSQL Version", '', $ip, '', $port, 
      $netbios, $current_version, $method_send, $modified, $allow, 
      $return_code, $fix, $content, $id, $info, 
      $version, $level, $CVE, $description, 'udp', $BID, $MS);
    print STDERR "$cli_exec ($$): SQL Scan completed for $ipaddr:$opt_p - \n"
      if ($opt_d);
    return;
  }
  if (%data) {
    eval {
      local $SIG{__WARN__};
      local $SIG{'__DIE__'} = "DEFAULT";
      local $SIG{'ALRM'} = sub { die "Timeout Alarm" };
      print STDERR "$cli_exec ($$): Creating Socket $ip\n" if ($opt_d > 2);
      alarm($opt_t);
      socket(SOCK, AF_INET, SOCK_DGRAM, getprotobyname('udp') )
        or die "Error: $!";
      print STDERR "$cli_exec ($$): Creating \$dest_addr\n" if ($opt_d > 2);
      my $dest_addr = sockaddr_in('1434', inet_aton($ip) );
      print STDERR "$cli_exec ($$): Sending Request $ip\n" if ($opt_d > 2);
      send(SOCK,$senddata2,0,$dest_addr)
        or die "Error: $!";
      print STDERR "$cli_exec ($$): Receiving Data $ip\n" if ($opt_d > 2);
      recv(SOCK,$sqldata2,256,0)
        or die "Error: $!";
      close (SOCK);
      alarm(0);
    };
    if ($sqldata2 and $@ !~ /^Error/) {
      print STDERR "$cli_exec ($$): Scan Data returned $sqldata2\n"
        if ($opt_d > 2);
      if ($sqldata2 eq $senddata2) {
        print STDERR "$cli_exec ($$): Vulnerable Server $ip\n" if ($opt_d > 2);
        $data{Vulnerable} = 'YES';
      }
    } else {
      print STDERR "$cli_exec ($$): ERROR: $@\n"
        if ($opt_d > 2);
    }
  }
  if ($data{Vulnerable} eq 'YES') {
    my $content = '';
    for (keys %data) {
      $content .= "$_ - $data{$_}\n";
    }
    $current_version = "SQL/$data{'Version'}";
    add_host("Vulnerable SQL (Slapper Worm)", '', $ip, '', $port, 
      $netbios, $current_version, $method_send, $modified, $allow, 
      $return_code, $fix, $content, $id, $info, 
      $version, $level, $CVE, $description, 'udp', $BID, $MS);
  } 
  print STDERR "$cli_exec ($$): SQL Scan completed for $ipaddr:$opt_p - \n"
    if ($opt_d);
}

sub scan_ftp {
  my ($ipaddr, $opt_p, %rules) =@_;
  my $current_version;
  my $prefix = 'ftp';
  $0 = "ftp-scanning $ipaddr:$opt_p";
  print STDERR "$cli_exec ($$): Scanning $ipaddr:$opt_p\n" 
    if ($opt_d);
  my @data = split /\n/, raw_request($ipaddr, $opt_p,"QUIT");
  if (@data) {
    $data[0] =~ /^220-?(.*)[\r]$/;
    $current_version = $1;
    if (!%rules) {
      add_host("FTP Version", $prefix, $ipaddr, $get, 
        $opt_p, $netbios, $current_version, $method_send, $modified, 
        $allow, $return_code, $fix, '', $id, $info, 
        $version, $level, $CVE, $description, $proto, $BID, $MS );
      print STDERR "$cli_exec ($$): FTP Scan completed for $ipaddr:$opt_p - \n"
        if ($opt_d);
      return;
    }
  }
  print STDERR "$cli_exec ($$): Connecting to $ipaddr via FTP\n" 
    if ($opt_d);
  my $ftp = Net::FTP->new($ipaddr,
                       Debug => 0,
                       Timeout => $timeout);
  if ($ftp) {
    print STDERR "$cli_exec ($$): Connected to $ipaddr via FTP\n" 
      if ($opt_d);
    my $login = $ftp->login("anonymous",'-anonymous@');
    if ($login) {
      print STDERR "$cli_exec ($$): logged into $ipaddr via FTP anonymously\n" 
        if ($opt_d);
      if ($ftp->mkdir("unspecific")) {
        $ftp->rmdir("unspecific");
        my $level = 'HIGH';
        my $id = '901';
        my $info = 'http://online.securityfocus.com/cgi-bin/sfonline/vulns.pl?keyword=FTP';
        my $description = 'Allowing anonymous FTP opens many dangers, and' .
         ' while not truly a vulnerability, it can make you vulnerable to' .
         '  known holes.  These include DoS attacks by filling available' .
         ' disk space, using your FTP server for "WAREZ", and other anoyances.';
        my $fix = 'Disable writable directories. Disable anonymous FTP if' .
         ' possible.  Use HTTP for anonymous file transfer. Use SCP with' . 
         ' user/pass for file transfers.';
        my $CVE = 'CAN-1999-0497';
        add_host("Anonymous FTP writable", $prefix, $ipaddr, $get, 
          $opt_p, $netbios, $current_version, $method_send, $modified, 
          $allow, $return_code, $fix, $ftp->ls(), $id, $info, 
          $version, $level, $CVE, $description, $proto, $BID, $MS );
      } else {
        my $wrt_dir;
        my @dir = $ftp->dir();
        DIR: for my $dir (@dir) {
          next if ($dir !~ /^d/);
          @dir_data = split ' ', $dir;
          if ($ftp->cwd($dir_data[-1])) {
            next DIR;
          } else {
            if ($ftp->mkdir("unspecific")) {
              $ftp->rmdir("unspecific");
              $wrt_dir = $dir_data[-1];
              last DIR;
            } else {
              $ftp->cwd();
            }
          }
        }
        if ($wrt_dir) {
          my $level = 'HIGH';
          my $id = '901';
          my $info = 'http://online.securityfocus.com/cgi-bin/sfonline/vulns.pl?keyword=FTP';
          my $description = 'Allowing anonymous FTP opens many dangers,' .
           ' and while not truly a vulnerability, it can make you vulnerable' .
           ' to known holes.  These include DoS attacks by filling available' . 
           ' disk space, using your FTP server for "WAREZ", and other anoyances.';
          my $fix = 'Disable writable directories. Disable anonymous FTP' . 
           ' if possible.  Use HTTP for anonymous file transfer. Use SCP' .
           ' with user/pass for file transfers.';
          my $CVE = 'CAN-1999-0497';
          add_host("Anonymous FTP writable directory $wrt_dir", $prefix, 
            $ipaddr, $get, $opt_p, $netbios, $current_version, $method_send, 
            $modified, $allow, $return_code, $fix, $ftp->ls(), $id, $info, 
            $version, $level, $CVE, $description, $proto, $BID, $MS );
        } else {
          my $level = 'Medium';
          my $id = '902';
          my $info = 'http://online.securityfocus.com/cgi-bin/sfonline/vulns.pl?keyword=FTP';
          my $description = 'Allowing anonymous FTP opens many dangers,' .
           ' and while not truly a vulnerability, it can make you vulnerable' . 
           ' to known holes.';
          my $fix = 'Disable anonymous FTP if possible.  Use HTTP for' .
           '  anonymous file transfer.';
          my $CVE = 'CAN-1999-0497';
          my $content = join ("\n", $ftp->ls());
          add_host("Anonymous FTP enabled", $prefix, $ipaddr, $get, 
            $opt_p, $netbios, $current_version, $method_send, $modified, 
            $allow, $return_code, $fix, $content, $id, $info, 
            $version, $level, $CVE, $description, $proto, $BID, $MS );
        }
      }
    } else {
      # add_host("FTP enabled w/ User/Pass", $prefix, $ipaddr, $get, 
        # $opt_p, $netbios, $current_version, $method_send, $modified, 
        # $allow, $return_code, $fix, 'N/A', $id, $info, 
        # $version, $level, $CVE, $description, $proto, $BID, $MS );
    }
    $ftp->quit;
  } else {
    # add_host("Port Open/Unable to Connect", $prefix, $ipaddr, $get, 
      # $opt_p, $netbios, $data, $method_send, $modified, 
      # $allow, $return_code, $fix, 'N/A', $id, $info, 
      # $version, $level, $CVE, $description, $proto, $BID, $MS );
  }
  print STDERR "$cli_exec ($$): FTP Scan completed for $ipaddr:$opt_p - \n"
    if ($opt_d);
}



sub scan_smtp {
  my ($ipaddr, $opt_p, %rules) =@_;
  my $current_version;
  $0 = "smtp-scanning $ipaddr:$opt_p";
  print STDERR "$cli_exec ($$): Scanning $ipaddr:$opt_p\n" 
    if ($opt_d);
  my @data = split /\n/, raw_request($ipaddr, $opt_p,"QUIT");
  if (@data) {
    print STDERR "$cli_exec ($$): SMTP line 1 returned $data[0] \n" 
      if ($opt_d > 2);
    $data[0] =~ /^220-?(.*)[\r]$/;
    $current_version = $1;
    print STDERR "$cli_exec ($$): SMTP RAW Version $current_version\n" 
      if ($opt_d > 2);
    $current_version =~ s/\n|\r/ /g;
    if ($current_version) {
      $current_version =  clean_banner($current_version, 'smtp');
    }
    print STDERR "$cli_exec ($$): got $current_version on SMTP scan\n" 
      if ($opt_d > 1);
    if (!%rules) {
      add_host("SMTP Version", $prefix, $ipaddr, $get, 
        $opt_p, $netbios, $current_version, $method_send, $modified, 
        $allow, $return_code, $fix, join("\n", @data), $id, $info, 
        $version, $level, $CVE, $description, $proto, $BID, $MS );
      print STDERR "$cli_exec ($$): SMTP Scan completed for $ipaddr:$opt_p - \n"
        if ($opt_d);
      return;
    }
  }
  $smtp = Net::SMTP->new($ipaddr, 
                         Timeout => $opt_t,
                         Hello => 'Unspecific.com',
                         Debug => $opt_d,
                         );
  if ($smtp) {
    $domain =  $smtp->domain,"\n";
    if (!$current_version) {
      $current_version =  clean_banner($smtp->banner, 'smtp');
      print STDERR "$cli_exec ($$): Setting $current_version from SMTP->BANNER\n" 
        if ($opt_d > 1);
    }
    if ($exp_rc = $smtp->expand('root')) {
      chomp $exp_rc;
      add_host("SMTP EXPN Enabled($exp_rc)", $prefix, $ipaddr, $get, 
        $opt_p, $netbios, $current_version, $method_send, $modified, 
        $allow, $return_code, $fix, $exp_rc, $id, $info, 
        $version, $level, $CVE, $description, $proto, $BID, $MS );
    }
    if ($vrfy_rc = $smtp->verify('root')) {
      chomp $vrfy_rc;
      add_host("SMTP VRFY Enabled for $domain", $prefix, $ipaddr, $get, 
        $opt_p, $netbios, $current_version, $method_send, $modified, 
        $allow, $return_code, $fix, $vrfy_rc, $id, $info, 
        $version, $level, $CVE, $description, $proto, $BID, $MS );
    }
    if ($mail_rc = $smtp->mail('scanner@unspecifi.com')) {
      print STDERR "$cli_exec ($$): Got $mail_rc from SMTP->MAIL\n" 
        if ($opt_d > 1);
      return;
    }
    if ($to_rc = $smtp->to($relay_mail)) {
      print STDERR "$cli_exec ($$): Got $to_rc from SMTP->TO\n" 
        if ($opt_d > 1);
      return;
    } else {
      add_host("Relaying Enabled for $domain", $prefix, $ipaddr, $get, 
        $opt_p, $netbios, $current_version, $method_send, $modified, 
        $allow, $return_code, $fix, $current_version, $id, $info, 
        $version, $level, $CVE, $description, $proto, $BID, $MS );
    }
    $smtp->data();
    $smtp->datasend("To: $relay_mail\n");
    $smtp->datasend("Subject: Relay Testing\n\n");
    $smtp->datasend("Testing relay from $ENV{HOSTNAME}\n");
    $smtp->datasend("Relay Successful for $ipaddr\n");
    $smtp->dataend();
    $smtp->quit;
  }
  print STDERR "$cli_exec ($$): SMTP Scan completed for $ipaddr:$opt_p - \n"
    if ($opt_d);
}

sub clean_banner {
  my ($banner, $type) = @_;
  if ($type eq 'smtp') {
    @version_data =  split(' ', $banner);
    if ($version_data[1] eq 'Microsoft' and $version_data[2] ne 'SMTP') {
      print STDERR "$cli_exec ($$): Found Microsoft ESMTP Server\n" 
        if ($opt_d > 1);
      $current_version = "Microsoft-ESMTP/$version_data[6]";
    } elsif ($version_data[1] eq 'Microsoft' and $version_data[2] eq 'SMTP') {
      print STDERR "$cli_exec ($$): Found Microsoft SMTP Server\n" 
        if ($opt_d > 1);
      $current_version = "Microsoft-SMTP/$version_data[13]";
    } elsif ($version_data[2] eq 'Sendmail') {
      print STDERR "$cli_exec ($$): Found Sendmail SMTP Server\n" 
        if ($opt_d > 1);
      $current_version = "Sendmail/$version_data[3]";
    } elsif ($version_data[4] eq '(Lotus') {
      print STDERR "$cli_exec ($$): Found Lotus Domino ESMTP Server\n" 
        if ($opt_d > 1);
      chop $version_data[7];
      $current_version = "LotusDomino/$version_data[7]";
    } elsif ($version_data[3] eq '(Post.Office') {
      print STDERR "$cli_exec ($$): Found Post.Office SMTP Server\n" 
        if ($opt_d > 1);
      $current_version = "Post.Office/$version_data[4]-$version_data[6]";
    } elsif ($version_data[2] eq 'Postfix') {
      print STDERR "$cli_exec ($$): Found Postfix SMTP Server\n" 
        if ($opt_d > 1);
      if ($version_data[3] =~ /^\(Postfix/) {
        $current_version = "$version_data[3]";
        $current_version =~ s/\(|\)//g;
      } elsif ($version_data[3] eq 'on') {
        $current_version = "Postfix on $version_data[4] $version_data[5] $version_data[6]";
      } else {
        $current_version = "Postfix";
      }
    } else {
      print STDERR "$cli_exec ($$): Not sure what SMTP server we found...\n" 
        if ($opt_d > 1);
      $current_version = join(' ', @version_data);
    }
  }
  return $current_version;
}

sub add_debug {
  my ($message) = @_;
  if ($HTML) {
    $message =~ s/</&lt;/g;
    $output .= "$message<br>";
  } else {
    # $output .= $message;
    print STDERR "$message";
  }
}


sub swrite {
  my ($format,@strings) = @_;
  $^A = "";
  formline($format,@strings);
  return $^A;
}

sub ALARM {
  return;
}


sub gen_html_out {
  my ($class) = @_;
  $level = $level?$level:'Unspecified';
  $version = $version?$version:'Multiple Versions Effected';
  my @CVE =  split(',',$CVE);
  for my $CVE (@CVE) {
    $CVE =~ s/\s//g;
    if ($CVE =~ /^CA\-/) { 
      $CVE_URL .= "<b>CERT Advisory</b>: <a href='http://www.cert.org/advisories/$CVE.html' target='_blank'>$CVE</a><br>\n";
    } elsif ($CVE =~ /^CA/) {
      $CVE_URL .= "<b>CVE Candidate</b>: <a href='http://icat.nist.gov/icat.cfm?cvename=$CVE' target='_blank'>$CVE</a><br>\n";
    } elsif ($CVE) {
      $CVE_URL .= "<b>CVE Information</b>: <a href='http://icat.nist.gov/icat.cfm?cvename=$CVE' target='_blank'>$CVE</a><br>\n";
    }
  }
  my @BID =  split(',',$BID);
  for my $BID (@BID) {
    $BID =~ s/\s//g;
    if ($BID) { 
      $BID_URL .= "<b>BubtraqID</b>: <a href='http://online.securityfocus.com/bid/$BID' target='_blank'>$BID</a><br>\n";
    }
  }
  my @MS =  split(',',$MS);
  for my $MS (@MS) {
    $MS =~ s/\s//g;
    if ($MS) { 
      $MS_URL .= "<b>Microsoft</b>: <a href='http://www.microsoft.com/technet/security/bulletin/$MS.mspx' target='_blank'>$MS</a><br>\n";
    }
  }
  if (length $info > 60) {
    $info_name = substr($info, 0, 60) . '...';
  } else {
    $info_name = $info;
  }
  $description = swrite(<<'END', "$description");
    ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ~~
END
  my $output = <<_EOF_;
<div class="$class" id="id$div_id">
<table width=400><tr><td width=395><font size=+1><b>$name</b></font><br>
$description<br><br>
Severity: <b>$level</b><br>
Version Effected: <b>$version</b><br>
Fix: <b>$fix</b><br>
<a href="$info" target='_blank'>$info_name</a><br>
$CVE_URL $BID_URL $MS_URL
</td><td align=right valign=top><a href="javascript:hideHelp();" class="helpClose">X</a></td></tr></table>
</div>
_EOF_
  return $output;
}
