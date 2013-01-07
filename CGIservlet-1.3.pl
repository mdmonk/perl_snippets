#! /usr/bin/perl
#
# Put the full path to perl5.002 on the first line, or a symbolic link to perl in 
# the startup directory.
#
# CGIservlet: 
#         A HTTPd "connector" for running CGI scripts on unix systems as WWW
#         accessible Web sites. The servlet starts a true HTTP daemon that channels 
#             HTTP requests to forked daughter processes. CGIservlet.pl is NOT a
#         full fledged server. Moreover, this servlet is definitely NOT intended 
#         as a replacement of a real server (e.g., Apache). It's design goal was
#         SIMPLICITY, and not mileage. 
#         
#         Note that a HTTP server can be accessed on your local machine WITHOUT 
#         internet access (but WITH a DNS?): 
#         use "http://localhost[:port]/[path]" or "http://127.0.0.1[:port]/[path]" 
#         as the URL. It is also easy to restrict access to the servlet to localhost
#         users (i.e., the computer running the servlet).
#         
#         Suggested uses:
#         - A testbed for CGI-scripts and document-trees outside the primary server.
#           When developing new scripts and services, you don't want to mess up your
#           current Web-site. CGIservlet is an easy way to start a temporary (private) 
#           server. CGIservlet allows to test separate HTTP server components, e.g., 
#           user authentication, in isolation.
#           
#         - A special purpose temporary server (WWW everywhere/anytime). 
#           We run identification and other experiments over the inter-/intra-net using 
#           CGI-scripts. This means a lot of development and changes and only little
#           actual run-time. The people doing this do not want "scripting" access to our 
#           departmental server with all its restrictions and security. So we need a 
#           small, lightweigth, easy-to-configure server that can be run by each
#           investigator on her own account (and risk). 
#          
#         - Interactive WWW presentations.
#           Not everyone is content with the features of "standard" office presentation 
#           software. HTML and its associated browsers are an alternative (especially 
#           under Linux). However, you need a server to realize the full interactive 
#           nature of the WWW. CGIservlet with the necessary scripts can be run from 
#           a floppie (a Web server in 100 kB). The CGIservlet can actually run a 
#           (small) web site from RAM, without disk access (if you DO NOT use the 
#           2>pid.log redirection on startup). 
#           With the "localhost" or "127.0.0.1" id in your browser you can use the
#           servlet standalone.
#           
#         When the servlet is started with the -r option, only requests from "localhost" 
#         or "127.0.0.1" are accepted (default) or from addresses indicated after the
#         -r switch.
#         
#         Running demo's and more information can be found at 
#         http://www.fon.hum.uva.nl/rob/OSS/OSS.html
#
#
############################################################################
#
# Changes (document ALL changes with date, name and email here):
#
# 15 Jan 2002 - Version 1.3
# 19 Oct 2001 - Included browsing of directories and a new -s
#               security switch. With security toggled of
#               directories can be browsed and all mime-types
#               are served, either as 'text/plain' or as
#               'application/octed-stream'.
# 18 May 2001 - Added some HTTP header lines.
# 13 Jun 2000 - Included the possibility to add POST request
#               to GET query-strings (and change the request
#               method). The -l ($Maxlength) maximum length
#               option now covers POST requests too.
#  8 Dec 1999 - Included hooks for compression when running from RAM. 
#  2 Dec 1999 - Autoflush enabled. 
#  2 Dec 1999 - Allow running a Web Site from RAM. 
#  2 Dec 1999 - Changed the behavior of CGIservletSETUP. CGIservlet
#               will eval ALL setup files, the one in the CGIscriptor
#               subdirectory (if any) AND the one in the current 
#               directory. (also added a close(SETUP) command)
# 26 Nov 1999 - Added some minimal security for 'automatic', out of
#                       the box installation. 
# 26 Nov 1999 - Made the text/osshell mime-type functional (i.e., 
#                       without any scripts, implement a dynamic web server)
#               Linited to '.cgi' extension.
# 26 Nov 1999 - Added aliasing of URL paths, both one-to-one lookups
#                and full regular expression, i.e., $Path =~ s/.../.../g 
#                replace commands
# 28 Sep 1999 - Made all client supplied HTTP parameter names lowercase
#                       to handle inconsistencies in case use.
# 29 Jul 1999 - Allowed for a SETUP configuration file 'CGIservletSETUP.pl'.
#               Use $beginarg from the 'CGIscriptor/' directory if it exists.
#               (Rob.van.Son@hum.uva.nl)
#          
#
############################################################################
#
# Known bugs
#
# 23 Mar 2000 - An odd server side network error is reported by Netscape
#               when a Post is initiated from a Javascript Submit of a 
#               <FORM>. This was found on Red Hat 6.1 Linux with perl 5.00503,
#               5.00503 and 5.6.0. But not on IRIX or Red Hat 5.0.
#
############################################################################
# 
#         
# Inner workings:
#         Whenever an HTTP request is received, the specified CGI script is 
#         started inside a child process as if it was inside a real server (e.g., 
#         Apache). The evironment variables are set more or less as in Apache. 
#         Note that CGIservlet only uses a SINGLE script for ALL requests.
#         No attemps for security are made, it is the script's responsibility to 
#         check access rights and the validity of the request.
#         When no scripts are given, CGIservlet runs as a bare bone WWW server
#         configurable to execute scripts (the default setting is as a
#         STATIC server).
#
# Author and copyright (c) : 
#         Rob van Son 
#         email:
#         Rob.van.Son@hum.uva.nl 
#         rob.van.son@workmail.com (more private)
#         mail:
#         Institute of Phonetic Sciences
#         University of Amsterdam
#         Herengracht 338
#         NL-1016CG Amsterdam
#         The Netherlands
#         tel +31 205252183
#         fax +31 205252197
#         
#         copying freely from the mhttpd server by Jerry LeVan (levan@eagle.eku.edu)
# Date:   January 15, 2002
# Version:1.300
# Env:    Perl 5.002
#
#          
################################################################################
#                                                                              #
#          LICENCE                                                             #
#                                                                              #
#          This program is free software; you can redistribute it and/or       #
#          modify it under the terms of the GNU General Public License         #
#          as published by the Free Software Foundation; either version 2      #
#          of the License, or (at your option) any later version.              #
#                                                                              #
#          This program is distributed in the hope that it will be useful,     #
#          but WITHOUT ANY WARRANTY; without even the implied warranty of      #
#          MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       #
#          GNU General Public License for more details.                        #
#                                                                              #
#          You should have received a copy of the GNU General Public License   #
#          along with this program; if not, write to the Free Software         #
#          Foundation, Inc., 59 Temple Place - Suite 330,                      #
#          Boston, MA  02111-1307, USA.                                        #
#                                                                              #
################################################################################
#
# Note:   CGIservlet.pl was directly inspired by Jerry LeVan's 
#         (levan@eagle.eku.edu) simple mhttpd server which again was 
#         inspired by work of others. CGIservlet is used as a bare bones 
#         socket server for a single CGI script at a time.
#
# Use:    CGIservlet.pl -<switch> <argument> 2>pid.log &     (sh/bash)
#         CGIservlet.pl -<switch> <argument> >&pid.log &     (csh)
#         
#         The servlet prints out pid and port number on STDERR. It is
#             adviced to store these in a separate file (this will become the
#         error log). 
#             NOTE: When running CGIservlet from a Memmory Image (i.e. RAM), 
#         do NOT redirect the error output to a file, but use something
#         like MAILTO!
#
# Stop:   sh pid.log                    (kills the server process)
#         
#         The first line in the file that receives STDERR output is a command
#         to stop CGIservlet.
#                 
#         examples:
#         CGIservlet.pl -p 2345 -d /cgi-bin/CGIscriptor.pl -t /WWW 2>pid.log &
#         CGIservlet.pl -p 8080 -b 'require "CGIscriptor.pl";' -t $PWD -e \
#         'Handle_Request();' 2>pid.log &
#         
#         The following example settings implement a static WWW server using 'cat'
#         (and prohibiting Queries):
#         -p 8008 
#         -t `pwd` 
#         -b ''
#         -e 
# '$ENV{QUERY_STRING}="";$ENV{PATH_INFO}=~/\.([\w]+)$/; "Content-type: ".$mimeType{uc($1)}."\n\n";'
#         -d 'cat -u -s'
#         -w '/index.html'
#         -c 32
#         -l 512
#         
#         This is identical to the (static) behaviour of CGIservlet when 
#         -e '' -d '' -x '' is used.
#         The CGIservlet command should be run from the intended server-root directory.
# 
#         Another setting will use a package 'CGIscriptor.pl' with a function
#         'HandleRequest()' to implement an interactive WWW server with inline 
#         Perl scripting:
#         -p 8080 
#         -t `pwd` 
#         -b 'require "CGIscriptor.pl";' 
#         -e 'HandleRequest();'
#         -d ''
#         -w '/index.html'
#         -c 32
#         -l 32767
#         
#         Look below or in the CGIservletSETUP.pl file for the current default 
#         settings.
#
#
# ###############################################################################
# 
#         There are many switches to tailor the workings of CGIservlet.pl.
#         Some are fairly esoteric and you should only look for them if you
#         need something special urgently. When building a Web site, 
#         the specific options you need will "suggest" themselves (e.g., port
#         number, script, or server-root directory). Most default settings 
#         should work fine. 
#
#         You can add your own configuration in a file called
#         'CGIservletSETUP.pl'. This file will be executed ("eval"-ed) 
#         after the default setup, but before the command line options take 
#         effect. CGIservlet looks for the SETUP file in the startup directory
#         and in the CGIscriptor subdirectory.
#         (Note that the $beginarg variable is evaluated AFTER the setup file). 
#         
#         In any case, it is best to change the default settings instead of
#         using the option switches. All defaults are put in a single block.
#          
#         switches and arguments:
#         Realy important
#         -p[ort] port number 
#          For example -p 2345
#          Obviously the port CGIservlet listenes to. Suggested Default: -p 8008
#          
#         -a[lias] Alias1 RealURL1 ...
#          For example -a '/Stimulus.aifc' '/catAIFC.xmr'
#          Replaces the given Alias URL path by its real URL path. Accepts full 
#          regular expressions too (identified by NON-URL characters). 
#          That is, on each request it performs (in order):
#          if($AliasTranslation{$Path})
#          { 
#              $Path = $AliasTranslation{$Path};
#          }
#          elsif(@RegAliasTranslation)
#          {  
#             my $i;
#             for($i=0; $i<scalar(@RegAliasTranslation); ++$i)
#             { 
#                 my $Alias   = $RegAliasTranslation[$i];
#                 my $RealURL = $RegURLTranslation[$i];
#                 last if ($Path =~ s#$Alias#$RealURL#g);
#             };
#          };
#          The effects can be quite drastic, so be 
#          carefull. Note also, that entering many Regular Expression
#          aliases could slow down your servlet. Checking stops after 
#          the first match.
#          Full regular expression alias translations are done in the
#          order given! They are recognized as Aliases containing 
#          regexp's (i.e., non-URL) operator characters like '^' and
#          '$'.
#          Note: The command line is NOT a good place for entering
#          Aliases, change the code below or add aliases to 
#          CGIservletSETUP.pl.
#          
#         Script related
#         -b[egin] perl commands
#          For example -b 'require "CGIscriptor.pl";' or
#          'require "/WWW/cgi-bin/XMLelement.pl";'
#          Perl commands evaluated at server startup
#          
#         -d[o] perl script file
#          For example -d '/WWW/cgi-bin/CGIscriptor.pl'
#          The actual CGI-script started as a perl {do "scriptfile"} command.
#              The PATH_INFO and the QUERY are pushed on @ARGV.
#          
#         -x shell command
#         -qx shell command
#         -exec shell command
#          OS shell script or command, e.g., -x 'CGIscriptor.pl' or 
#          -x '/WWW/cgi-bin/my-script'
#          The actual CGI-script started as `my-script \'$Path\' \'$QueryString\'`. 
#              -qx and -exec[ute] are aliases of -x. For security reasons, Paths or
#              queries containing '-quotes are rejected.
#          
#         -e[val] perl commands
#          For example -e 'Handle_Request();'   
#          The argument is evaluated as perl code. The actual CGI-script 
#          can be loaded once with -b 'require module.pm' and you only have to 
#          call the central function(s).
#          
#         WWW-tree related
#         -t[extroot] path
#          For example -t "$PWD" or -t "/WWW/documents"
#          The root of the server hierachy. Defaults to the working directory
#          at startup time (`pwd`)  
#          
#         -w[elcome] filepath
#          For example -w "/index.html"   (default)
#          The default welcome page used when no path is entered. Note that
#          this path can point to anything (or nothing real at all).
#         
#         Security related
#         The following arguments supply some rudimentary security. It is the
#         responsibility of the script to ensure that the requests are indeed
#         "legal".
#
#         -c[hildren] maximum child processes
#          For example -c 32
#          The maximum number of subprocesses started. If there are more requests,
#          the oldest requests are "killed". This should take care of "zombie"
#          processes and server overloading. Note that new requests will be 
#          serviced irrespective of the success of killing it's older siblings.
#          
#         -l[ength] maximum length of HTTP request in bytes
#          For example -l 32768 
#          This prevents overloading the server with enormous queries. Reading of
#          requests simply stops when this limit is reached. This DOES affect 
#          POST requests.  If the combined length of the COMPLETE HTTP request,
#          including headers, exceeds this limit, the whole request is dropped.
#          
#         -r[estrict] [Remote-address [Remote-host]]
#          For example -r 127.0.0.1          (default of -r)
#          A space separated list of client IP addresses and/or domain names that
#          should be serviced. Default, i.e., '-r' without any addresses or domain
#          names, is the localhost IP address '127.0.0.1'.
#          When using CGIservlet for local purposes only (e.g., development or a 
#          presentation), it would be unsafe to allow others to access the servlet.
#          If -r is used (or the corresponding @RemoteAddr or @RemoteHost lists are
#          filled in the code below), all requests from clients whose Remote-address
#          or Remote-host do not match the indicated addresses will be rejected.
#          Partial addresses and domain names are allowed. Matching is done according 
#          to Remote-addr =~ /^\Q$pattern\E/ (front to back) and 
#          Remote-host =~ /\Q$pattern\E$/ (back to front)
#
#         -s[ecure] 
#          No arguments.
#          A toggle switch that blocks all access to files with undefined
#          mime-types (or to serve ascii files as "text/plain"), and blocking directory 
#          browsing. Defaults to blocking what is not explicitely allowed.
#
#         -m[emory]
#          No arguments.
#          Reads complete Web site into memory and runs from this image.
#          Set $UseRAMimage = 1; to activate memory-only running.
#          Under certain circumstance, this can improve security.
#          Note, however, that running osshellscripts from this image 
#          makes any "security" related claims very shaky.
#          
#         Speedup
#         -n[oname]
#          No arguments. 
#          Retrieving the domain name of the Client (i.e., Remote-host) is a
#          very slow process and normally useless. To skip it, enter this 
#          option. Note that you cannot use '-r Remote-host' anymore after 
#          you enter -n, only IP addresses will work.
#
#     Configuration with the CGIservletSETUP.pl file
#
#     You can add your own configuration in a file
#     called 'CGIservletSETUP.pl'. This file will be executed ("eval"-ed) 
#     after the default setup, but before the command line options take 
#     effect. CGIservlet looks for the SETUP file in the startup directory
#     and in the CGIservlet and CGIscriptor subdirectories.
#     (Note that the $beginarg variable is evaluated even later).
#
#         Changing POST to GET requests
#
#         CGIservlet normally only handles requests with the GET method. Processing
#         the input from POST requests is left to the reading application. POST 
#         requests add some extra complexity to processing requests. Sometimes,
#         the reading application doesn't handle POST requests. CGIservlet
#         already has to manage the HTTP request. Therefore, it can easily
#         handle the POST request. If the variable $POSTtoGET is set to any
#         non-false value, the content of whole POST request is added to the
#         QUERY_STRING environment variable (preceeded by a '&' if necessary).
#         The content-length is set to 0. If $POSTtoGET equals 'GET', the method 
#         will also be changed to 'GET'.

#          remarks:
#          All of the arguments of -d, -e, and -x are processed sequentially
#          in this order. This might not be what you want so you should be 
#          carefull when using multiple executable arguments.
#          If none of the executable arguments is DEFINED (i.e., they are entered
#          as -d '' -e '' -x ''), each request is treated as a simple 
#          text-retrieval. THIS CAN BE A SECURITY RISK!
#          
#          The wiring of an interactive web-server, which also calls shell 
#          scripts with the extension '.cgi', is in place. You can 
#          "activate" it by changing the "my $ExecuteOSshell = 0;" line to 
#          "my $ExecuteOSshell = 1;".
#          If you have trouble doing this, it might be a good idea
#          to reconsider using a dynamic web server. Executing shell
#          scripts inside a web server is a rather dangerous practise.
#
#          CGIservlet can run its "standard" web server from memory. 
#          At startup, all files are read into a hash table. Upon
#          request, the contents of the file are placed in the
#          environment variable: CGI_FILE_CONTENTS.
#          No further disk access is necessary. This means that:
#          1 CGIservlet can run a WWW site from a removable disk, 
#            e.g., a floppy
#          2 The web servlet can run without any read or write privilege.
#          3 The integrity of the Web-site contents can be secured at the
#            level you want
#
#          To compres the memory (RAM) immage, you should hook the 
#          compression function to 
#          $CompressRAMimage = sub { return shift;};
#          and the decompression function to
#          $DecompressRAMimage = sub { return shift;};
# 
#
###################################################################################
#
require 5.002;
use strict;  # Should realy be used!
use Socket;
use Carp;     # could come in handy (can be missed, I think)
$| = 1;         # Autoflush

my $version = "1.3";
my $program = "CGIservlet.pl";

##################################################################
#                                                                #
#   print some information to STDERR, e.g., the process number   #
#                                                                #
##################################################################
sub logmsg { print STDERR "kill -KILL $$;exit;\n",     # Stop CGIservlet
"$0 $$: @_ at ", scalar localtime, "\n" } 

############################################################
#                                                          #
#   Parse arguments (you can define DEFAULT VALUES here)   #
#                                                          #
############################################################

my $port      = 8008;        # The port number

# Add POST requests to the QUERY_STRING, change method to 
# GET if the value is 'GET'
my $POSTtoGET = 0;                      # Add POST requests to the query string

# (Fast) direct translation of full URL paths
my %AliasTranslation = ();   # Alias => RealURL pairs (ONLY paths)
# Regular expression alias translation, in order of application
# (this can be quite slow)
my @RegAliasTranslation = ('(^|.*/)CVS(/.*|$)'); # Full regular expression alias/url pairs: URL
my @RegURLTranslation = ('/index.html');   # Full regular expression alias/url pairs: PATH

my $textroot  = $ENV{'PWD'} || `pwd`; # current working directory 
chomp($textroot);            # Remove nasty newline, if present
my $doarg     = '';          # do "filename", 

my $beginarg  = '';          # eval($Argument) at the start of the program
my $evalarg   = '';          # eval($Argument) for each request
my $execarg   = '';          # execute `command \'$textroot$Path\' \'$QueryString\'`

my $welcome   = '/index.html';  # Default path

#  Rudimentary security, overflow detection
my $MaxBrood  = 32;             # Maximum number of running children
my $MaxLength = 2**15;          # Maximum Request Length 
my $Secure = 1;			# Block browsing directories and text files or not

# If one of the following lists contains any client addresses or names, all others are
# blocked (be carefull, your site will be inaccessible if you misspell them).
my @RemoteHost = ();            # Accepted Hosts, suggest: localhost
my @RemoteAddr = ();            # Accepted IP addresses, suggest: @RemoteAddr=('127.0.0.1')
my $DefaultRemoteAddr = '127.0.0.1';  # default, use localhost IP address
my $NONAME = 0;                 # if 1, do NOT ask for REMOTE_HOST (faster)

# Store the whole Web Site in a hash table and use this RAM memory image
my $UseRAMimage = 0;
# Empty function handlers for data compression
# In general, these must be redefined in the $beginarg
my $CompressRAMimage = sub { return shift;};
my $DecompressRAMimage = sub { return shift;};

# Execute shell CGI scripts when no -d, -e, or -x are supplied
my $ExecuteOSshell = 0;         # Do you REALY want this? It is dangerous

#################################################################
#                                                               #
#   Configure CGIservlet with a setup file (overides the        #
#   default settings, but not the command line options).        #
#   Note that, if it exists, the setup file in the CGIscriptor  #
#   subdirectory is processed EVEN if there is a SETUP file     #
#   in the current directory.                                   #
#                                                               #
#################################################################
# There exists a CGIscriptor subdirectory and it contains
# a CGIservletSETUP.pl file
if((-e './CGIscriptor/CGIservletSETUP.pl') &&
   open(SETUP, '<./CGIscriptor/CGIservletSETUP.pl'))
{ 
    # Get the setup code
    my $SetupCode = join("", <SETUP>);
    # 'Eval' is used to ensure that the values are entered in the current
    # package (contrary to what 'do' and 'require' do).
    (eval $SetupCode) || die "$! $@\n";
    close(SETUP);
};
# There is a CGIservletSETUP.pl file in the current directory
if((-e './CGIservletSETUP.pl') &&
   open(SETUP, '<./CGIservletSETUP.pl'))
{ 
    # Get the setup code
    my $SetupCode = join("", <SETUP>);
    # 'Eval' is used to ensure that the values are entered in the current
    # package (contrary to what 'do' and 'require' do).
    (eval $SetupCode) || die "$! $@\n";
    close(SETUP);
};

######################################
#                                    #
#   process arguments and defaults   #
#                                    #
######################################

while ($_ = shift(@ARGV))
{
    # With switches
    if(/\-p/is)               # Port
    { 
        $port = shift(@ARGV);
    }
    elsif(/\-d/is)            # Do
    { 
        $doarg = shift(@ARGV);
    }
    elsif(/\-(x|qx|exec)/is)  # Execute
    { 
        $execarg = shift(@ARGV);
    }
    elsif(/\-b/is)            # Begin
    { 
        $beginarg = shift(@ARGV);
    }
    elsif(/\-e/is)            # Evaluate
    { 
        $evalarg = shift(@ARGV);
    }
    elsif(/\-t/is)            # Textroot
    { 
        $textroot = shift(@ARGV);
    }
    elsif(/\-w/is)            # Default welcome page
    { 
        $welcome = shift(@ARGV);
    }
    elsif(/\-c/is)            # Maximum Children
    { 
        $MaxBrood = shift(@ARGV) || $MaxBrood;
    }
    elsif(/\-l/is)            # Maximum Length
    { 
        $MaxLength = shift(@ARGV) || $MaxLength;
    }
    elsif(/\-a/is)            # Aliases
    { 
        while(@ARGV && $ARGV[0] !~ /^\-/) # while not a parameter
        {
            my $Alias = shift(@ARGV);
            my $RealURL = $ARGV[0] !~ /^\-/ ? shift(@ARGV) : "";
            next unless $Alias && $RealURL;
            # Store the alias
            # Simple straight translations
            unless($Alias =~ m/[\Q^$*&@!\?(){}[];:\E]/)
            {
                $AliasTranslation{$Alias} = $RealURL;
            }
            else  # Full regular expressions
            {
                push(@RegAliasTranslation, $Alias);
                push(@RegURLTranslation, $RealURL);
            };
            
        };
    }
    elsif(/\-r/is)            # Remote host or address
    { 
        while(@ARGV && $ARGV[0] !~ /^\-/) # while not a parameter
        {
            my $Remote = shift(@ARGV);
            if($Remote =~ /[\d\.]+/) # A host IP address
            {
                push(@RemoteAddr, $Remote);
            }
            else                     # A host domain name, less secure
            {
                push(@RemoteHost, $Remote);
            };
        };
        #
        # Use the default Remote Host (Client) IP address (e.g., localhost)
        # if no addresses or domain names are entered.
        push(@RemoteAddr, $DefaultRemoteAddr) unless @RemoteAddr || @RemoteHost;
    }
    elsif(/\-s/is)            # Secure or not
    { 
	$Secure = !$Secure;	# Toggle blocking directory browsing and ASCII file access
    }
    elsif(/\-n/is)            # Do NOT extract Remote host
    { 
                $NONAME = 1;
    }
    else        # perform unreliable magick without switches
    { 
        if(/^[0-9]+$/ && $_ > 1024)     # A (large) number must be a port
        {       
            $port = $_;
        }
        elsif(-T && /\.pl$/)    # Text file with extension .pl is a Perl file
        {       
            $doarg = $_;
        }
        elsif(-T && /\.pm$/)    # Text file with extension .pm is a Perl module file
        {       
            $beginarg = $_;
        }
        elsif(-x)       # Executables can be executed
        {       
            $execarg = $_;
        }
        elsif(-d)       # A directory can only be the root
        {       
            $textroot = $_;
        }
        elsif(-T && /^\// && /\.html$/) # An html file path is the default path
        {       
            $welcome = $_;
        }
        elsif(-T)       # A text file is something to do
        {       
            $doarg = $_;
        }
        elsif(/[\s\{\`\[\@\%]/)         # I give up, just try it
        { 
            $evalarg = shift(@ARGV);
        };
    };
};

################################################
#                                              #
#   All argument values are known.             #
#   Initialize environment variables.          #
#   (should be accessible to eval($beginarg))  #
#                                              #
################################################
#
# Initialize %ENV
$ENV{'SERVER_SOFTWARE'} = "$program $version";
$ENV{'GATEWAY_INTERFACE'} = "CGI/1.1";
$ENV{'SERVER_PORT'} = "$port";
$ENV{'CGI_HOME'} = $textroot;
$ENV{'SERVER_ROOT'} = $textroot;                # Server Root Directory
$ENV{'DOCUMENT_ROOT'} = $textroot;              # Server Root Directory
$ENV{'SCRIPT_NAME'} = $doarg.$execarg.$evalarg;  # Combine executable arguments

################################################
#                                              #
#   The initial argument should be evaluated   #
#                                              #
################################################

eval($beginarg) if $beginarg;

################################################
#                                              #
#   The initial argument has been evaluated    #
#                                              #
################################################
#
# Socket related code
my $proto = getprotobyname('tcp');
$port = $1 if $port =~ /(\d+)/; # untaint port number

socket(Server, PF_INET, SOCK_STREAM, $proto)        || die "socket: $!";
setsockopt(Server, &SOL_SOCKET, &SO_REUSEADDR, 
pack("l", 1))                               || die "setsockopt: $!";
bind(Server, sockaddr_in($port, INADDR_ANY))        || die "bind: $!";
listen(Server,SOMAXCONN)                            || die "listen: $!";

# 
# Report start of server
logmsg "server started on port $port";

# Set up SIG vector (every signal will kill the process that receives it)
$SIG{CHLD} = 'IGNORE';
$SIG{'KILL'} = "SigHandler";
$SIG{'TERM'} = "SigHandler";
$SIG{'QUIT'} = "SigHandler";
$SIG{'HUP'}  = "SigHandler";

# Define text mime types served if no scripts are defined
# Note that the "text/osshell" mime-type is executed by CGIservlet ITSELF!
# You should remove it if you don't want that!
my %mimeType = (
'HTML'=> "text/html",
'TXT' => "text/plain",
'PL'  => "text/plain",    # This is incorrect, of course
'JPG'  => "image/jpeg",
'JPEG' => "image/jpeg",
'GIF'  => "image/gif",
'AU'   => "audio/basic",
'AIF'  => "audio/aiff",
'AIFC' => "audio/aiff",
'AIFF' => "audio/aiff",
'GZ'   => "application/gzip",
'TGZ'   => "application/tar",
#'CGI'  => "text/osshell",       # Executes SERVER side shell scripts, HIGHLY DANGEROUS
'WAV'  => "audio/wav",
'OGG'  => "audio/x-vorbis",
'PDF'  => "application/pdf",
'PS'  => "application/postscript"
);

################################################
#                                              #
#   Fill the RAM image of the web site         #
#                                              #
################################################

my %WWWramImage = ();
if($UseRAMimage)
{
        my  $TotalSize = 0;
        my @WWWfilelist = `find $textroot ! -type l ! -type d -print`;
        my $WWWfile;
        foreach $WWWfile (@WWWfilelist)
        {
                chomp($WWWfile);
                # Skip unsupported file types
                $WWWfile =~ /\.(\w+)$/;
                my $WWWfileExtension = uc($1);
                next unless $mimeType{$WWWfileExtension};
                # Store GnuZipped image of file
                $WWWramImage{$WWWfile} = "";
                open(FILEIN, "<$WWWfile") || die "$WWWfile could not be opened: $!\n";
                my $Buffer;
                while(sysread(FILEIN, $Buffer, 1024))
                {
                    $WWWramImage{$WWWfile} .= $Buffer;
                };
                # Apply compression
                my $CompressedPtr = &$CompressRAMimage(\${WWWramImage{$WWWfile}});
                $WWWramImage{$WWWfile} = $$CompressedPtr;
                $TotalSize += length($WWWramImage{$WWWfile});
        };
        #
        # Report size of Web RAM image
        print STDERR "Total number of $TotalSize bytes read in memory image\n";
};

################################################
#                                              #
#   The RAM image of the web site has been     #
#   filled.                                    #
#                                              #
################################################

# Map HTTP request parameters to Environment variables 
# HTTP request => Environment variable
my %HTTPtype = (
'content-length'  => 'CONTENT_LENGTH',    # Necessary for POST
'user-agent'      => 'HTTP_USER_AGENT',
'accept'          => 'HTTP_ACCEPT',
'content-type'    => 'CONTENT_TYPE',
'auth-type'       => 'AUTH_TYPE',
'ident'           => 'REMOTE_IDENT',
'referer'         => 'HTTP_REFERER',
'user'            => 'REMOTE_USER',
'address'         => 'REMOTE_ADDR',
'connection'      => 'HTTP_CONNECTION',
'accept-language' => 'HTTP_ACCEPT_LANGUAGE',
'accept-encoding' => 'HTTP_ACCEPT_ENCODING',
'accept-charset'  => 'HTTP_ACCEPT_CHARSET',
'host'            => 'HTTP_HOST'
);

###############################################################################
#                                                                             #
#  Now we start with the real work. When there is a request, get the required #
#  values and fork a child to service it.                                     #
#                                                                             #
###############################################################################

my @brood = ();
my $child;

# When someone knocks on the door
for (;;) 
{
    my $paddr;
    
    if(!($paddr = accept(Client,Server)) ) # Knock knock
    {
        exit 1; # This went terrribly wrong
    };
    
    # Fork to child and parent
    if(($child =fork()) == 0) 
    {
        # this is the child
        my ($port,$iaddr) = sockaddr_in($paddr);
        my $address = inet_ntoa($iaddr);  # The IP address of the Client
        # The following is EXTREMELY slow and generally unnecessary.
        # Use -n  or set $NONAME = 1; if you don't need it.
        my $name = $NONAME ? '' : gethostbyaddr($iaddr,AF_INET);
        my @Input = ();

        #
        # Before doing anything else, check whether the client should be 
        # served at all.
        # Is IP addr on the list?
        if(@RemoteAddr && !grep(/^\Q$address\E/, @RemoteAddr)) 
        {
            print STDERR "Reject $address $name\n";
            exit 1;
        };
        # Is name on the list?
        if(@RemoteHost && !grep(/\Q$name\E$/, @RemoteHost))    
        {
            print STDERR "Reject $name $address\n";
            exit 1;
        };
        
        #
        # Grab a line without using buffered input... Important for
        # Post methods since they have to read the Client input stream.
        #
        my $string = "";
        my $ch = "";
        my $HTTPlength = 0;
        alarm 120 ;     # prevent deadly spin if other end goes away
        while(sysread(Client, $ch, 1)>0)
        {
            $string .= $ch;
            ++$HTTPlength;
            last if $HTTPlength > $MaxLength;  # Protect against overflow 
            
            next if $ch eq "\r"; # skip <cr>
            if($ch eq "\n")
            {
                        last unless $string =~ /\S/;        # stop if empty line
                        push (@Input, split(' ', $string)); # Collect input in list
                        $string = "";
            };
        };
        alarm 0;    # clear alarm
        
        # Extract input arguments
        my $method   = shift(@Input);
        my $Request  = shift(@Input);
        my $protocol = shift(@Input);
        my ($Path, $QueryString) = split('\?', $Request);
        
        # Get rest of Input
        my $HTTPparameter;
        my %HTTPtable = ();
        while($HTTPparameter = lc(shift(@Input)))
        {
            chop($HTTPparameter);
            $HTTPtable{$HTTPparameter} = "";
            while(@Input && $Input[0] !~ /\:$/)
            {   
                $HTTPtable{$HTTPparameter} .= " " if  $HTTPtable{$HTTPparameter};
                $HTTPtable{$HTTPparameter} .= shift(@Input);
            };
        };
        
        # Translate the Aliases
	$Path = GetAlias($Path);
       
        # HTTP servers should always add the default path
        $Path = $welcome if !$Path || $Path eq '/';     # The common default path
        
        # Set fixed environment variables
        $ENV{'PATH_INFO'}       = "$Path"; 
        $ENV{'QUERY_STRING'}    = "$QueryString";
        $ENV{'PATH_TRANSLATED'} = "$textroot$Path";
        $ENV{'SERVER_PROTOCOL'} = "$protocol";
        $ENV{'REQUEST_METHOD'}  = "$method";
        $ENV{'REMOTE_ADDR'}     = "$address";  # The IP address of the Client
        $ENV{'REMOTE_HOST'}     = "$name";
        
        # Load all request information in the %ENV.
        # MUST be done with a pre-defined list of parameter names.
        foreach $HTTPparameter (keys(%HTTPtype))
        {
            my $Label = $HTTPtype{$HTTPparameter};
            # The following adds environment variables FROM THE REQUEST.
            # It is a VERY, VERY bad idea to just use the client supplied 
            # parameter names!
            $ENV{$Label} = $HTTPtable{$HTTPparameter} unless exists($ENV{$Label});
            # (The last part prevents overwriting existing environment variables)
        };
        
        # SECURITY: Check length of POST request. Stop if request is too long
        die if $HTTPlength + $ENV{'CONTENT_LENGTH'} > $MaxLength;

        # If POST requests are unwanted, they can be added tot the query string
        # NOTE: the method is set to GET if $POSTtoGET equals 'GET', otherwise, 
        # the method stays POST and only the content length is set to 0
        if($POSTtoGET && $ENV{'REQUEST_METHOD'} =~ /^POST$/i)
        {
                my $POSTlength = $ENV{'CONTENT_LENGTH'} || 0;
                my $ReadBytes = 1;

                # Add '&' if there is a query string already
                if($ENV{'QUERY_STRING'})
                {
                        # Before we add something to the string, check length again
                die if $HTTPlength + $ENV{'CONTENT_LENGTH'} + 1 > $MaxLength;
                        # Now add the '&'
                        $ENV{'QUERY_STRING'} .= '&';
                };

                # Read Client
                while($POSTlength > 0 && $ReadBytes > 0)
                {
                        my $Read = "";
                        $ReadBytes = sysread(Client, $Read, $POSTlength);
                        $ENV{'QUERY_STRING'} .= $Read;
                        $POSTlength -= $ReadBytes;
                };

                # All has been read, the content length becomes 0
                $ENV{'CONTENT_LENGTH'} = 0;
                # Method can change
                $ENV{'REQUEST_METHOD'} = 'GET' if $POSTtoGET eq 'GET';
        };

        #
        # Connect STDOUT and STDIN to the client
        open(STDIN, "<&Client");
        open(STDOUT, ">&Client");
        print STDOUT "HTTP/1.1 200 OK\n";       # Supply HTTP protocol information
	print STDOUT "Date: ".gmtime()." GMT\n"; # Current date
	print STDOUT "Server: $program $version\n"; # This program
	print STDOUT "Connection: close\n"; # Don't allow persistent connections

        # Start processing of request (note that ALL scripts will be executed if
        # present, i.e., if -d, -x, and -e are entered, they are alle processed).
        
        # If in memory-only mode, store the requested file in an environment
        # variable: CGI_FILE_CONTENTS
        undef($ENV{'CGI_FILE_CONTENTS'}); # Make sure the ENV var doesn't exist
        if($UseRAMimage)
        {
            my $DecompressedPtr = &$DecompressRAMimage(\${WWWramImage{"$textroot$Path"}});
            $ENV{'CGI_FILE_CONTENTS'} = $$DecompressedPtr;
            # Decompression does not seem to work
        };
        
        # do perl script
        @ARGV = ("$textroot$Path", $QueryString);
        do "$doarg" if $doarg; # The perl script should do the printing
        
        # evaluate perl command
        print STDOUT eval($evalarg) if $evalarg;
        
        # execute shell command
        if($execarg)
        {
            my $shellscript = $execarg;
            
            # Attempts to use Paths or Queries containing '-quotes are rejected.
            # Executing these would compromise security. 
            die "Quotes in path: $textroot$Path\n" if "$textroot$Path" =~ /\'/; 
            $shellscript .= " '$textroot$Path'" if $Path;
            
            die "Quotes in query: $QueryString\n" if $QueryString =~ /\'/; 
            $shellscript .= " '$QueryString'" if $QueryString;
            $shellscript = qx{$shellscript};
            print STDOUT $shellscript;
        };
        
        # Output files if no scripts are given (actually, this should be 
        # handled by a script). Unknown mimetypes are killed.
        # This is more or less a functional (dynamic) Web server in itself.
        unless($doarg || $execarg || $evalarg) # Request not already handled
        { 
            die ".. trick: $address $name $Path $QueryString\n" 
            if $Path =~ m@\.\./@ ;      # No tricks!
            
	    # Handle mime-types and directory browsing
            $Path =~ /\.([\w]+)$/;      # Get extension
            my $extension = uc($1);
	    my $browse = ($Path =~ m@/\s*$@ || -d "$textroot$Path") ? 1 : 0;
            my $mime = $browse ? "" : $mimeType{$extension};
	    
	    # Serve up text and binary files unless they the $Secure option is given
	    $mime = "text/plain" if !$mime && !$browse && (-T "$textroot$Path") && !$Secure;
	    $mime = "application/octet-stream" if !$mime && !$browse && (-B "$textroot$Path") && !$Secure;
	    
	    # Remove final / in directory paths
	    $Path =~ s@/\s*$@@g;
	    
	    # Block illegal mime-types
	    die "Illegal mime type:$extension\n" unless $mime || $browse; # illegal mime's are killed
            
            # Print out the document
            if(($mime eq 'text/osshell') && $ExecuteOSshell) # Don't use this unless you know what you'r doing
            {
                # Note that CGI scripts must supply their own content type
                # Some rudimentary security tests
                # Kill child if the path contains any non-URL characters
                die "ATTACK: ADDR:$ENV{'REMOTE_ADDR'} HOST:$ENV{'REMOTE_HOST'} URL=$Path '$QueryString'\n" 
                if $Path =~ m@[^\w\-\.\/]@;     # Exclusive list of allowed characters
                # If you want to execute server side shell scripts, use the 'text/osshell' 
                # mime-type (see above) but remember that there is NO SECURITY implemented 
                # whatsoever. 
                # Plain Web site from DISK
                unless($UseRAMimage)
                {
                    print STDOUT `$textroot$Path`;  # This is Russian Roulette
                }
                else  # Use a RAM image of the web site
                {
                    my $ShellInterpreter = '/usr/bin/sh';
                    if($ENV{'CGI_FILE_CONTENTS'} =~ /^\#\!\s*([^\r\n]+)/isg)
                    {
                        $ShellInterpreter = $1;
                    };
                    # Execute shell script
                    open(RAMOUT, "| $ShellInterpreter") || die "ERROR open RAMOUT  $ShellInterpreter $textroot$Path $! $@\n";
                    (print RAMOUT $ENV{'CGI_FILE_CONTENTS'}) || die "ERROR print RAMOUT $ShellInterpreter $textroot$Path $! $@\n";
                    close(RAMOUT);
                };
            }
            elsif($mime)
            {
                # Content-type and document
                print STDOUT "Content-type: $mime\n\n";
                # Plain Web site from DISK
                unless($UseRAMimage)
                {
                    print STDOUT `cat '$textroot$Path'` # lazy, let the OS do the work   
                }
                else  # Use a RAM image of the web site
                {
                    print STDOUT $ENV{'CGI_FILE_CONTENTS'};

                };
	    }
	    elsif($browse && !$Secure)	# Block directory browsing in the Secure setup
	    {
                # Content-type and document
                print STDOUT "Content-type: text/html\n\n";
		opendir(BROWSE, "$textroot$Path") || die "<$textroot$Path: $!\n";
		
		print "<HTML>\n<HEAD>\n<TITLE>$Path</TITLE></HEAD>\n<BODY>\n<H1>$Path</H1>\n<pre>\n<dl>";
		
		my $DirEntry;
		foreach $DirEntry (sort {lc($a) cmp lc($b)} readdir(BROWSE))
		{
			my $CurrentPath = $Path;
			# Handle '..'
			if($DirEntry eq '..')
			{
				my $ParentDir = $CurrentPath;
				$ParentDir =~ s@/[^/]+$@@g;
				$ParentDir = '/' unless $ParentDir;
				print "<dt> <a href='$ParentDir'><h3>Parent directory</h3></a></dt>\n";
			};
			next if $DirEntry !~ /[^\.\/\\\:]/;
			
			# Get aliases
			my $Alias = GetAlias("$CurrentPath/$DirEntry");
			if($Alias ne "$CurrentPath/$DirEntry")
			{
				$Alias =~ m@/([^/]+)$@;
				$CurrentPath = $`;
				$DirEntry = $1;
			};
			# 
			my $Date = localtime($^T - (-M "$textroot$CurrentPath/$DirEntry")*3600*24);
			my $Size = -s "$textroot$CurrentPath/$DirEntry";
			$Size = sprintf("%6.0F kB", $Size/1024);
			my $Type = `file $textroot$CurrentPath/$DirEntry`;
			$Type =~ s@\s*$textroot$CurrentPath/$DirEntry\s*\:\s*@@ig;
	    		chomp($Type);
			print "<dt> <a href='$CurrentPath/$DirEntry'>";
			printf("%-40s", $DirEntry."</a>");
			print "\t$Size\t$Date\t$Type</dt>\n";
		};
		close(BROWSE);
		print "</dl></pre></BODY>\n</HTML>\n";
	    	
            };
        };

        close(STDOUT) || die "STDOUT: $!\n";
        close(STDIN) || die "STDIN: $!\n";
	close(Client) || die "Client: $!\n";
        #
        exit 0; # Kill Child
    }
    else
    {
        #
        # parent code...some systems will have to worry about waiting
        # before they can actually close the link to the Client

        # Determine which of the children are actually still alive
        my @old_brood = @brood;
        @brood = ();    # empty brood
        foreach (@old_brood)
        {  
            push(@brood, $_) if kill (0, $_); # Alive?
        };
        
        # Weed out overflow of children (zombies etc.)
        my $oldest;
        for($oldest=0; $oldest < scalar(@brood)-$MaxBrood; ++$oldest)
        {
            kill "KILL", $brood[$oldest] if $brood[$oldest]; # Remove
        };
        
        # Push new child on the list
        push (@brood, $child);
        
        close Client;  # This is it, ready!
    };
};

# Interupt handler for shutting down
sub SigHandler 
{
    my $sig = shift;
    exit 1;
}

# Subroutine for Aliases
# Uses Global variables: %AliasTranslation, @RegAliasTranslation, and @RegURLTranslation
sub GetAlias	# ($Path)->AliasURL
{
    my $Path = shift;
        
    # Translate the Aliases
    if($AliasTranslation{$Path})
    { 
        $Path = $AliasTranslation{$Path};
    }
    elsif(@RegAliasTranslation)
    {  
       my $i;
       for($i=0; $i<scalar(@RegAliasTranslation); ++$i)
       { 
           my $Alias   = $RegAliasTranslation[$i];
           my $RealURL = $RegURLTranslation[$i];
           last if ($Path =~ s#$Alias#$RealURL#g);
       };
    };
    return $Path;    
}

=head1 NAME

CGIservlet - a HTTPd "connector" for running CGI scripts on unix systems as WWW
accessible Web sites. 

=head1 DESCRIPTION

The servlet starts a true HTTP daemon that channels 
HTTP requests to forked daughter processes. Can run 
a (small) WWW-site from memory.
 
=head1 README

Whenever an HTTP request is received, the specified CGI script is 
started inside a child process as if it was inside a real server (e.g., 
Apache). The evironment variables are set more or less as in Apache. 
Note that CGIservlet only uses a SINGLE script for ALL requests.
No attemps for security are made, it is the script's responsibility to 
check access rights and the validity of the request.
Can store the files of Web site in memory and serve them
on request.

=head1 PREREQUISITES

This script requires the C<strict>, Socket and Carp modules.

=head1 COREQUISITES

=pod OSNAMES

Unix

=pod SCRIPT CATEGORIES

CGI
Web

=cut
