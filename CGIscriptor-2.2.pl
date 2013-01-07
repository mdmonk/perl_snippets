#! /usr/bin/perl 
#
# (configure the first line to contain YOUR path to perl 5.000+)
#
# CGIscriptor.pl
# Version 2.1
# 15 January 2002
#
# YOU NEED:
#
# perl 5.0 or higher (see: "http://www.perl.org/")
#                
# Notes:
#  
# This Perl program will run on any WWW server that runs Perl scripts,
# just add a line like the following to your srm.conf file 
# (Apache example):
# 
# ScriptAlias /SHTML/ "/real-path/CGIscriptor.pl/"
# 
# URL's that refer to http://www.your.address/SHTML/... will now be handled 
# by CGIscriptor.pl, which can use a private directory tree (default is the 
# DOCUMENT_ROOT directory tree, but it can be anywhere, see below).
# 
# This file contains all documentation as comments. These comments
# can be removed to speed up loading (e.g., `egrep -v '^#' CGIscriptor.pl` > 
# leanScriptor.pl). A bare bones version of CGIscriptor.pl, lacking
# documentation, most comments, access control, example functions etc.
# (but still with the copyright notice and some minimal documentation)
# can be obtained by calling CGIscriptor.pl with the '-slim'
# command line argument, e.g.,
# >CGIscriptor.pl -slim >slimCGIscriptor.pl
# 
# CGIscriptor.pl can be run from the command line as 
# `CGIscriptor.pl <path> <query>`, inside a perl script with 
# 'do CGIscriptor.pl' after setting $ENV{PATH_INFO} and $ENV{QUERY_STRING}, 
# or CGIscriptor.pl can be loaded with 'require "/real-path/CGIscriptor.pl"'. 
# In the latter case, requests are processed by 'Handle_Request();' 
# (again after setting $ENV{PATH_INFO} and $ENV{QUERY_STRING}). 
# 
# Running demo's and more information can be found at 
# http://www.fon.hum.uva.nl/rob/OSS/OSS.html
#         
# A pocket-size HTTP daemon, CGIservlet.pl, is available from my web site
# or CPAN that can use CGIscriptor.pl as the base of a µWWW server and 
# demonstrates its use.
#
# Configuration, copyright notice, and user manual follow the next 
# (Changes) section.
#
############################################################################
#
# Changes (document ALL changes with date, name and email here):
# 19 Mar  2002 - Added SRC pseudo-files PREFIX and POSTFIX. These
#                switch to prepending or to appending the content
#                of the SRC attribute. Default is prefixing. You
#                can add as many of these switches as you like.
# 13 Mar  2002 - Do not search for tag content if a tag closes with
#                />, i.e., <DIV ... /> will be handled the XML way.
# 25 Jan  2002 - Added 'curl' and 'snarf' to SRC attribute URL handling 
#                (replaces wget).
# 25 Jan  2002 - Found a bug in SAFEqx, now executes qx() in a scalar context
#                (i.o. a list context). This is necessary for binary results.
# 24 Jan  2002 - Disambiguated -T $SRCfile to -T "$SRCfile" (and -e) and
#                changed the order of if/elsif to allow removing these 
#                conditions in systems with broken -T functions.
#                (I also removed a spurious ')' bracket)
# 17 Jan  2002 - Changed DIV tag SRC from <SOURCE> to sysread(SOURCE,...)
#                to support binary files.
# 17 Jan  2002 - Removed WhiteSpace from $FileAllowedCharacters.
# 17 Jan  2002 - Allow "file://" prefix in SRC attribute. It is simply
#                stipped from the path.
# 15 Jan  2002 - Version 2.2
# 15 Jan  2002 - Debugged and completed URL support (including 
#                CGIscriptor::read_url() function)
# 07 Jan  2002 - Added automatic (magic) URL support to the SRC attribute 
#                with the main::GET_URL function. Uses wget -O underlying.
# 04 Jan  2002 - Added initialization of $NewDirective in InsertForeignScript
#                (i.e., my $NewDirective = "";) to clear old output
#                (this was a realy anoying bug).
# 03 Jan  2002 - Added a <DIV CLASS='text/ssperl' ID='varname'></DIV> 
#                tags that assign the body text as-is (literally)
#                to $varname. Allows standard HTML-tools to handle
#                Cascading Style Sheet templates. This implements a
#                design by Gerd Franke (franke@roo.de).
# 03 Jan  2002 - I finaly gave in and allowed SRC files to expand ~/.
# 12 Oct  2001 - Normalized spelling of "CGIsafFileName" in documentation.
# 09 Oct  2001 - Added $ENV{'CGI_BINARY_FILE'} to log files to 
#                detect unwanted indexing of TAR files by webcrawlers.
# 10 Sep  2001 - Added $YOUR_SCRIPTS directory to @INC for 'require'.
# 22 Aug  2001 - Added .txt (Content-type: text/plain) as a default 
#                processed file type. Was processed via BinaryMapFile.
# 31 May  2001 - Changed =~ inside CGIsafeEmailAddress that was buggy.
# 29 May  2001 - Updated $CGI_HOME to point to $ENV{DOCUMENT_ROOT} io
#                the root of PATH_TRANSLATED. DOCUMENT_ROOT can now
#                be manipulated to achieve a "Sub Root". 
#                NOTE: you can have $YOUR_HTML_FILES != DOCUMENT_ROOT
# 28 May  2001 - Changed CGIscriptor::BrowsDirs function for security
#                and debugging (it now works).
# 21 May  2001 - defineCGIvariableHash will ADD values to existing
#                hashes,instead of replacing existing hashes.
# 17 May  2001 - Interjected a '&' when pasting POST to GET data
# 24 Apr  2001 - Blocked direct requests for BinaryMapFile. 
# 16 Aug  2000 - Added hash table extraction for CGI parameters with 
#                CGIparseValueHash (used with structured parameters).
#                Use: CGI='%<CGI-partial-name>' (fill in your name in <>)
#                Will collect all <CGI-partial-name><key>=value pairs in
#                $<CGI-partial-name>{<key>} = value;
# 16 Aug  2000 - Adapted SAFEqx to protect @PARAMETER values.
# 09 Aug  2000 - Added support for non-filesystem input by way of
#                the CGI_FILE_CONTENTS and CGI_DATA_ACCESS_CODE
#                environment variables.
# 26 Jul  2000 - On the command-line, file-path '-' indicates STDIN.
#                This allows CGIscriptor to be used in pipes.
#                Default, $BLOCK_STDIN_HTTP_REQUEST=1 will block this
#                in an HTTP request (i.e., in a web server).
# 26 Jul  2000 - Blocked 'Content-type: text/html' if the SERVER_PROTOCOL
#                is not HTTP or another protocol. Changed the default
#                source directory to DOCUMENT_ROOT (i.o. the incorrect
#                SERVER_ROOT).
# 24 Jul  2000 - -slim Command-line argument added to remove all
#                comments, security, etc.. Updated documentation.
# 05 Jul  2000 - Added IF and UNLESS attributes to make the
#                execution of all <META> and <SCRIPT> code
#                conditional.
# 05 Jul  2000 - Rewrote and isolated the code for extracting
#                quoted items from CGI and SRC attributes.
#                Now all attributes expect the same set of
#                quotes: '', "", ``, (), {}, [] and the same
#                preceded by a \, e.g., "\((aap)\)" will be 
#                extracted as "(aap)".
# 17 Jun  2000 - Construct @ARGV list directly in CGIexecute
#                name-space (i.o. by evaluation) from
#                CGI attributes to prevent interference with
#                the processing for non perl scripts.
#                Changed CGIparseValueList to prevent runaway
#                loops.
# 16 Jun  2000 - Added a direct (interpolated) display mode
#                (text/ssdisplay) and a user log mode
#                (text/sslogfile).
# 06 Jun  2000 - Replace "print $Result" with a syswrite loop to
#                allow large string output.
# 02 Jun  2000 - Corrected shrubCGIparameter($CGI_VALUE) to realy
#                remove all control characters. Changed Interpreter
#                initialization to shrub interpolated CGI parameters.
#                Added  'text/ssmailto' interpreter script.
# 22 May  2000 - Changed some of the comments
# 09 May  2000 - Added list extraction for CGI parameters with 
#                CGIparseValueList (used with multiple selections).
#                Use: CGI='@<CGI-parameter>' (fill in your name in <>)
# 09 May  2000 - Added a 'Not Present' condition to CGIparseValue.
# 27 Apr  2000 - Updated documentation to reflect changes.
# 27 Apr  2000 - SRC attribute "cleaned". Supported for external
#                interpreters.
# 27 Apr  2000 - CGI attribute can be used in <SCRIPT> tag.
# 27 Apr  2000 - Gprolog, M4 support added.
# 26 Apr  2000 - Lisp (rep) support added.
# 20 Apr  2000 - Use of external interpreters now functional.
# 20 Apr  2000 - Removed bug from extracting Content types (RegExp)
# 10 Mar  2000 - Qualified unconditional removal of '#' that preclude
#                the use of $#foo, i.e., I changed
#                s/[^\\]\#[^\n\f\r]*([\n\f\r])/\1/g
#                to
#                s/[^\\\$]\#[^\n\f\r]*([\n\f\r])/\1/g
# 03 Mar  2000 - Added a '$BlockPathAccess' variable to "hide" 
#                things like, e.g., CVS information in CVS subtrees
# 10 Feb  2000 - URLencode/URLdecode have been made case-insensitive
# 10 Feb  2000 - Added a BrowseDirs function (CGIscriptor package)
# 01 Feb  2000 - A BinaryMapFile in the ~/ directory has precedence
#                over a "burried" BinaryMapFile.
# 04 Oct  1999 - Added two functions to check file names and email addresses
#                (CGIscriptor::CGIsafeFileName and 
#                 CGIscriptor::CGIsafeEmailAddress)
# 28 Sept 1999 - Corrected bug in sysread call for reading POST method 
#                to allow LONG posts.
# 28 Sept 1999 - Changed CGIparseValue to handle multipart/form-data.
# 29 July 1999 - Refer to BinaryMapFile from CGIscriptor directory, if
#                this directory exists.
# 07 June 1999 - Limit file-pattern matching to LAST extension
# 04 June 1999 - Default text/html content type is printed only once.
# 18 May  1999 - Bug in replacement of ~/ and ./ removed.
#                (Rob van Son, Rob.van.Son@hum.uva.nl)
# 15 May  1999 - Changed the name of the execute package to CGIexecute.
#                Changed the processing of the Accept and Reject file.
#                Added a full expression evaluation to Access Control.
#                (Rob van Son, Rob.van.Son@hum.uva.nl)
# 27 Apr  1999 - Brought CGIscriptor under the GNU GPL. Made CGIscriptor 
# Version 1.1    a module that can be called with 'require "CGIscriptor.pl"'.
#                Requests are serviced by "Handle_Request()". CGIscriptor 
#                can still be called as a isolated perl script and a shell
#                command. 
#                Changed the "factory default setting" so that it will run
#                from the DOCUMENT_ROOT directory.
#                (Rob van Son, Rob.van.Son@hum.uva.nl)
# 29 Mar  1999 - Remove second debugging STDERR switch. Moved most code
#                to subroutines to change CGIscriptor into a module.
#                Added mapping to process unsupported file types (e.g., binary
#                pictures). See $BinaryMapFile.
#                (Rob van Son, Rob.van.Son@hum.uva.nl)
# 24 Sept 1998 - Changed text of license (Rob van Son, Rob.van.Son@hum.uva.nl)
#                Removed a double setting of filepatterns and maximum query 
#                size. Changed email address. Removed some typos from the
#                comments.
# 02 June 1998 - Bug fixed in URLdecode. Changing the foreach loop variable
#                caused quiting CGIscriptor.(Rob van Son, Rob.van.Son@hum.uva.nl)
# 02 June 1998 - $SS_PUB and $SS_SCRIPT inserted an extra /, removed.
#                (Rob van Son, Rob.van.Son@hum.uva.nl)
# 
#
# Known Bugs:
# 
# 23 Mar 2000
# It is not possible to use operators or variables to construct variable names, 
# e.g., $bar = \@{$foo}; won't work. However, eval('$bar = \@{'.$foo.'};'); 
# will indeed work. If someone could tell me why, I would be obliged.
# 
#
############################################################################
#
# OBLIGATORY USER CONFIGURATION
#
# Configure the directories where all user files can be found (this 
# is the equivalent of the server root directory of a WWW-server).  
# These directories can be located ANYWHERE. For security reasons, it is 
# better to locate them outside the WWW-tree of your HTTP server, unless
# CGIscripter handles ALL requests.
# 
# For convenience, the defaults are set to the root of the WWW server.
# However, this might not be safe!
# 
# ~/ text files
# $YOUR_HTML_FILES = "/usr/pub/WWW/SHTML"; # or SS_PUB as environment var
# (patch to use the parent directory of CGIscriptor as document root, should be removed)
if($ENV{'SCRIPT_FILENAME'}) # && $ENV{'SCRIPT_FILENAME'} !~ /\Q$ENV{'DOCUMENT_ROOT'}\E/)
{
	$ENV{'DOCUMENT_ROOT'} = $ENV{'SCRIPT_FILENAME'};
	$ENV{'DOCUMENT_ROOT'} =~ s@/CGIscriptor.*$@@g;
};

# Just enter your own directory path here
$YOUR_HTML_FILES = $ENV{'DOCUMENT_ROOT'};     # default is the DOCUMENT_ROOT
#
# ./ script files (recommended to be different from the previous)
# $YOUR_SCRIPTS = "/usr/pub/WWW/scripts";  # or SS_SCRIPT as environment var
$YOUR_SCRIPTS = $YOUR_HTML_FILES;           # This might be a SECURITY RISK
#
# End of obligatory user configuration
# (note: there is more non-essential user configuration below)
#
############################################################################
#
# OPTIONAL USER CONFIGURATION (all values are used CASE INSENSITIVE)
#
# Script content-types: TYPE="Content-type" (user defined mime-type)
$ServerScriptContentType = "text/ssperl"; # Server Side Perl scripts
#
$ShellScriptContentType = "text/osshell"; # OS shell scripts 
#                                         # (Server Side perl ``-execution)
#
# Accessible file patterns, block any request that doesn't match.
# Matches any file with the extension .(s)htm(l), .txt, or .xmr 
# (\. is used in regexp)
# Note: die unless $PATH_INFO =~ m@($FilePattern)$@is;
$FilePattern = ".shtml|.htm|.html|.xmr|.txt"; 
#
# The table with the content type MIME types 
# (allows to differentiate MIME types, if needed)
%ContentTypeTable =
(
'.html' => 'text/html',
'.shtml' => 'text/html',
'.htm' => 'text/html',
'.txt' => 'text/plain'
);

#
# File pattern post-processing
$FilePattern =~ s/([@.])/\\$1/g;  # Convert . and @ to \. and \@
#
# Raw files must contain their own Content-type (xmr <- x-multipart-replace). 
# THIS IS A SUBSET OF THE FILES DEFINED IN $FilePattern
$RawFilePattern = ".xmr"; 
#
# Raw File pattern post-processing
$RawFilePattern =~ s/([@.])/\\$1/g;  # Convert . and @ to \. and \@
#
# Server protocols for which "Content-type: text/html\n\n" should be printed
# (you should not bother with these, except for HTTP, they are mostly imaginary)
$ContentTypeServerProtocols = 'HTTP|MAIL|MIME';
#
# Block access to all (sub-) paths and directories that match the 
# following (URL) path (is used as: 
# 'die if $BlockPathAccess && $ENV{'PATH_INFO'} =~ m@$BlockPathAccess@;' )
$BlockPathAccess = '/CVS/';             # Protect CVS information
#
# All (blocked) other file-types can be mapped to a single "binary-file" 
# processor (a kind of pseudo-file path). This can either be an error 
# message (e.g., "illegal file") or contain a script that serves binary 
# files.
# Note: the real file path wil be stored in $ENV{CGI_BINARY_FILE}. 
$BinaryMapFile = "/BinaryMapFile.xmr"; 
# Allow for the addition of a CGIscriptor directory
# Note that a BinaryMapFile in the root "~/" directory has precedence
$BinaryMapFile = "/CGIscriptor".$BinaryMapFile 
if !  -e "$YOUR_HTML_FILES".$BinaryMapFile  
&& -e "$YOUR_HTML_FILES/CGIscriptor".$BinaryMapFile;
#
# List of all characters that are allowed in file names and paths. 
# All requests containing illegal characters are blocked. This
# blocks most tricks (e.g., adding "\000", "\n", or other control
# characters)
# THIS IS A SECURITY FEATURE
# (this is also used to parse filenames in SRC= features, note the 
# '-quotes, they are essential)
$FileAllowedChars = '\w\.\~\*\?\/\:\-'; # Covers Unix and Mac, but NO spaces
#
# The string used to separate directories in the path 
# (used for ~/ and ./ substitution).  
$DirectorySeparator = '/';                 # Unix
# $DirectorySeparator = ':';                 # Mac
# $DirectorySeparator = '\';                 # MS things ?
# (I haven't actually tested this for non-UNIX OS's)
#
# Maximum size of the Query (number of characters clients can send
# covers both GET & POST combined)
$MaximumQuerySize = 2**20 - 1; # = 2**14 - 1
#
#
# Embeded URL get function used in SRC attributes and CGIscriptor::read_url
# (returns a string with the PERL code to transfer the URL contents, e.g., 
# "SAFEqx(\'curl \"http://www.fon.hum.uva.nl\"\')")
# "SAFEqx(\'wget --quiet --output-document=- \"http://www.fon.hum.uva.nl\"\')")
# Be sure to handle <BASE HREF='URL'> and allow BOTH 
# direct printing GET_URL($URL [, 0]) and extracting the content of
# the $URL for post-processing GET_URL($URL, 1).
# You get the WHOLE file, including HTML header.
# The shell command Use $URL where the URL should go
# ('wget', 'snarf' or 'curl', uncomment the one you would like to use)
#my $GET_URL_shell_command = 'wget --quiet --output-document=- $URL';
#my $GET_URL_shell_command = 'snarf $URL -';
my $GET_URL_shell_command = 'curl $URL';

sub GET_URL	# ($URL, $ValueNotPrint) -> content_of_url
{
	my $URL = shift || return;
	my $ValueNotPrint = shift || 0;
	
	# Check URL for illegal characters
	return "print '<h1>Illegal URL<h1>'\"\n\";" if $URL =~ /[^$FileAllowedChars\%]/;
	
	# Include URL in final command
	my $CurrentCommand = $GET_URL_shell_command;
	$CurrentCommand =~ s/\$URL/$URL/g;
	
	# Print to STDOUT or return a value
	my $BlockPrint = "print STDOUT ";
	$BlockPrint = "" if $ValueNotPrint;
	
	my $Commands = <<"GETURLCODE";
	# Get URL
	{
		my \$Page = "";
	
		# Simple, using shell command 
		\$Page = SAFEqx('$CurrentCommand');
	
		# Add a BASE tage to the header
		\$Page =~ s!\\</head!\\<base href='$URL'\\>\\</head!ig unless \$Page =~ m!\\<base!;
	
		# Print the URL value, or return it as a value
		$BlockPrint\$Page;
	};
GETURLCODE
print STDERR "'$Commands'";
	return $Commands;
};
#
# As files can get rather large (and binary), you might want to use
# some more intelligent reading procedure, e.g., 
# 	Direct Perl
# 	# open(URLHANDLE, '/usr/bin/wget --quiet --output-document=- "$URL"|') || die "wget: \$!";
# 	#open(URLHANDLE, '/usr/bin/snarf "$URL" -|') || die "snarf: \$!";
# 	open(URLHANDLE, '/usr/bin/curl "$URL"|') || die "curl: \$!";
# 	my \$text = "";
# 	while(sysread(URLHANDLE,\$text, 1024) > 0)
# 	{
# 		\$Page .= \$text;
# 	};
# 	close(URLHANDLE) || die "\$!";
# However, this doesn't work with the CGIexecute->evaluate() function.
# You get an error: 'No child processes at (eval 16) line 15, <file0> line 8.'
#
# You can forget the next two variables, they are only needed when
# you don't want to use a regular file system (i.e., with open)
# but use some kind of database/RAM image for accessing (generating)
# the data.
#
# Name of the environment variable that contains the file contents 
# when reading directly from Database/RAM. When this environment variable,
# $ENV{$CGI_FILE_CONTENTS}, is not false, no real file will be read. 
$CGI_FILE_CONTENTS = 'CGI_FILE_CONTENTS';
# Uncomment the following if you want to force the use of the data access code
# $ENV{$CGI_FILE_CONTENTS} = '-';  # Force use of $ENV{$CGI_DATA_ACCESS_CODE}
#
# Name of the environment variable that contains the RAM access perl
# code needed to read additional "files", i.e., 
# $ENV{$CGI_FILE_CONTENTS} = eval("\@_=('$file_path'); do{$ENV{$CGI_DATA_ACCESS_CODE}}");
# When $ENV{$CGI_FILE_CONTENTS} eq '-', this code is executed to generate the data.
$CGI_DATA_ACCESS_CODE = 'CGI_DATA_ACCESS_CODE';
#
# You can, of course, fill this yourself, e.g.,
# $ENV{$CGI_DATA_ACCESS_CODE} = 
# 'open(INPUT, "<$_[0]"); while(<INPUT>){print;};close(INPUT);'
#
#
# DEBUGGING
#
# Suppress error messages, this can be changed for debugging or error-logging
#open(STDERR, "/dev/null"); # (comment out for use in debugging)
#
# SPECIAL: Remove Comments, security, etc. if the command line is
# '>CGIscriptor.pl -slim >slimCGIscriptor.pl'
$TrimDownCGIscriptor = 1 if $ARGV[0] =~ /^\-slim/i; 

# If CGIscriptor is used from the command line, the command line 
# arguments are interpreted as the file (1st) and the Query String (rest).
# Get the arguments
$ENV{'PATH_INFO'} = shift(@ARGV) unless exists($ENV{'PATH_INFO'}); 
$ENV{'QUERY_STRING'} = join("&", @ARGV) unless exists($ENV{'QUERY_STRING'});
#
# End of optional user configuration
# (note: there is more non-essential user configuration below)
#
###############################################################################
#
# Author and Copyright (c):
# Rob van Son, © 1995,1996,1997,1998,1999,2000,2001,2002
# Institute of Phonetic Sciences & IFOTT/ACLS
# University of Amsterdam
# Herengracht 338
# NL-1016CG Amsterdam, The Netherlands 
# Email: Rob.van.Son@hum.uva.nl
#        rob.van.son@workmail.com
# WWW  : http://www.fon.hum.uva.nl/rob/
# mail:  Institute of Phonetic Sciences
#        University of Amsterdam
#        Herengracht 338
#        NL-1016CG Amsterdam
#        The Netherlands
#        tel +31 205252183
#        fax +31 205252197
#
# License for use and disclaimers
#
# CGIscriptor merges plain ASCII HTML files transparantly  
# with CGI variables, in-line PERL code, shell commands, 
# and executable scripts in other scripting languages. 
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#
# Contributors:
# Rob van Son (Rob.van.Son@hum.uva.nl) 
# Gerd Franke franke@roo.de (designed the <DIV> behaviour)
#
#######################################################>>>>>>>>>>Start Remove
#
# You can skip the following code, it is an auto-splice
# procedure.
#
# Construct a slimmed down version of CGIscriptor 
# (i.e., CGIscriptor.pl -slim > slimCGIscriptor.pl)
#
if($TrimDownCGIscriptor)
{
    open(CGISCRIPTOR, "<CGIscriptor.pl") 
    || die "<CGIscriptor.pl not slimmed down: $!\n";
    my $SKIPtext = 0;
    my $SKIPComments = 0;
    
    while(<CGISCRIPTOR>)
    {
        my $SKIPline = 0;
        
        ++$LineCount;
        
        # Start of SKIP text
        $SKIPtext = 1 if /[\>]{10}Start Remove/;
        $SKIPComments = 1 if $SKIPtext == 1;
        
        # Skip this line?
        $SKIPline = 1 if $SKIPtext || ($SKIPComments && /^\s*\#/);
        
        ++$PrintCount unless $SKIPline;
        
        print STDOUT $_ unless $SKIPline;
        
        # End of SKIP text ?
        $SKIPtext = 0 if /[\<]{10}End Remove/;
    };
    # Ready!
    print STDERR "\# Printed $PrintCount out of $LineCount lines\n";
    exit;
};
#
#######################################################
#
# HYPE
#
# CGIscriptor merges plain ASCII HTML files transparantly and safely 
# with CGI variables, in-line PERL code, shell commands, and executable 
# scripts in many languages (on-line and real-time). It combines the 
# "ease of use" of HTML files with the versatillity of specialized 
# scripts and PERL programs. It hides all the specifics and 
# idiosyncrasies of correct output and CGI coding and naming. Scripts 
# do not have to be aware of HTML, HTTP, or CGI conventions just as HTML 
# files can be ignorant of scripts and the associated values. CGIscriptor 
# complies with the W3C HTML 4.0 recommendations.
# In addition to its use as a WWW embeded CGI processor, it can
# be used as a command-line document preprocessor (text-filter).
#
# THIS IS HOW IT WORKS
#
# The aim of CGIscriptor is to execute "plain" scripts inside a text file
# using any required CGIparameters and environment variables. It 
# is optimized to transparantly process HTML files inside a WWW server.
# The native language is Perl, but many other scripting languages
# can be used.
# 
# CGIscriptor reads text files from the requested input file (i.e., from
# $YOUR_HTML_FILES$PATH_INFO) and writes them to <STDOUT> (i.e., the 
# client requesting the service) preceded by the obligatory 
# "Content-type: text/html\n\n" or "Content-type: text/plain\n\n" string
# (except for "raw" files which supply their own Content-type message
# and only if the SERVER_PROTOCOL supports HTTP, MAIL, or MIME).
#
# When CGIscriptor encounters an embedded script, indicated by an HTML4 tag
#
# <SCRIPT TYPE="text/ssperl" [CGI="$VAR='default value'"] [SRC="ScriptSource"]>
# PERL script
# </SCRIPT> 
#
# or
# 
# <SCRIPT TYPE="text/osshell" [CGI="$name='default value'"] [SRC="ScriptSource"]>
# OS Shell script
# </SCRIPT> 
# 
# construct (anything between []-brackets is optional, other MIME-types
# and scripting languages are supported), the embedded script is removed 
# and both the contents of the source file (i.e., "do 'ScriptSource'") 
# AND the script are evaluated as a PERL program (i.e., by eval()), 
# shell script (i.e., by a "safe" version of `Command`, qx) or an external 
# interpreter. The output of the eval() function takes the place of the 
# original <SCRIPT></SCRIPT> construct in the output string. Any CGI 
# parameters declared by the CGI attribute are available as simple perl 
# variables, and can subsequently be made available as variables to other 
# scripting languages (e.g., bash, python, or lisp).
# 
# Example: printing "Hello World"
# <HTML><HEAD><TITLE>Hello World</TITLE>
# <BODY>
# <H1><SCRIPT TYPE="text/ssperl">"Hello World"</SCRIPT></H1>
# </BODY></HTML>
# 
# Save this in a file, hello.html, in the directory you indicated with 
# $YOUR_HTML_FILES and access http://your_server/SHTML/hello.html
# (or to whatever name you use as an alias for CGIscriptor.pl). 
# This is realy ALL you need to do to get going.
# 
# You can use any values that are delivered in CGI-compliant form (i.e., 
# the "?name=value" type URL additions) transparently as "$name" variables 
# in your scripts IFF you have declared them in the CGI attribute of 
# a META or SCRIPT tag before e.g.:
# <META CONTENT="text/ssperl; CGI='$name = `default value`' 
# [SRC='ScriptSource']"> 
# or
# <SCRIPT TYPE="text/ssperl" CGI="$name = 'default value'" 
# [SRC='ScriptSource']> 
# After such a 'CGI' attribute, you can use $name as an ordinary PERL variable
# (the ScriptSource file is immediately evaluated with "do 'ScriptSource'"). 
# The CGIscriptor script allows you to write ordinary HTML files which will 
# include dynamic CGI aware (run time) features, such as on-line answers 
# to specific CGI requests, queries, or the results of calculations. 
#
# For example, if you wanted to answer questions of clients, you could write 
# a Perl program called "Answer.pl" with a function "AnswerQuestion()"
# that prints out the answer to requests given as arguments. You then write 
# an HTML page "Respond.html" containing the following fragment:
#
# <center>
# The Answer to your question
# <META CONTENT="text/ssperl; CGI='$Question'">
# <h3><SCRIPT TYPE="text/ssperl">$Question</SCRIPT></h3>
# is 
# <h3><SCRIPT TYPE="text/ssperl" SRC="./PATH/Answer.pl">
#  AnswerQuestion($Question);
# </SCRIPT></h3>
# </center>
# <FORM ACTION=Respond.html METHOD=GET>
# Next question: <INPUT NAME="Question" TYPE=TEXT SIZE=40><br>
# <INPUT TYPE=SUBMIT VALUE="Ask">
# </FORM>
#
# The output could look like the following (in HTML-speak):
# 
# <CENTER>
# The Answer to your question
# <h3>What is the capital of the Netherlands?</h3>
# is
# <h3>Amsterdam</h3>
# </CENTER>
# <FORM ACTION=Respond.html METHOD=GET>
# Next question: <INPUT NAME="Question" TYPE=TEXT SIZE=40><br>
# <INPUT TYPE=SUBMIT VALUE="Ask">
#
# Note that the function "Answer.pl" does know nothing about CGI or HTML,
# it just prints out answers to arguments. Likewise, the text has no 
# provisions for scripts or CGI like constructs. Also, it is completely 
# trivial to extend this "program" to use the "Answer" later in the page 
# to call up other information or pictures/sounds. The final text never 
# shows any cue as to what the original "source" looked like, i.e., 
# where you store your scripts and how they are called.
# 
# There are some extra's. The argument of the files called in a SRC= tag 
# can access the CGI variables declared in the preceding META tag from
# the @ARGV array. Executable files are called as: 
# `file '$ARGV[0]' ... ` (e.g., `Answer.pl \'$Question\'`;)
# The files called from SRC can even be (CGIscriptor) html files which are 
# processed in-line. Furthermore, the SRC= tag can contain a perl block 
# that is evaluated. That is, 
# <META CONTENT="text/ssperl; CGI='$Question' SRC='{$Question}'">
# will result in the evaluation of "print do {$Question};" and the VALUE
# of $Question will be printed. Note that these "SRC-blocks" can be 
# preceded and followed by other file names, but only a single block is 
# allowed in a SRC= tag.
# 
# One of the major hassles of dynamic WWW pages is the fact that several
# mutually incompatible browsers and platforms must be supported. For example,
# the way sound is played automatically is different for Netscape and 
# Internet Explorer, and for each browser it is different again on 
# Unix, MacOS, and Windows. Realy dangerous is processing user-supplied 
# (form-) values to construct email addresses, file names, or database
# queries. All Apache WWW-server exploits reported in the media are 
# based on faulty CGI-scripts that didn't check their user-data properly.
#
# There is no panacee for these problems, but a lot of work and problems
# can be safed by allowing easy and transparent control over which 
# <SCRIPT></SCRIPT> blocks are executed on what CGI-data. CGIscriptor
# supplies such a method in the form of a pair of attributes:
# IF='...condition..' and UNLESS='...condition...'. When added to a
# script tag, the whole block (including the SRC attribute) will be
# ignored if the condition is false (IF) or true (UNLESS).
# For example, the following block will NOT be evaluated if the value
# of the CGI variable FILENAME is NOT a valid filename:
#
# <SCRIPT TYPE='text/ssperl' CGI='$FILENAME' 
# IF='CGIscriptor::CGIsafeFileName($FILENAME)'>
# .....
# </SCRIPT>
#
# (the function CGIsafeFileName(String) returns an empty string ("") 
# if the String argument is not a valid filename).
# The UNLESS attribute is the mirror image of IF.
#
# A user manual follows the HTML 4 and security paragraphs below.
# 
##########################################################################
#
# HTML 4 compliance
# 
# In general, CGIscriptor.pl complies with the HTML 4 recommendations of 
# the W3C. This means that any software to manage Web sites will be able
# to handle CGIscriptor files, as will web agents.
# 
# All script code should be placed between <SCRIPT></SCRIPT> tags, the 
# script type is indicated with TYPE="mime-type", the LANGUAGE
# feature is ignored, and a SRC feature is implemented. All CGI specific
# features are delegated to the CGI attribute.
# 
# However, the behavior deviates from the W3C recommendations at some 
# points. Most notably:
#  0- The scripts are executed at the server side, invissible to the 
#     client (i.e., the browser)
#  1- The mime-types are personal and idiosyncratic, but can be adapted.
#  2- Code in the body of a <SCRIPT></SCRIPT> tag-pair is still evaluated 
#     when a SRC feature is present.
#  3- The SRC attribute reads a list of files.
#  4- The files in a SRC attribute are processed according to file type.
#  5- The SRC attribute evaluates inline Perl code.
#  6- Processed META, DIV tags are removed from the output 
#     document.
#  7- All attributes of the processed META tags, except CONTENT, are ignored 
#     (i.e., deleted from the output).
#  8- META tags can be placed ANYWHERE in the document.
#  9- Through the SRC feature, META tags can have visible output in the 
#     document.
# 10- The CGI attribute that declares CGI parameters, can be used
#     inside the <SCRIPT> tag.
# 11- Use of an extended quote set, i.e., '', "", ``, (), {}, []
#     and their \-slashed combinations: \'\', \"\", \`\`, \(\), 
#     \{\}, \[\].
# 12- IF and UNLESS attributes to <SCRIPT>, <META>, <DIV> tags.
# 13- <DIV> tags cannot be nested, DIV tags are not
#     rendered with new-lines.
# 14- The XML style <TAG .... /> is recognized and handled correctly.
#     (i.e., no content is processed)
#    
# The reasons for these choices are:
# You can still write completely HTML4 compliant documents. CGIscriptor 
# will not force you to write "deviant" code. However, it allows you to 
# do so (which is, in fact, just as bad). The prime design principle 
# was to allow users to include plain Perl code. The code itself should 
# be "enhancement free". Therefore, extra features were needed to 
# supply easy access to CGI and Web site components. For security 
# reasons these have to be declared explicitly. The SRC feature 
# transparently manages access to external files, especially the safe 
# use of executable files. 
# The CGI attribute handles the declarations of external (CGI) variables
# in the SCRIPT and META tag's.
# EVERYTHING THE CGI ATTRIBUTE AND THE META TAG DO CAN BE DONE INSIDE 
# A <SCRIPT></SCRIPT> TAG CONSTRUCT.
# 
# The reason for the IF, UNLESS, and SRC attributes (and their Perl code 
# evaluation) were build into the META and SCRIPT tags is part laziness, 
# part security. The SRC blocks allows more compact documents and easier 
# debugging. The values of the CGI variables can be immediately screened 
# for security by IF or UNLESS conditions, and even SRC attributes (e.g., 
# email addresses and file names), and a few commands can be called 
# without having to add another Perl TAG pair. This is especially important
# for documents that require the use of other (more restricted) "scripting"
# languages and facilities that lag transparent control structures.
#
##########################################################################
#
# SECURITY
#
# Your WWW site is a few keystrokes away from a few hundred million internet 
# users. A fair percentage of these users knows more about your computer 
# than you do. And some of these just might have bad intentions.
# 
# To ensure uncompromized operation of your server and platform, several 
# features are incorporated in CGIscriptor.pl to enhance security.
# First of all, you should check the source of this program. No security
# measures will help you when you download programs from anonymous sources.
# If you want to use THIS file, please make sure that it is uncompromized.
# The best way to do this is to contact the source and try to determine
# whether s/he is reliable (and accountable).
# 
# BE AWARE THAT ANY PROGRAMMER CAN CHANGE THIS PROGRAM IN SUCH A WAY THAT
# IT WILL SET THE DOORS TO YOUR SYSTEM WIDE OPEN
# 
# I would like to ask any user who finds bugs that could compromise 
# security to report them to me (and any other bug too,
# Email: Rob.van.Son@hum.uva.nl or rob.van.son@workmail.com).
#
# Security features
#
# 1 Invisibility  
#   The inner workings of the HTML source files are completely hidden  
#   from the client. Only the HTTP header and the ever changing content 
#   of the output distinguish it from the output of a plain, fixed HTML
#   file. Names, structures, and arguments of the "embedded" scripts 
#   are invisible to the client. Error output is suppressed except
#   during debugging (user configurable).
#
# 2 Separate directory trees
#   Directories containing Inline text and script files can reside on
#   separate trees, distinct from those of the HTTP server. This means
#   that NEITHER the text files, NOR the script files can be read by
#   clients other than through CGIscriptor.pl, UNLESS they are 
#   EXPLICITELY made available. 
#
# 3 Requests are NEVER "evaluated"
#   All client supplied values are used as literal values (''-quoted). 
#   Client supplied ''-quotes are ALWAYS removed. Therefore, as long as the 
#   embedded scripts do NOT themselves evaluate these values, clients CANNOT 
#   supply executable commands. Be sure to AVOID scripts like:
#   
#   <META CONTENT="text/ssperl; CGI='$UserValue'">
#   <SCRIPT TYPE="text/ssperl">$dir = `ls -1 $UserValue`;</SCRIPT>
#   
#   These are a recipe for disaster. However, the following quoted
#   form should be save (but is still not adviced):
#   
#   <SCRIPT TYPE="text/ssperl">$dir = `ls -1 \'$UserValue\'`;</SCRIPT>
#   
#   A special function, SAFEqx(), will automatically do exactly this, 
#   e.g., SAFEqx('ls -1 $UserValue') will execute `ls -1 \'$UserValue\'`
#   with $UserValue interpolated. I recommend to use SAFEqx() instead
#   of backticks whenever you can. The OS shell scripts inside
#     
#   <SCRIPT TYPE="text/osshell">ls -1 $UserValue</SCRIPT> 
#   
#   are handeld by SAFEqx and automatically ''-quoted.
#
# 4 Logging of requests
#   All requests can be logged separate from the Host server. The level of
#   detail is user configurable: Including or excluding the actual queries. 
#   This allows for the inspection of (im-) proper use.
#
# 5 Access control: Clients
#   The Remote addresses can be checked against a list of authorized 
#   (i.e., accepted) or non-authorized (i.e., rejected) clients. Both 
#   REMOTE_HOST and REMOTE_ADDR are tested so clients without a proper 
#   HOST name can be (in-) excluded by their IP-address. Client patterns 
#   containing all numbers and dots are considered IP-addresses, all others
#   domain names. No wild-cards or regexp's are allowed, only partial 
#   addresses.
#   Matching of names is done from the back to the front (domain first, 
#   i.e., $REMOTE_HOST =~ /\Q$pattern\E$/is), so including ".edu" will 
#   accept or reject all clients from the domain EDU. Matching of 
#   IP-addresses is done from the front to the back (domain first, i.e., 
#   $REMOTE_ADDR =~ /^\Q$pattern\E/is), so including "128." will (in-) 
#   exclude all clients whose IP-address starts with 128.
#   There are two special symbols: "-" matches HOSTs with no name and "*"
#   matches ALL HOSTS/clients.
#   For those needing more expressional power, lines starting with 
#   "-e" are evaluated by the perl eval() function. E.g., 
#   '-e $REMOTE_HOST =~ /\.edu$/is;' will accept/reject clients from the 
#   domain '.edu'.
#
# 6 Access control: Files
#   In principle, CGIscriptor could read ANY file in the directory 
#   tree as discussed in 1. However, for security reasons this is 
#   restricted to text files. It can be made more restricted by entering 
#   a global file pattern (e.g., ".html"). This is done by default. 
#   For each client requesting access, the file pattern(s) can be made
#   more restrictive than the global pattern by entering client specific
#   file patterns in the Access Control files (see 5).
#   For example: if the ACCEPT file contained the lines
#   *           DEMO
#   .hum.uva.nl LET 
#   145.18.230.     
#   Then all clients could request paths containing "DEMO" or "demo", e.g. 
#   "/my/demo/file.html" ($PATH_INFO =~ /\Q$pattern\E/), Clients from 
#   *.hum.uva.nl could also request paths containing  "LET or "let", e.g. 
#   "/my/let/file.html", and clients from the local cluster 
#   145.18.230.[0-9]+ could access ALL files.
#   Again, for those needing more expressional power, lines starting with 
#   "-e" are evaluated. For instance: 
#   '-e $REMOTE_HOST =~ /\.edu$/is && $PATH_INFO =~ m@/DEMO/@is;' 
#   will accept/reject requests for files from the directory "/demo/" from
#   clients from the domain '.edu'.
#   
# 7 Query length limiting
#   The length of the Query string can be limited. If CONTENT_LENGTH is larger
#   than this limit, the request is rejected. The combined length of the 
#   Query string and the POST input is checked before any processing is done. 
#   This will prevent clients from overloading the scripts.
#   The actual, combined, Query Size is accessible as a variable through 
#   $CGI_Content_Length.
#  
# 8 Illegal filenames, paths, and protected directories
#   One of the primary security concerns in handling CGI-scripts is the
#   use of "funny" characters in the requests that con scripts in executing
#   malicious commands. Examples are inserting ';', null bytes, or <newline> 
#   characters in URL's and filenames, followed by executable commands. A  
#   special variable $FileAllowedChars stores a string of all allowed
#   characters. Any request that translates to a filename with a character 
#   OUTSIDE this set will be rejected.
#   In general, all (readable files) in the DocumentRoot tree are accessible.
#   This might not be what you want. For instance, your DocumentRoot directory
#   might be the working directory of a CVS project and contain sensitive
#   information (e.g., the password to get to the repository). You can block
#   access to these subdirectories by adding the corresponding patterns to
#   the $BlockPathAccess variable. For instance, $BlockPathAccess = '/CVS/'
#   will block any request that contains '/CVS/' or: 
#   die if $BlockPathAccess && $ENV{'PATH_INFO'} =~ m@$BlockPathAccess@;
#  
# 9 The execution of code blocks can be controlled in a transparent way
#   by adding IF or UNLESS conditions in the tags themselves. That is,
#   a simple check of the validity of filenames or email addresses can
#   be done before any code is executed.
#
###############################################################################
#
# USER MANUAL (sort of)
#
# CGIscriptor removes embedded scripts, indicated by an HTML 4 type 
# <SCRIPT TYPE='text/ssperl'> </SCRIPT> or <SCRIPT TYPE='text/osshell'> 
# </SCRIPT> constructs. CGIscriptor also recognizes XML-type 
# <SCRIPT TYPE='text/ssperl'/> constructs. These are usefull when
# the necessary code is already available in the TAG itself (e.g.,
# using external files). The contents of the directive are executed by 
# the PERL eval() and `` functions (in a separate name space). The 
# result of the eval() function replaces the <SCRIPT> </SCRIPT> construct 
# in the output file. You can use the values that are delivered in 
# CGI-compliant form (i.e., the "?name=value&.." type URL additions) 
# transparently as "$name" variables in your directives after they are 
# defined in a <META> or <SCRIPT> tag. 
# If you define the variable "$CGIscriptorResults" in a CGI attribute, all 
# subsequent <SCRIPT> and <META> results (including the defining 
# tag) will also be pushed onto a stack: @CGIscriptorResults. This list 
# behaves like any other, ordinary list and can be manipulated.
#
# Both GET and POST requests are accepted. These two methods are treated
# equal. Variables, i.e., those values that are determined when a file is
# processed, are indicated in the CGI attribute by $<name> or $<name>=<default>
# in which  <name> is the name of the variable and <default> is the value
# used when there is NO current CGI value for <name> (you can use 
# white-spaces in $<name>=<default> but really DO make sure that the 
# default value is followed by white space or is quoted). Names can contain 
# any alphanumeric characters and _ (i.e., names match /[\w]+/).
# If the Content-type: is 'multipart/*', the input is treated as a
# MIME multipart message and automatically delimited. CGI variables get 
# the "raw" (i.e., undecoded) body of the corresponding message part. 
#
# Variables can be CGI variables, i.e., those from the QUERY_STRING, 
# environment variables, e.g., REMOTE_USER, REMOTE_HOST, or REMOTE_ADDR, 
# or predefined values, e.g., CGI_Decoded_QS (The complete, decoded, 
# query string), CGI_Content_Length (the length of the decoded query 
# string), CGI_Year, CGI_Month, CGI_Time, and CGI_Hour (the current 
# date and time).
# 
# All these are available when defined in a CGI attribute. All environment 
# variables are accessible as $ENV{'name'}. So, to access the REMOTE_HOST 
# and the REMOTE_USER, use, e.g.: 
# 
# <SCRIPT TYPE='text/ssperl'>
# ($ENV{'REMOTE_HOST'}||"-")." $ENV{'REMOTE_USER'}"
# </SCRIPT>
# 
# (This will print a "-" if REMOTE_HOST is not known)
# Another way to do this is:
# 
# <META CONTENT="text/ssperl; CGI='$REMOTE_HOST = - $REMOTE_USER'">
# <SCRIPT TYPE='text/ssperl'>"$REMOTE_HOST $REMOTE_USER"</SCRIPT>
# or
# <META CONTENT='text/ssperl; CGI="$REMOTE_HOST = - $REMOTE_USER"
#  SRC={"$REMOTE_HOST $REMOTE_USER\n"}'>
#  
# This is possible because ALL environment variables are available as 
# CGI variables. The environment variables take precedence over CGI 
# names in case of a "name clash". For instance:  
# <META CONTENT="text/ssperl; CGI='$HOME' SRC={$HOME}">
# Will print the current HOME directory (environment) irrespective whether
# there is a CGI variable from the query 
# (e.g., Where do you live? <INPUT TYPE="TEXT" NAME="HOME">)
# THIS IS A SECURITY FEATURE. It prevents clients from changing
# the values of defined environment variables (e.g., by supplying
# a bogus $REMOTE_ADDR). Although $ENV{} is not changed by the META tags, 
# it would make the use of declared variables insecure. You can still 
# access CGI variables after a name clash with 
# CGIscriptor::CGIparseValue(<name>).
#
# Some CGI variables are present several times in the query string
# (e.g., from multiple selections). These should be defined as
# @VARIABLENAME=default in the CGI attribute. The list @VARIABLENAME
# will contain ALL VARIABLENAME values from the query, or a single
# default value. If there is an ENVIRONMENT variable of the
# same name, it will be used instead of the default AND the query
# values. The corresponding function is 
# CGIscriptor::CGIparseValueList(<name>)
# 
# CGI variables collected in a @VARIABLENAME list are unordered.
# When more structured variables are needed, a hash table can be used.
# A variable defined as %VARIABLE=default will collect all
# CGI-parameters whose name start with 'VARIABLE' in a hash table with
# the remainder of the name as a key. For instance, %PERSON will 
# collect PERSONname='John Doe', PERSONbirthdate='01 Jan 00', and
# PERSONspouse='Alice' into a hash table %PERSON such that $PERSON{'spouse'}
# equals 'Alice'. Any default value or environment value will be stored
# under the "" key. If there is an ENVIRONMENT variable of the same name, 
# it will be used instead of the default AND the query values. The 
# corresponding function is CGIscriptor::CGIparseValueHash(<name>)
# 
# This method of first declaring your environment and CGI variables
# before being able to use them in the scripts might seem somewhat 
# clumsy, but it protects you from inadvertedly printing out the values of 
# system environment variables when their names coincide with those used 
# in the CGI forms.  It also prevents "clients" from supplying CGI 
# parameter values for your private variables.
# THIS IS A SECURITY FEATURE!
#
#
# NON-HTML CONTENT TYPES
#
# Normally, CGIscriptor prints the standard "Content-type: text/html\n\n"
# message before anything is printed. This has been extended to include
# plain text (.txt) files, for which the Content-type (MIME type) 
# 'text/plain' is printed. In all other respects, text files are treated
# as HTML files (this can be switched off by removing '.txt' from the 
# $FilePattern variable) . When the content type should be something else, 
# e.g., with multipart files, use the $RawFilePattern (.xmr, see also next 
# item). CGIscriptor will not print a Content-type message for this file 
# type (which must supply its OWN Content-type message). Raw files must
# still conform to the <SCRIPT></SCRIPT> and <META> tag specifications.
# 
# 
# NON-HTML FILES
# 
# CGIscriptor is intended to process HTML and text files only. You can 
# create documents of any mime-type on-the-fly using "raw" text files, 
# e.g.,  with the .xmr extension. However, CGIscriptor will not process 
# binary files of any type, e.g., pictures or sounds. Given the sheer 
# number of formats, I do not have any intention to do so. However, 
# an escape route has been provided. You can construct a genuine raw 
# (.xmr) text file that contains the perl code to service any file type 
# you want. If the global $BinaryMapFile variable contains the path to 
# this file (e.g., /BinaryMapFile.xmr), this  file will be called 
# whenever an unsupported (non-HTML) file type is  requested. The path 
# to the requested binary file is stored in  $ENV('CGI_BINARY_FILE') 
# and can be used like any other CGI-variable. Servicing binary files 
# then becomes supplying the correct Content-type (e.g., print 
# "Content-type: image/jpeg\n\n";) and reading the file and writing it 
# to STDOUT (e.g., using sysread() and syswrite()).
# 
# 
# THE META TAG
# 
# All attributes of a META tag are ignored, except the 
# CONTENT='text/ssperl; CGI=" ... " [SRC=" ... "]' attribute. The string
# inside the quotes following the CONTENT= indication (white-space is
# ignored, "" '' `` (){}[]-quote pairs are allowed, plus their \ versions) 
# MUST start with any of the CGIscriptor mime-types (e.g.: text/ssperl or 
# text/osshell) and a comma or semicolon. 
# The quoted string following CGI= contains a white-space separated list 
# of declarations of the CGI (and Environment) values and default values 
# used when no CGI values are supplied by the query string.
#
# If the default value is a longer string containing special characters, 
# possibly spanning several lines, the string must be enclosed in quotes. 
# You may use any pair of quotes or brackets from the list '', "", ``, (), 
# [], or {} to distinguish default values (or preceded by \, e.g., \(...\) 
# is different from (...)). The outermost pair will always be used and any 
# other quotes inside the string are considered to be part of the string 
# value, e.g., 
#
# $Value = {['this'
# "and" (this)]} 
# will result in $Value getting the default value: ['this'
# "and" (this)]
# (NOTE that the newline is part of the default value!).
#
# Internally, for defining and initializing CGI (ENV) values, the META 
# and SCRIPT tags use the functions "defineCGIvariable($name, $default)" 
# (scalars) and "defineCGIvariableList($name, $default)" (lists). 
# These functions can be used inside scripts as 
# "CGIscriptor::defineCGIvariable($name, $default)" and
# "CGIscriptor::defineCGIvariableList($name, $default)".
# "CGIscriptor::defineCGIvariableHash($name, $default)".
#
# The CGI attribute will be processed exactly identical when used inside
# the <SCRIPT> tag. However, this use is not according to the 
# HTML 4.0 specifications of the W3C.
#
#
# THE DIV TAGS
#
# There is a problem when constructing html files containing
# server-side perl scripts with standard HTML tools. These
# tools will refuse to process any text between <SCRIPT></SCRIPT>
# tags. This is quite annoying when you want to use large
# HTML templates where you will fill in values.
#
# For this purpose, CGIscriptor will read the neutral 
# <DIV CLASS="text/ssperl" ID="varname"></DIV>
# tag (in Cascading Style Sheet manner) Note that 
# "varname" has NO '$' before it, it is a bare name. 
# Any text between these <DIV ...></DIV> tags will 
# be assigned to '$varname' as is (e.g., as a literal). 
# No processing or interpolation will be performed. 
# There is also NO nesting possible. Do NOT nest a
# </DIV> inside a <DIV></DIV>! Moreover, DIV tags do 
# NOT ensure a block structure in the final rendering 
# (i.e., no empty lines).
#
# Note that <DIV CLASS="text/ssperl" ID="varname"/>
# is handled the XML way. No content is processed,
# but varname is defined, and any SRC directives are
# processed.
#
# You can use $varname like any other variable name. 
# However, $varname is NOT a CGI variable and will be 
# completely internal to your script. There is NO 
# interaction between $varname and the outside world.
#
# To interpolate a DIV derived text, you can use:
# $varname =~ s/([\]])/\\\1/g; # Mark ']'-quotes
# $varname = eval("qq[$varname]"); # Interpolate all values
#
# The DIV tags will process IF, UNLESS, CGI and 
# SRC attributes. The SRC files will be pre-pended to the
# body text of the tag. SRC blocks are NOT executed.
#
# CONDITIONAL PROCESSING: THE 'IF' AND 'UNLESS' ATTRIBUTES
#
# It is often necessary to include code-blocks that should be executed
# conditionally, e.g., only for certain browsers or operating system.
# Furthermore, quite often sanity and security checks are necessary
# before user (form) data can be processed, e.g., with respect to
# email addresses and filenames.
#
# Checks added to the code are often difficult to find, interpret or 
# maintain and in general mess up the code flow. This kind of confussion 
# is dangerous. 
# Also, for many of the supported "foreign" scripting languages, adding 
# these checks is cumbersome or even impossible. 
#
# As a uniform method for asserting the correctness of "context", two 
# attributes are added to all supported tags: IF and UNLESS. 
# They both evaluate their value and block execution when the
# result is <FALSE> (IF) or <TRUE> (UNLESS) in Perl, e.g., 
# UNLESS='$NUMBER \> 100;' blocks execution if $NUMBER <= 100. Note that
# the backslash in the '\>' is removed and only used to differentiate 
# this conditional '>' from the tag-closing '>'. For symmetry, the
# backslash in '\<' is also removed. Inside these conditionals, 
# ~/ and ./ are expanded to their respective directory root paths.
#
# For example, the following tag will be ignored when the filename is 
# invalid:
#
# <SCRIPT TYPE='text/ssperl' CGI='$FILENAME' 
# IF='CGIscriptor::CGIsafeFileName($FILENAME);'>
# ...
# </SCRIPT>
#
# The IF and UNLESS values must be quoted. The same quotes are supported
# as with the other attributes. The SRC attribute is ignored when IF and 
# UNLESS block execution.
#
# NOTE: 'IF' and 'UNLESS' always evaluate perl code.
#
#
# THE MAGIC SOURCE ATTRIBUTE (SRC=)
# 
# The SRC attribute inside tags accepts a list of filenames and URL's
# separated by "," comma's (or ";" semicolons). 
# ALL the variable values defined in the CGI attribute are available 
# in @ARGV as if the file or block was executed from the command line, 
# in the exact order in which they were declared in the preceding CGI 
# attribute.
# 
# First, a SRC={}-block will be evaluated as if the code inside the 
# block was part of a <SCRIPT></SCRIPT> construct, i.e.,
# "print do { code };'';" or `code` (i.e., SAFEqx('code)). 
# Only a single block is evaluated. Note that this is processed less 
# efficiently than <SCRIPT> </SCRIPT> blocks. Type of evaluation 
# depends on the content-type: Perl for text/ssperl and OS shell for 
# text/osshell. For other mime types (scripting languages), anything in 
# the source block is put in front of the code block "inside" the tag.
#
# Second, executable files (i.e., -x filename != 0) are evaluated as:
# print `filename \'$ARGV[0]\' \'$ARGV[1]\' ...`
# That is, you can actually call executables savely from the SRC tag.
# 
# Third, text files that match the file pattern, used by CGIscriptor to
# check whether files should be processed ($FilePattern), are 
# processed in-line (i.e., recursively) by CGIscriptor as if the code
# was inserted in the original source file. Recursions, i.e., calling
# a file inside itself, are blocked. If you need them, you have to code
# them explicitely using "main::ProcessFile($file_path)".
# 
# Fourth, Perl text files (i.e., -T filename != 0) are evaluated as: 
# "do FileName;'';".
#
# Last, URL's (i.e., starting with 'HTTP://', 'FTP://', 'GOPHER://', 
# 'TELNET://', 'WHOIS://' etc.) are loaded
# and printed. The loading and handling of <BASE> and document header 
# is done by a command generated by main::GET_URL($URL [, 0]). You can enter your 
# own code (default is curl, wget, or snarf and some post-processing to add a <BASE> tag).
#
# There are two pseudo-file names: PREFIX and POSTFIX. These implement
# a switch from prefixing the SRC code/files (PREFIX, default) before the
# content of the tag to appending the code after the content of the tag
# (POSTFIX). The switches are done in the order in which the PREFIX and 
# POSTFIX labels are encountered. You can mix PREFIX and POSTFIX labels 
# in any order with the SRC files. Note that the ORDER of file execution 
# is determined for prefixed and postfixed files seperately.
#
# File paths can be preceded by the URL protocol prefix "file://". This
# is simply STRIPPED from the name.
# 
# Example:
# The request 
# "http://cgi-bin/Action_Forms.pl/Statistics/Sign_Test.html?positive=8&negative=22
# will result in printing "${SS_PUB}/Statistics/Sign_Test.html"
# With QUERY_STRING = "positive=8&negative=22"
#
# on encountering the lines:
# <META CONTENT="text/osshell; CGI='$positive=11 $negative=3'">
# <b><SCRIPT LANGUAGE=PERL TYPE="text/ssperl" SRC="./Statistics/SignTest.pl">
#  </SCRIPT></b><p>"
#
# This line will be processed as:
# "<b>`${SS_SCRIPT}/Statistics/SignTest.pl '8' '22'`</b><p>"
#
# In which "${SS_SCRIPT}/Statistics/SignTest.pl" is an executable script, 
# This line will end up printed as:
# "<b>p <= 0.0161</b><p>"
#
# Note that the META tag itself will never be printed, and is invisible to 
# the outside world.
#
# The SRC files in a DIV tag will be added (pre-pended) to the body
# of the <DIV></DIV> tag. Blocks are NOT executed! If you do not 
# need any content, you can use the <DIV...../> format.
# 
# 
# THE CGISCRIPTOR ROOT DIRECTORIES ~/ AND ./
# 
# Inside <SCRIPT></SCRIPT> tags, filepaths starting 
# with "~/" are replaced by "$YOUR_HTML_FILES/", this way files in the 
# public directories can be accessed without direct reference to the 
# actual paths. Filepaths starting with "./" are replaced by 
# "$YOUR_SCRIPTS/" and this should only be used for scripts. 
#
# Note: this replacement can seriously affect Perl scripts. Watch
# out for constructs like $a =~ s/aap\./noot./g, use 
# $a =~ s@aap\.@noot.@g instead.
#
# CGIscriptor.pl will assign the values of $SS_PUB and $SS_SCRIPT
# (i.e., $YOUR_HTML_FILES and $YOUR_SCRIPTS) to the environment variables 
# $SS_PUB and $SS_SCRIPT. These can be accessed by the scripts that are 
# executed.
# Values not preceded by $, ~/, or ./ are used as literals 
#
#
# OS SHELL SCRIPT EVALUATION (CONTENT-TYPE=TEXT/OSSHELL)
#
# OS scripts are executed by a "safe" version of the `` operator (i.e., 
# SAFEqx(), see also below) and any output is printed. CGIscriptor will 
# interpolate the script and replace all user-supplied CGI-variables by 
# their ''-quoted values (actually, all variables defined in CGI attributes 
# are quoted). Other Perl variables are interpolated in a simple fasion, 
# i.e., $scalar by their value, @list by join(' ', @list), and %hash by 
# their name=value pairs. Complex references, e.g., @$variable, are all 
# evaluated in a scalar context. Quotes should be used with care. 
# NOTE: the results of the shell script evaluation will appear in the
# @CGIscriptorResults stack just as any other result.
# All occurrences of $@% that should NOT be interpolated must be 
# preceeded by a "\". Interpolation can be switched off completely by 
# setting $CGIscriptor::NoShellScriptInterpolation = 1
# (set to 0 or undef to switch interpolation on again)
# i.e.,
# <SCRIPT TYPE="text/ssperl">
# $CGIscriptor::NoShellScriptInterpolation = 1;
# </SCRIPT>
#
#
# EVALUATION OF OTHER SCRIPTING LANGUAGES
#
# Adding a MIME-type and an interpreter command to 
# %ScriptingLanguages automatically will catch any other 
# scripting language in the standard 
# <SCRIPT TYPE="[mime]"></SCRIPT> manner.
# E.g., adding: $ScriptingLanguages{'text/sspython'} = 'python';
# will actually execute the folowing code in an HTML page
# (ignore 'REMOTE_HOST' for the moment):
# <SCRIPT TYPE="text/sspython">
# # A Python script
# x = ["A","real","python","script","Hello","World","and", REMOTE_HOST]
# print x[4:8] # Prints the list ["Hello","World","and", REMOTE_HOST]
# </SCRIPT>
#
# The script code is NOT interpolated by perl, EXCEPT for those 
# interpreters that cannot handle variables themselves.
# Currently, several interpreters are pre-installed: 
# 
# Perl test -  "text/testperl" => 'perl',  
# Python    -  "text/sspython" => 'python', 
# Ruby      -  "text/ssruby"   => 'ruby',  
# Tcl       -  "text/sstcl"    => 'tcl',    
# Awk       -  "text/ssawk"    => 'awk -f-',  
# Gnu Lisp  -  "text/sslisp"   => 'rep | tail +5 '.
#                                 "| egrep -v '> |^rep. |^nil\\\$'",      
# XLispstat -  "text/xlispstat" => 'xlispstat | tail +7 '.
#                                "| egrep -v '> \\\$|^NIL'",      
# Gnu Prolog-  "text/ssprolog" => 'gprolog',  
# M4 macro's-  "text/ssm4"     => 'm4',
# Born shell-  "text/sh"       => 'sh', 
# Bash      -  "text/bash"     => 'bash',
# C-shell   -  "text/csh"      => 'csh',
# Korn shell-  "text/ksh"      => 'ksh',
# Praat     -  "text/sspraat"    => "praat - | sed 's/Praat > //g'",            
# R         -  "text/ssr" => "R --vanilla --slave | sed 's/^[\[0-9\]*] //g'",   
# REBOL     -   "text/ssrebol" => 
#               "rebol --quiet|egrep -v '^[> ]* == '|sed 's/^\s*\[> \]* //g'", 
# PostgreSQL-  "text/postgresql" => 'psql 2>/dev/null',
# (psql)
#
# Note that the "value" of $ScriptingLanguages{mime} must be a command
# that reads Standard Input and writes to standard output. Any extra
# output of interactive interpreters (banners, echo's, prompts)
# should be removed by piping the output through 'tail', 'grep',
# 'sed', or even 'awk' or 'perl'.
#
# For access to CGI variables there is a special hashtable:
# %ScriptingCGIvariables. 
# CGI variables can be accessed in three ways. 
# 1. If the mime type is not present in %ScriptingCGIvariables, 
# nothing is done and the script itself should parse the relevant 
# environment variables.
# 2. If the mime type IS present in %ScriptingCGIvariables, but it's
# value is empty, e.g., $ScriptingCGIvariables{"text/sspraat"}  = '';,
# the script text is interpolated by perl. That is, all $var, @array,
# %hash, and \-slashes are replaced by their respective values.
# 3. In all other cases, the CGI and environment variables are added
# in front of the script according to the format stored in 
# %ScriptingCGIvariables. That is, the following (pseudo-)code is 
# executed for each CGI- or Environment variable defined in the CGI-tag:
# printf(INTERPRETER, $ScriptingCGIvariables{$mime}, $CGI_NAME, $CGI_VALUE);
#
# For instance, "text/testperl" => '$%s = "%s";' defines variable
# definitions for Perl, and "text/sspython" => '%s = "%s"' for Python
# (note that these definitions are not save, the real ones contain '-quotes).
# 
# THIS WILL NOT WORK FOR @VARIABLES, the (empty) $VARIABLES will be used
# instead.
#
# The $CGI_VALUE parameters are "shrubed" of all control characters
# and quotes (by &shrubCGIparameter($CGI_VALUE)) for the options 2 and 3. 
# Control characters are replaced by \0<octal ascii value> (the exception
# is \015, the newline, which is replaced by \n) and quotes 
# and backslashes by their HTML character
# value (' -> &#39; ` -> &#96; " -> &quot; \ -> &#92; & -> &amper;). 
# For example:
# if a client would supply the string value  (in standard perl, e.g., 
# \n means <newline>)
# "/dev/null';\nrm -rf *;\necho '"
# it would be processed as 
# '/dev/null&#39;;\nrm -rf *;\necho &#39;'
# (e.g., sh or bash would process the latter more according to your 
# intentions).
# If your intepreter requires different protection measures, you will
# have to supply these in %main::SHRUBcharacterTR (string => translation), 
# e.g., $SHRUBcharacterTR{"\'"} = "&#39;";
#
# Currently, the following definitions are used:
# %ScriptingCGIvariables = (
# "text/testperl" => "\$\%s = '\%s';",    # Perl          $VAR = 'value' (for testing)
# "text/sspython" => "\%s = '\%s'",       # Python        VAR = 'value'
# "text/ssruby"   => '@%s = "%s"',        # Ruby          @VAR = "value"
# "text/sstcl"    => 'set %s "%s"',       # TCL           set VAR "value"
# "text/ssawk"    => '%s = "%s";',        # Awk           VAR = "value"; 
# "text/sslisp"   => '(setq %s "%s")',    # Gnu lisp (rep) (setq VAR "value")
# "text/xlispstat"   => '(setq %s "%s")',         # Xlispstat (setq VAR "value")
# "text/ssprolog" => '',                  # Gnu prolog    (interpolated)
# "text/ssm4"     => "define(`\%s', `\%s')", # M4 macro's define(`VAR', `value')
# "text/sh"       => "\%s='\%s';",        # Born shell    VAR='value'; 
# "text/bash"     => "\%s='\%s';",        # Born again shell VAR='value';
# "text/csh"      => "\$\%s = '\%s';",    # C shell       $VAR = 'value';
# "text/ksh"      => "\$\%s = '\%s';",    # Korn shell    $VAR = 'value';
# "text/sspraat"  => '',                  # Praat         (interpolation) 
# "text/ssr"      => '%s <- "%s";',       # R             VAR <- "value";
# "text/ssrebol"  => '%s: copy "%s"',     # REBOL         VAR: copy "value"
# "text/postgresql" => '',                # PostgreSQL    (interpolation) 
# "" => ""
# );
#
# Four tables allow fine-tuning of interpreter with code that should be 
# added before and after each code block:
# 
# Code added before each script block
# %ScriptingPrefix = (
# "text/testperl" => "\# Prefix Code;",   # Perl script testing
# "text/ssm4"     =>  'divert(0)'         # M4 macro's (open STDOUT)
# );
# Code added at the end of each script block
# %ScriptingPostfix = (
# "text/testperl" => "\# Postfix Code;",  # Perl script testing
# "text/ssm4"     =>  'divert(-1)'        # M4 macro's (block STDOUT)
# );
# Initialization code, inserted directly after opening (NEVER interpolated)
# %ScriptingInitialization = (
# "text/testperl" => "\# Initialization Code;", # Perl script testing
# "text/ssawk"    => 'BEGIN {',                 # Server Side awk scripts
# "text/sslisp"   => '(prog1 nil ',             # Lisp (rep)
# "text/xlispstat"   => '(prog1 nil ',          # xlispstat
# "text/ssm4"     =>  'divert(-1)'              # M4 macro's (block STDOUT)
# );
# Cleanup code, inserted before closing (NEVER interpolated)
# %ScriptingCleanup = (
# "text/testperl" => "\# Cleanup Code;",  # Perl script testing
# "text/sspraat" => 'Quit',
# "text/ssawk"    => '};',        # Server Side awk scripts
# "text/sslisp"   =>  '(princ "\n" standard-output)).'   # Closing print to rep
# "text/xlispstat"   =>  '(print "" *standard-output*)).'   # Closing print to xlispstat
# "text/postgresql" => '\q',
# );
#
#
# The SRC attribute is NOT magical for these interpreters. In short,
# all code inside a source file or {} block is written verbattim
# to the interpreter. No (pre-)processing or executional magic is done.
#
# A serious shortcomming of the described mechanism for handling other
# (scripting) languages, with respect to standard perl scripts 
# (i.e., 'text/ssperl'), is that the code is only executed when 
# the pipe to the interpreter is closed. So the pipe has to be 
# closed at the end of each block. This means that the state of the 
# interpreter (e.g., all variable values) is lost after the closing of 
# the next </SCRIPT> tag. The standard 'text/ssperl' scripts retain 
# all values and definitions.
#
# APPLICATION MIME TYPES
#
# To ease some important auxilliary functions from within the
# html pages I have added them as MIME types. This uses
# the mechanism that is also used for the evaluation of
# other scripting languages, with interpolation of CGI
# parameters (and perl-variables). Actually, these are
# defined exactly like any other "scripting language".
#
# text/ssdisplay: display some (HTML) text with interpolated 
#                 variables (uses `cat`).
# text/sslogfile: write (append) the interpolated block to the file
#                 mentioned on the first, non-empty line
#                 (the filename can be preceded by 'File: ',
#                 note the space after the ':', 
#                 uses `awk .... >> <filename>`).
# text/ssmailto:  send email directly from within the script block. 
#                 The first line of the body must contain
#                 To:Name@Valid.Email.Address 
#                 (note: NO space between 'To:' and the email adres)
#                 For other options see the mailto man pages.
#                 It works by directly sending the (interpolated) 
#                 content of the text block to a pipe into the 
#                 Linux program 'mailto'.
#
# In these script blocks, all Perl variables will be 
# replaced by their values. All CGI variables are cleaned before 
# they are used. These CGI variables must be redefined with a 
# CGI attribute to restore their original values.
# In general, this will be more secure than constructing
# e.g., your own email command lines. For instance, Mailto will
# not execute any odd (forged) email addres, but just stops
# when the email address is invalid and awk will construct 
# any filename you give it (e.g. '<File;rm\\\040-f' would end up
# as a "valid" UNIX filename). Note that it will also gladly
# store this file anywhere (/../../../etc/passwd will work!).
# Use the CGIscriptor::CGIsafeFileName() function to clean the 
# filename.
#
# SHELL SCRIPT PIPING
# 
# If a shell script starts with the UNIX style "#! <shell command> \n"
# line, the rest of the shell script is piped into the indicated command, 
# i.e.,
# open(COMMAND, "| command");print COMMAND $RestOfScript; 
#
# In many ways this is equivalent to the MIME-type profiling for 
# evaluating other scripting languages as discussed above. The 
# difference breaks down to convenience. Shell script piping is a 
# "raw" implementation. It allows you to control all aspects of 
# execution. Using the MIME-type profiling is easier, but has a 
# lot of defaults built in that might get in the way. Another
# difference is that shell script piping uses the SAFEqx() function, 
# and MIME-type profiling does not.
# 
# Execution of shell scripts is under the control of the Perl Script blocks
# in the document. The MIME-type triggered execution of <SCRIPT></SCRIPT>
# blocks can be simulated easily. You can switch to a different shell, 
# e.g. tcl, completely by executing the following Perl commands inside 
# your document:
# 
# <SCRIPT TYPE="text/ssperl">
# $main::ShellScriptContentType = "text/ssTcl";     # Yes, you can do this
# CGIscriptor::RedirectShellScript('/usr/bin/tcl'); # Pipe to Tcl
# $CGIscriptor::NoShellScriptInterpolation = 1;
# </SCRIPT>
# 
# After this script is executed, CGIscriptor will parse scripts of
# TYPE="text/ssTcl" and pipe their contents into '|/usr/bin/tcl'
# WITHOUT interpolation (i.e., NO substitution of Perl variables).
# The crucial function is :
# CGIscriptor::RedirectShellScript('/usr/bin/tcl')
# After executing this function, all shell scripts AND all 
# calls to SAFEqx()) are piped into '|/usr/bin/tcl'. If the argument 
# of RedirectShellScript is empty, e.g., '', the original (default) 
# value is reset.
#  
# The standard output, STDOUT, of any pipe is send to the client. 
# Currently, you should be carefull with quotes in such a piped script.
# The results of a pipe is NOT put on the @CGIscriptorResults stack.
# As a result, you do not have access to the output of any piped (#!)
# process! If you want such access, execute 
# <SCRIPT TYPE="text/osshell">echo "script"|command</SCRIPT> 
# or  
# <SCRIPT TYPE="text/ssperl">
# $resultvar = SAFEqx('echo "script"|command');
# </SCRIPT>.
#
# Safety is never complete. Although SAFEqx() prevents some of the 
# most obvious forms of attacks and security slips, it cannot prevent 
# them all. Especially, complex combinations of quotes and intricate 
# variable references cannot be handled safely by SAFEqx. So be on  
# guard.
#
#
# PERL CODE EVALUATION (CONTENT-TYPE=TEXT/SSPERL)
#
# All PERL scripts are evaluated inside a PERL package. This package 
# has a separate name space. This isolated name space protects the 
# CGIscriptor.pl program against interference from user code. However, 
# some variables, e.g., $_, are global and cannot be protected. You are 
# advised NOT to use such global variable names. You CAN write 
# directives that directly access the variables in the main program. 
# You do so at your own risk (there is definitely enough rope available 
# to hang yourself). The behavior of CGIscriptor becomes undefined if 
# you change its private variables during run time. The PERL code 
# directives are used as in: 
# $Result = eval($directive); print $Result;'';
# ($directive contains all text between <SCRIPT></SCRIPT>).
# That is, the <directive> is treated as ''-quoted string and
# the result is treated as a scalar. To prevent the VALUE of the code
# block from appearing on the client's screen, end the directive with 
# ';""</SCRIPT>'. Evaluated directives return the last value, just as 
# eval(), blocks, and subroutines, but only as a scalar.
#
# IMPORTANT: All PERL variables defined are persistent. Each <SCRIPT>
# </SCRIPT> construct is evaluated as a {}-block with associated scope
# (e.g., for "my $var;" declarations). This means that values assigned 
# to a PERL variable can be used throughout the document unless they
# were declared with "my". The following will actually work as intended 
# (note that the ``-quotes in this example are NOT evaluated, but used 
# as simple quotes):
# 
# <META CONTENT="text/ssperl; CGI=`$String='abcdefg'`">
# anything ...
# <SCRIPT TYPE=text/ssperl>@List = split('', $String);</SCRIPT>
# anything ...
# <SCRIPT TYPE=text/ssperl>join(", ", @List[1..$#List]);</SCRIPT>
# 
# The first <SCRIPT TYPE=text/ssperl></SCRIPT> construct will return the 
# value scalar(@List), the second <SCRIPT TYPE=text/ssperl></SCRIPT> 
# construct will print the elements of $String separated by commas, leaving 
# out the first element, i.e., $List[0].
#
# Another warning: './' and '~/' are ALWAYS replaced by the values of 
# $YOUR_SCRIPTS and $YOUR_HTML_FILES, respectively . This can interfere
# with pattern matching, e.g., $a =~ s/aap\./noot\./g will result in the
# evaluations of $a =~ s/aap\\${YOUR_SCRIPTS}noot\\${YOUR_SCRIPTS}g. Use 
# s@<regexp>.@<replacement>.@g instead.
#
#
# USER EXTENSIONS
#
# A CGIscriptor package is attached to the bottom of this file. With
# this package you can personalize your version of CGIscriptor by 
# including often used perl routines. These subroutines can be 
# accessed by prefixing their names with CGIscriptor::, e.g., 
# <SCRIPT LANGUAGE=PERL TYPE=text/ssperl> 
# CGIscriptor::ListDocs("/Books/*") # List all documents in /Books
# </SCRIPT>
# It already contains some useful subroutines for Document Management.
# As it is a separate package, it has its own namespace, isolated from
# both the evaluator and the main program. To access variables from
# the document <SCRIPT></SCRIPT> blocks, use $CGIexecute::<var>. 
# 
# Currently, the following functions are implemented 
# (precede them with CGIscriptor::, see below for more information)
# - SAFEqx ('String') -> result of qx/"String"/ # Safe application of ``-quotes
#   Is used by text/osshell Shell scripts. Protects all CGI 
#   (client-supplied) values with single quotes before executing the 
#   commands (one of the few functions that also works WITHOUT CGIscriptor:: 
#   in front)
# - defineCGIvariable ($name[, $default) -> 0/1 (i.e., failure/success)
#   Is used by the META tag to define and initialize CGI and ENV 
#   name/value pairs. Tries to obtain an initializing value from (in order):
#   $ENV{$name}
#   The Query string
#   The default value given (if any)
#   (one of the few functions that also works WITHOUT CGIscriptor:: 
#   in front)
# - CGIsafeFileName (FileName) -> FileName or ""
#   Check a string against the Allowed File Characters (and ../ /..).
#   Returns an empty string for unsafe filenames.
# - CGIsafeEmailAddress (Email) -> Email or ""
#   Check a string against correct email address pattern.
#   Returns an empty string for unsafe addresses.
# - RedirectShellScript ('CommandString') -> FILEHANDLER or undef
#   Open a named PIPE for SAFEqx to receive ALL shell scripts
# - URLdecode (URL encoded string) -> plain string # Decode URL encoded argument
# - URLencode (plain string) -> URL encoded string # Encode argument as URL code
# - CGIparseValue (ValueName [, URL_encoded_QueryString]) -> Decoded value
#   Extract the value of a CGI variable from the global or a private 
#   URL-encoded query (multipart POST raw, NOT decoded)
# - CGIparseValueList (ValueName [, URL_encoded_QueryString]) 
#   -> List of decoded values
#   As CGIparseValue, but now assembles ALL values of ValueName into a list.
# - CGIparseHeader (ValueName [, URL_encoded_QueryString]) -> Header
#   Extract the header of a multipart CGI variable from the global or a private 
#   URL-encoded query ("" when not a multipart variable or absent)
# - CGIparseForm ([URL_encoded_QueryString]) -> Decoded Form
#   Decode the complete global URL-encoded query or a private 
#   URL-encoded query
# - read_url(URL) # Returns the page from URL (with added base tag, both FTP and HTTP)
#   Uses main::GET_URL(URL, 1) to get at the command to read the URL.
# - BrowseDirs(RootDirectory [, Pattern, Startdir, CGIname]) # print browsable directories
# - ListDocs(Pattern [,ListType])  # Prints a nested HTML directory listing of 
#   all documents, e.g., ListDocs("/*", "dl");.
# - HTMLdocTree(Pattern [,ListType])  # Prints a nested HTML listing of all 
#   local links starting from a given document, e.g., 
#   HTMLdocTree("/Welcome.html", "dl");
#
#
# THE RESULTS STACK: @CGISCRIPTORRESULTS
# 
# If the pseudo-variable "$CGIscriptorResults" has been defined in a
# META tag, all subsequent SCRIPT and META results are pushed 
# on the @CGIscriptorResults stack. This list is just another
# Perl variable and can be used and manipulated like any other list.
# $CGIscriptorResults[-1] is always the last result.
# This is only of limited use, e.g., to use the results of an OS shell
# script inside a Perl script. Will NOT contain the results of Pipes
# or code from MIME-profiling.
#
#
# USEFULL CGI PREDEFINED VARIABLES (DO NOT ASSIGN TO THESE)
#
# $CGI_HOME - The DocumentRoot directory
# $CGI_Decoded_QS - The complete decoded Query String
# $CGI_Content_Length - The ACTUAL length of the Query String
# $CGI_Date - Current date and time
# $CGI_Year $CGI_Month $CGI_Day $CGI_WeekDay - Current Date
# $CGI_Time - Current Time
# $CGI_Hour $CGI_Minutes $CGI_Seconds - Current Time, split
# GMT Date/Time:
# $CGI_GMTYear $CGI_GMTMonth $CGI_GMTDay $CGI_GMTWeekDay $CGI_GMTYearDay 
# $CGI_GMTHour $CGI_GMTMinutes $CGI_GMTSeconds $CGI_GMTisdst
# 
#
# USEFULL CGI ENVIRONMENT VARIABLES
#
# Variables accessible (in APACHE) as $ENV{<name>}
# (see: "http://hoohoo.ncsa.uiuc.edu/cgi/env.html"):
#
# QUERY_STRING - The query part of URL, that is, everything that follows the 
#                question mark.
# PATH_INFO    - Extra path information given after the script name
# PATH_TRANSLATED - Extra pathinfo translated through the rule system. 
#                   (This doesn't always make sense.)
# REMOTE_USER  - If the server supports user authentication, and the script is 
#                protected, this is the username they have authenticated as.
# REMOTE_HOST  - The hostname making the request. If the server does not have 
#                this information, it should set REMOTE_ADDR and leave this unset
# REMOTE_ADDR  - The IP address of the remote host making the request.
# REMOTE_IDENT - If the HTTP server supports RFC 931 identification, then this 
#                variable will be set to the remote user name retrieved from 
#                the server. Usage of this variable should be limited to logging 
#                only. 
# AUTH_TYPE    - If the server supports user authentication, and the script 
#                is protected, this is the protocol-specific authentication 
#                method used to validate the user. 
# CONTENT_TYPE - For queries which have attached information, such as HTTP 
#                POST and PUT, this is the content type of the data.   
# CONTENT_LENGTH - The length of the said content as given by the client.
# SERVER_SOFTWARE - The name and version of the information server software 
#                   answering the request (and running the gateway). 
#                   Format: name/version
# SERVER_NAME  - The server's hostname, DNS alias, or IP address as it 
#                   would appear in self-referencing URLs
# GATEWAY_INTERFACE - The revision of the CGI specification to which this 
#                     server complies. Format: CGI/revision
# SERVER_PROTOCOL - The name and revision of the information protocol this 
#                   request came in with. Format: protocol/revision
# SERVER_PORT  - The port number to which the request was sent.
# REQUEST_METHOD - The method with which the request was made. For HTTP, 
#                  this is "GET", "HEAD", "POST", etc. 
# SCRIPT_NAME  - A virtual path to the script being executed, used for 
#                self-referencing URLs.
# HTTP_ACCEPT  - The MIME types which the client will accept, as given by 
#                HTTP headers. Other protocols may need to get this 
#                information from elsewhere. Each item in this list should 
#                be separated by commas as per the HTTP spec. 
#                Format: type/subtype, type/subtype  
# HTTP_USER_AGENT - The browser the client is using to send the request. 
#                General format: software/version library/version. 
#
# 
# INSTRUCTIONS FOR RUNNING CGIscriptor ON UNIX
# 
# CGIscriptor.pl will run on any WWW server that runs Perl scripts, just add
# a line like the following to your srm.conf file (Apache example):
# 
# ScriptAlias /SHTML/ /real-path/CGIscriptor.pl/
# 
# URL's that refer to http://www.your.address/SHTML/...  will now be handled
# by CGIscriptor.pl, which can use a private directory tree (default is the
# DOCUMENT_ROOT directory tree, but it can be anywhere, see manual).
# 
# The CGIscriptor file contains all documentation as comments.  These
# comments can be removed to speed up loading (e.g., `egrep -v '^#'
# CGIscriptor.pl` > leanScriptor.pl).  A bare bones version of
# CGIscriptor.pl, lacking documentation, most comments, access control,
# example functions etc.  (but still with the copyright notice and some
# minimal documentation) can be obtained by calling CGIscriptor.pl on the 
# command line with the '-slim' command line argument, e.g.,
# 
# >CGIscriptor.pl -slim > slimCGIscriptor.pl
# 
# CGIscriptor.pl can be run from the command line with <path> and <query> as
# arguments, as `CGIscriptor.pl  <path> <query>`, inside a perl script 
# with 'do CGIscriptor.pl' after setting $ENV{PATH_INFO}
# and $ENV{QUERY_STRING}, or CGIscriptor.pl can be loaded with 'require
# "/real-path/CGIscriptor.pl"'.  In the latter case, requests are processed
# by 'Handle_Request();' (again after setting $ENV{PATH_INFO} and
# $ENV{QUERY_STRING}).
# 
# Using the command line execution option, CGIscriptor.pl can be used as a 
# document (meta-)preprocessor. If the first argument is '-', STDIN will be read. 
# For example:
# 
# > cat MyDynamicDocument.html | CGIscriptor.pl - '[QueryString]' > MyStaticFile.html
# 
# This command line will produce a STATIC file with the DYNAMIC content of 
# MyDocument.html "interpolated". 
#
# This option would be very dangerous when available over the internet. 
# If someone could sneak a 'http://www.your.domain/-' URL past your 
# server, CGIscriptor could EXECUTE any POSTED contend.
# Therefore, for security reasons, STDIN will NOT be read
# if ANY of the HTTP server environment variables is set (e.g.,
# SERVER_PORT, SERVER_PROTOCOL, SERVER_NAME, SERVER_SOFTWARE, 
# HTTP_USER_AGENT, REMOTE_ADDR).
# This block on processing STDIN on HTTP requests can be lifted by setting
# $BLOCK_STDIN_HTTP_REQUEST = 0;
# In the security configuration. Butbe carefull when doing this. 
# It can be very dangerous.
#
# Running demo's and more information can be found at
# http://www.fon.hum.uva.nl/~rob/OSS/OSS.html
# 
# A pocket-size HTTP daemon, CGIservlet.pl, is available from my web site or
# CPAN that can use CGIscriptor.pl as the base of a µWWW server and
# demonstrates its use.
# 
#
# PROCESSING NON-FILESYSTEM DATA
#
# Normally, HTTP (WWW) requests map onto file that can be accessed
# using the perl open() function. That is, the web server runs on top of
# some directory structure. However, we can envission (and put to good
# use) other systems that do not use a normal file system. The whole CGI
# was developed to make dynamic document generation possible. 
#
# A special case is where we want to have it both: A normal web server
# with normal "file data", but not a normal files system. For instance,
# we want or normal Web Site to run directly from a RAM hash table or
# other database, instead of from disk. But we do NOT want to code the
# whole site structure in CGI.
#
# CGIscriptor can do this. If the web server fills an environment variable
# $ENV{'CGI_FILE_CONTENT'} with the content of the "file", then the content 
# of this variable is processed instead of opening a file. If this environment 
# variable has the value '-', the content of another environment variable,
# $ENV{'CGI_DATA_ACCESS_CODE'} is executed as:
# eval("\@_ = ($file_path); do {$ENV{'CGI_DATA_ACCESS_CODE'}};") 
# and the result is processed as if it was the content of the requested
# file.
# (actually, the names of the environment variables are user configurable, 
# they are stored in the local variables $CGI_FILE_CONTENT and 
# $CGI_DATA_ACCESS_CODE)
#
# When using this mechanism, the SRC attribute mechanism will only partially work.
# Only the "recursive" calls to CGIscriptor (the ProcessFile() function) 
# will work, the automagical execution of SRC files won't. (In this case, 
# the SRC attribute won't work either for other scripting languages)
#
#
# NON-UNIX PLATFORMS
# 
# CGIscriptor.pl was mainly developed and tested on UNIX. However, as I 
# coded part of the time on an Apple Macintosh under MacPerl, I made sure
# CGIscriptor did run under MacPerl (with command line options).  But only
# as an independend script, not as part of a HTTP server.
# 
# As far as I have been able to test it, the only change to be made is
# uncommenting the line "$DirectorySeparator = ':';    # Mac" in the
# configuration part (and commenting out the UNIX part). If your server
# does not convert the URL PATH_INFO into MacOS directory paths, you
# must make sure that the line "$file_path =~ s@/@$DirectorySeparator@isg;"
# in the Initialize_output() function is not commented out (it is useless
# under UNIX).
# 
# The same should be possible under Microsoft Windows/NT. However, I 
# have never run CGIscriptor.pl under any of the MS OS's.
#
###############################################################################
#
# SECURITY CONFIGURATION
#
# Special configurations related to SECURITY 
# (i.e., optional, see also environment variables below)
#
# LOGGING
# Log Clients and the requested paths (Redundant when loging Queries)
# 
$ClientLog = "./Client.log"; # (uncomment for use)
#
# Format: Localtime | REMOTE_USER REMOTE_IDENT REMOTE_HOST REMOTE_ADDRESS \
# PATH_INFO CONTENT_LENGTH  (actually, the real query+post length)
#                         
# Log Clients and the queries, the CGIQUERYDECODE is required if you want
# to log queries. If you log Queries, the loging of Clients is redundant
# (note that queries can be quite long, so this might not be a good idea)
# 
#$QueryLog = "./Query.log"; # (uncomment for use)                       
#
# ACCESS CONTROL 
# the Access files should contain Hostnames or IP addresses, 
# i.e. REMOTE_HOST or REMOTE_ADDR, each on a separate line
# optionally followed by one ore more file patterns, e.g., "edu /DEMO". 
# Matching is done "domain first". For example ".edu" matches all 
# clients whose "name" ends in ".edu" or ".EDU". The file pattern 
# "/DEMO" matches all paths that contain the strings "/DEMO" or "/demo" 
# (both matchings are done case-insensitive).
# The name special symbol "-" matches ALL clients who do not supply a 
# REMOTE_HOST name, "*" matches all clients.
# Lines starting with '-e' are evaluated. A non-zero return value indicates 
# a match. You can use $REMOTE_HOST, $REMOTE_ADDR, and $PATH_INFO. These
# lines are evaluated in the program's own name-space. So DO NOT assign to 
# variables.
#
# Accept the following users (remove comment # and adapt filename)
#$CGI_Accept = "~/CGIscriptorAccept.lis"; # (uncomment for use)
#
# Reject requests from the following users (remove comment # and 
# adapt filename, this is only of limited use)
#$CGI_Reject = "~/CGIscriptorReject.lis"; # (uncomment for use)
#
# Empty lines or comment lines starting with '#' are ignored in both 
# $CGI_Accept and $CGI_Reject.
#
# Block STDIN (i.e., '-') requests when servicing an HTTP request
# Comment this out if you realy want to use STDIN in an on-line web server
$BLOCK_STDIN_HTTP_REQUEST = 1;
#
#
# End of security configuration
#
##################################################<<<<<<<<<<End Remove
# 
# PARSING CGI VALUES FROM THE QUERY STRING (USER CONFIGURABLE)
# 
# The CGI parse commands. These commands extract the values of the 
# CGI variables from the URL encoded Query String.
# If you want to use your own CGI decoders, you can call them here 
# instead, using your own PATH and commenting/uncommenting the 
# appropriate lines
# 
# CGI parse command for individual values 
# (if $List > 0, returns a list value, if $List < 0, a hash table, this is optional)
sub YOUR_CGIPARSE   # ($Name [, $List]) -> Decoded value
{ 
    my $Name = shift;
    my $List = shift || 0;
    # Use one of the following by uncommenting
    if(!$List)    # Simple value
    {
        return CGIscriptor::CGIparseValue($Name) ;
    }
    elsif($List < 0)         # Hash tables
    {
        return CGIscriptor::CGIparseValueHash($Name); # Defined in CGIscriptor below
    }
    else          # Lists
    {
        return CGIscriptor::CGIparseValueList($Name); # Defined in CGIscriptor below
    };
    
    # return `/PATH/cgiparse -value $Name`;  # Shell commands
    # require "/PATH/cgiparse.pl"; return cgivalue($Name); # Library
}
# Complete queries
sub YOUR_CGIQUERYDECODE 
{
    # Use one of the following by uncommenting
    return CGIscriptor::CGIparseForm(); # Defined in CGIscriptor below
    # return `/PATH/cgiparse -form`;   # Shell commands
    # require "/PATH/cgiparse.pl"; return cgiform(); # Library
};
#
# End of configuration
# 
#######################################################################
#
# Seamless access to other (Scripting) Languages
# TYPE='text/ss<interpreter>'
#
# Configuration section
#
#######################################################################
#
# OTHER SCRIPTING LANGUAGES AT THE SERVER SIDE (MIME => OScommand)
# Yes, it realy is this simple! (unbelievable, isn't it)
# NOTE: Some interpreters require some filtering to obtain "clean" output

%ScriptingLanguages = (
"text/testperl" => 'perl',              # Perl for testing
"text/sspython" => 'python',            # Python 
"text/ssruby"   => 'ruby',              # Ruby 
"text/sstcl"    => 'tcl',               # TCL 
"text/ssawk"    => 'awk -f-',           # Awk  
"text/sslisp"   =>                      # lisp (rep, GNU)
'rep | tail +4 '."| egrep -v '> |^rep. |^nil\\\$'",       
"text/xlispstat"   =>                   # xlispstat
'xlispstat | tail +7 ' ."| egrep -v '> \\\$|^NIL'",          
"text/ssprolog" =>                      # Prolog (GNU) 
"gprolog | tail +4 | sed 's/^| ?- //'",  
"text/ssm4"     => 'm4',                # M4 macro's
"text/sh"       => 'sh',                # Born shell
"text/bash"     => 'bash',              # Born again shell
"text/csh"      => 'csh',               # C shell 
"text/ksh"      => 'ksh',               # Korn shell
"text/sspraat"  =>                      # Praat (sound/speech analysis)
"praat - | sed 's/Praat > //g'",         
"text/ssr"      =>                      # R
"R --vanilla --slave | sed 's/^[\[0-9\]*] //'",
"text/ssrebol" =>                       # REBOL
"rebol --quiet|egrep -v '^[> ]* == '|sed 's/^\s*\[> \]* //'",
"text/postgresql" => 'psql 2>/dev/null',

# Not real scripting, but the use of other applications
"text/ssmailto"  => "awk 'NF||F{F=1;print \\\$0;}'|mailto >/dev/null",  # Send mail from server
"text/ssdisplay"  => 'cat',             # Display, (interpolation)
"text/sslogfile"  =>                    # Log to file, (interpolation)
"awk 'NF||L {if(!L){L=tolower(\\\$1)~/^file:\\\$/ ? \\\$2 : \\\$1;}else{print \\\$0 >> L;};}'",

"" => ""
);
#
# To be able to access the CGI variables in your script, they
# should be passed to the scripting language in a readable form
# Here you can enter how they should be printed (the first %s 
# is replaced by the NAME of the CGI variable as it apears in the 
# META tag, the second by its VALUE).
# For Perl this would be: 
# "text/testperl" => '$%s = "%s";',
# which would be executed as
# printf('$%s = "%s";', $CGI_NAME, $CGI_VALUE);
#
# If the hash table value doesn't exist, nothing is done
# (you have to parse the Environment variables yourself).
# If it DOES exist but is empty (e.g., "text/sspraat"   => '',)
# Perl string interpolation of variables (i.e., $var, @array, 
# %hash) is performed. This means that $@%\ must be protected
# with a \.
#
%ScriptingCGIvariables = (
"text/testperl" => "\$\%s = '\%s';",    # Perl          $VAR = 'value'; (for testing)
"text/sspython" => "\%s = '\%s'",       # Python        VAR = 'value'
"text/ssruby"   => '@%s = "%s"',        # Ruby          @VAR = 'value'
"text/sstcl"    => 'set %s "%s"',       # TCL           set VAR "value"
"text/ssawk"    => '%s = "%s";',        # Awk           VAR = 'value'; 
"text/sslisp"   => '(setq %s "%s")',    # Gnu lisp (rep) (setq VAR "value")
"text/xlispstat"   => '(setq %s "%s")', # xlispstat (setq VAR "value")
"text/ssprolog" => '',                  # Gnu prolog    (interpolated)
"text/ssm4"     => "define(`\%s', `\%s')", # M4 macro's define(`VAR', `value')
"text/sh"       => "\%s='\%s'",         # Born shell    VAR='value'
"text/bash"     => "\%s='\%s'",         # Born again shell VAR='value' 
"text/csh"      => "\$\%s='\%s';",      # C shell       $VAR = 'value';
"text/ksh"      => "\$\%s='\%s';",      # Korn shell    $VAR = 'value'; 

"text/ssrebol"  => '%s: copy "%s"',     # REBOL         VAR: copy "value" 
"text/sspraat"  => '',                  # Praat         (interpolation) 
"text/ssr"      => '%s <- "%s";',       # R             VAR <- "value"; 
"text/postgresql" => '',                # PostgreSQL    (interpolation) 

# Not real scripting, but the use of other applications
"text/ssmailto"  => '',                 # MAILTO, (interpolation)
"text/ssdisplay"  => '',                        # Display, (interpolation)
"text/sslogfile"  => '',                        # Log to file, (interpolation)

"" => ""
);

# If you want something added in front or at the back of each script 
# block as send to the interpreter add it here.
# mime => "string", e.g., "text/sspython" => "python commands"
%ScriptingPrefix = (
"text/testperl" => "\# Prefix Code;",   # Perl script testing
"text/ssm4"     =>  'divert(0)',        # M4 macro's (open STDOUT)

"" => "" 
);
# If you want something added at the end of each script block
%ScriptingPostfix = (
"text/testperl" => "\# Postfix Code;",  # Perl script testing
"text/ssm4"     =>  'divert(-1)',       # M4 macro's (block STDOUT)

"" => "" 
);
# If you need initialization code, directly after opening
%ScriptingInitialization = (
"text/testperl" => "\# Initialization Code;",   # Perl script testing
"text/ssawk"    => 'BEGIN {',   # Server Side awk scripts (VAR = "value")
"text/sslisp"   => '(prog1 nil ',   # Lisp (rep)
"text/xlispstat"   => '(prog1 nil ',   # xlispstat
"text/ssm4"     =>  'divert(-1)',       # M4 macro's (block STDOUT)

"" => "" 
);
# If you need cleanup code before closing
%ScriptingCleanup = (
"text/testperl" => "\# Cleanup Code;",  # Perl script testing
"text/sspraat"  => 'Quit',
"text/ssawk"    => '};',        # Server Side awk scripts (VAR = "value")
"text/sslisp"   =>  '(princ "\n" standard-output)).',      # Closing print to rep
"text/xlispstat"   =>  '(print ""))',      # Closing print to xlispstat
"text/postgresql" => '\q',              # quit psql
"text/ssdisplay" => "",		# close cat

"" => ""
);
#
# End of configuration for foreign scripting languages
#
###############################################################################
#
# Initialization Code
# 
# 
sub Initialize_Request
{
    ###############################################################################
    #
    # ENVIRONMENT VARIABLES
    #
    # Use environment variables to configure CGIscriptor on a temporary basis.
    # If you define any of the configurable variables as environment variables, 
    # these are used instead of the "hard coded" values above.
    #
    $SS_PUB = $ENV{'SS_PUB'} || $YOUR_HTML_FILES;
    $SS_SCRIPT = $ENV{'SS_SCRIPT'} || $YOUR_SCRIPTS;
    
    #
    # Substitution strings, these are used internally to handle the
    # directory separator strings, e.g., '~/' -> 'SS_PUB:' (Mac)
    $HOME_SUB = $SS_PUB;
    $SCRIPT_SUB = $SS_SCRIPT;

    # 
    # Make sure all script are reliably loaded
    push(@INC, $SS_SCRIPT);

    
    # Add the directory separator to the "home" directories. 
    # (This is required for ~/ and ./ substitution)
    $HOME_SUB .= $DirectorySeparator if $HOME_SUB;
    $SCRIPT_SUB .= $DirectorySeparator if $SCRIPT_SUB;
    
    $CGI_HOME = $ENV{'DOCUMENT_ROOT'};
    $ENV{'PATH_TRANSLATED'} =~ /$ENV{'PATH_INFO'}/is;
    $CGI_HOME = $` unless $ENV{'DOCUMENT_ROOT'};    # Get the DOCUMENT_ROOT directory
    $default_values{'CGI_HOME'} = $CGI_HOME;
    $ENV{'HOME'} = $CGI_HOME;
    # Set SS_PUB and SS_SCRIPT as Environment variables (make them available
    # to the scripts)
    $ENV{'SS_PUB'} = $SS_PUB unless $ENV{'SS_PUB'};
    $ENV{'SS_SCRIPT'} = $SS_SCRIPT unless $ENV{'SS_SCRIPT'};
    #
    $FilePattern = $ENV{'FilePattern'} || $FilePattern;
    $MaximumQuerySize = $ENV{'MaximumQuerySize'} || $MaximumQuerySize;
    $ClientLog = $ENV{'ClientLog'} || $ClientLog;
    $QueryLog = $ENV{'QueryLog'} || $QueryLog;
    $CGI_Accept = $ENV{'CGI_Accept'} || $CGI_Accept;
    $CGI_Reject = $ENV{'CGI_Reject'} || $CGI_Reject;
    #
    # Parse file names
    $CGI_Accept =~ s@^\~/@$HOME_SUB@g if $CGI_Accept;
    $CGI_Reject =~ s@^\~/@$HOME_SUB@g if $CGI_Reject;
    $ClientLog =~ s@^\~/@$HOME_SUB@g if $ClientLog;
    $QueryLog =~ s@^\~/@$HOME_SUB@g if $QueryLog;
    
    $CGI_Accept =~ s@^\./@$SCRIPT_SUB@g if $CGI_Accept;
    $CGI_Reject =~ s@^\./@$SCRIPT_SUB@g if $CGI_Reject;
    $ClientLog =~ s@^\./@$SCRIPT_SUB@g if $ClientLog;
    $QueryLog =~ s@^\./@$SCRIPT_SUB@g if $QueryLog;
    
    @CGIscriptorResults = ();  # A stack of results
    #
    # end of Environment variables
    #
    #############################################################################
    #
    # Define and Store "standard" values
    #
    # BEFORE doing ANYTHING check the size of Query String
    length($ENV{'QUERY_STRING'}) <= $MaximumQuerySize || die "QUERY TOO LONG\n";
    #
    # The Translated Query String and the Actual length of the (decoded) 
    # Query String
    if($ENV{'QUERY_STRING'})
    { 
        # If this can contain '`"-quotes, be carefull to use it QUOTED
        $default_values{CGI_Decoded_QS} = YOUR_CGIQUERYDECODE();
        $default_values{CGI_Content_Length} = length($default_values{CGI_Decoded_QS});
    };
    #
    # Get the current Date and time and store them as default variables
    #
    # Get Local Time
    $LocalTime = localtime;
    #
    # CGI_Year CGI_Month CGI_Day CGI_WeekDay CGI_Time 
    # CGI_Hour CGI_Minutes CGI_Seconds
    # 
    $default_values{CGI_Date} = $LocalTime;
    ($default_values{CGI_WeekDay}, 
    $default_values{CGI_Month}, 
    $default_values{CGI_Day}, 
    $default_values{CGI_Time}, 
    $default_values{CGI_Year}) = split(' ', $LocalTime);
    ($default_values{CGI_Hour}, 
    $default_values{CGI_Minutes}, 
    $default_values{CGI_Seconds}) = split(':', $default_values{CGI_Time});
    #
    # GMT:
    # CGI_GMTYear CGI_GMTMonth CGI_GMTDay CGI_GMTWeekDay CGI_GMTYearDay 
    # CGI_GMTHour CGI_GMTMinutes CGI_GMTSeconds CGI_GMTisdst
    #
    ($default_values{CGI_GMTSeconds}, 
    $default_values{CGI_GMTMinutes}, 
    $default_values{CGI_GMTHour}, 
    $default_values{CGI_GMTDay}, 
    $default_values{CGI_GMTMonth}, 
    $default_values{CGI_GMTYear}, 
    $default_values{CGI_GMTWeekDay}, 
    $default_values{CGI_GMTYearDay}, 
    $default_values{CGI_GMTisdst}) = gmtime;
    #
}
#
# End of Initialize Request
#
###################################################################
#
# SECURITY: ACCESS CONTROL
#
# Check the credentials of each client (use pattern matching, domain first).
# This subroutine will kill-off (die) the current process whenever access 
# is denied.

sub Access_Control
{
    # >>>>>>>>>>Start Remove
    #
    # ACCEPTED CLIENTS
    #
    # Only accept clients which are authorized, reject all unnamed clients
    # if REMOTE_HOST is given.
    # If file patterns are given, check whether the user is authorized for 
    # THIS file.
    if($CGI_Accept)
    { 
        # Use local variables, REMOTE_HOST becomes '-' if undefined
        my $REMOTE_HOST = $ENV{REMOTE_HOST} || '-';
        my $REMOTE_ADDR = $ENV{REMOTE_ADDR};
        my $PATH_INFO = $ENV{'PATH_INFO'};
        
        open(CGI_Accept, "<$CGI_Accept");
        $NoAccess = 1;
        while($NoAccess && <CGI_Accept>)
        { 
            next unless /\S/;  # Skip empty lines
            next if /^\s*\#/;  # Skip comments
            
            # Full expressions
            if(/^\s*-e\s/is)
            {
                my $Accept = $';  # Get the expression
                $NoAccess &&= eval($Accept);  # evaluate the expresion
            }
            else
            {
                my ($Accept, @FilePatternList) = split;
                if($Accept eq '*'               # Always match
                ||$REMOTE_HOST =~ /\Q$Accept\E$/is        # REMOTE_HOST matches
                || (
                $Accept =~ /^[0-9\.]+$/ 
                && $REMOTE_ADDR =~ /^\Q$Accept\E/ # IP address matches
                )
                )
                { 
                    if($FilePatternList[0])
                    {  
                        foreach $Pattern (@FilePatternList)
                        { 
                            # Check whether this patterns is accepted
                            $NoAccess &&= ($PATH_INFO !~ m@\Q$Pattern\E@is);    
                        };
                    }
                    else
                    {  
                        $NoAccess = 0;   # No file patterns -> Accepted
                    };
                };
            };
        };
        close(CGI_Accept);
        if($NoAccess){ die "No Access: $PATH_INFO\n";};
    };
    #
    # 
    # REJECTED CLIENTS
    #
    # Reject named clients, accept all unnamed clients
    if($CGI_Reject)
    { 
        # Use local variables, REMOTE_HOST becomes '-' if undefined
        my $REMOTE_HOST = $ENV{'REMOTE_HOST'} || '-';
        my $REMOTE_ADDR = $ENV{'REMOTE_ADDR'};
        my $PATH_INFO = $ENV{'PATH_INFO'};
        
        open(CGI_Reject, "<$CGI_Reject");
        $NoAccess = 0;
        while(!$NoAccess && <CGI_Reject>)
        { 
            next unless /\S/;  # Skip empty lines
            next if /^\s*\#/;     # Skip comments
            
            # Full expressions
            if(/^-e\s/is)
            {
                my $Reject = $';  # Get the expression
                $NoAccess ||= eval($Reject);  # evaluate the expresion
            }
            else
            {
                my ($Reject, @FilePatternList) = split;
                if($Reject eq '*'                     # Always match
                ||$REMOTE_HOST =~ /\Q$Reject\E$/is   # REMOTE_HOST matches
                ||($Reject =~ /^[0-9\.]+$/ 
                && $REMOTE_ADDR =~ /^\Q$Reject\E/is  # IP address matches
                )
                )
                { 
                    if($FilePatternList[0])
                    {  
                        foreach $Pattern (@FilePatternList)
                        { 
                            $NoAccess ||= ($PATH_INFO =~ m@\Q$Pattern\E@is);
                        };
                    }
                    else
                    {  
                        $NoAccess = 1;    # No file patterns -> Rejected
                    };
                };
            };
        };
        close(CGI_Reject);
        if($NoAccess){ die "Request rejected: $PATH_INFO\n";};
    };
    #
    ##########################################################<<<<<<<<<<End Remove
    #
    #
    # Get the filename
    #
    # Does the filename contain any illegal characters (e.g., |, >, or <)
    die "Illegal request\n" if $ENV{'PATH_INFO'} =~ /[^$FileAllowedChars]/;
    # Does the pathname contain an illegal (blocked) "directory"
    die "Illegal request\n" if $BlockPathAccess && $ENV{'PATH_INFO'} =~ m@$BlockPathAccess@;  # Access is blocked
    # Does the pathname contain a direct referencer to BinaryMapFile
    die "Illegal request\n" if $BinaryMapFile && $ENV{'PATH_INFO'} =~ m@\Q$BinaryMapFile\E@;  # Access is blocked
    
    # SECURITY: Is PATH_INFO allowed?
    if($FilePattern && $ENV{'PATH_INFO'} &&  $ENV{'PATH_INFO'} ne '-' &&
    ($ENV{'PATH_INFO'} !~ m@($FilePattern)$@is)) 
    {
        # Unsupported file types can be processed by a special raw-file
        if($BinaryMapFile)
        {
            $ENV{'CGI_BINARY_FILE'} = $ENV{'PATH_INFO'};
            $ENV{'PATH_INFO'} = $BinaryMapFile;     
        }
        else
        {
            die "Illegal file\n"; 
        };
    };
    
}
#
# End of Security Access Control
# 
#
############################################################################
#
# Start (HTML) output and logging
# (if there are irregularities, it can kill the current process)
#
#
sub Initialize_output
{
    # Construct the REAL file path (except for STDIN on the command line)
    my $file_path = $ENV{'PATH_INFO'} ne '-' ? $SS_PUB . $ENV{'PATH_INFO'} : '-'; 
    $file_path =~ s/\?.*$//;                  # Remove query
    # This is only necessary if your server does not catch ../ directives
    $file_path !~ m@\.\./@ || die; # SECURITY: Do not allow ../ constructs
    
    # Block STDIN use (-) if CGIscriptor is servicing a HTTP request
    if($file_path eq '-')
    {
        die if $BLOCK_STDIN_HTTP_REQUEST
        && ($ENV{'SERVER_SOFTWARE'} 
        || $ENV{'SERVER_NAME'} 
        || $ENV{'GATEWAY_INTERFACE'} 
        || $ENV{'SERVER_PROTOCOL'} 
        || $ENV{'SERVER_PORT'} 
        || $ENV{'REMOTE_ADDR'} 
        || $ENV{'HTTP_USER_AGENT'});
    };
    
    # Change URL's into file directory paths (ONLY necessary if your 
    # NON-UNIX OS HTTP server does NOT take care of it).
    $file_path =~ s@/@$DirectorySeparator@isg;
    
    #
    #
    # If POST, Read data from stdin to QUERY_STRING
    if($ENV{'REQUEST_METHOD'} =~ /POST/is)
    {
        # SECURITY: Check size of Query String
        $ENV{'CONTENT_LENGTH'} <= $MaximumQuerySize || die;  # Query too long
        my $QueryRead = 0;
        my $SystemRead = $ENV{'CONTENT_LENGTH'};
	$ENV{'QUERY_STRING'} .= '&' if length($ENV{'QUERY_STRING'}) > 0;
        while($SystemRead > 0)
        {
            $QueryRead = sysread(STDIN, $Post, $SystemRead); # Limit length
            $ENV{'QUERY_STRING'} .= $Post;
            $SystemRead -= $QueryRead;
        };
        # Update decoded Query String
        $default_values{CGI_Decoded_QS} = YOUR_CGIQUERYDECODE();
        $default_values{CGI_Content_Length} = 
        length($default_values{CGI_Decoded_QS});
    };
    #
    #
    if($ClientLog)
    {
        open(ClientLog, ">>$ClientLog");
        print ClientLog  "$LocalTime | ",
        ($ENV{REMOTE_USER} || "-"), " ",
        ($ENV{REMOTE_IDENT} || "-"), " ",
        ($ENV{REMOTE_HOST} || "-"), " ",
        $ENV{REMOTE_ADDR}, " ",
        $ENV{PATH_INFO}, " ", 
        $ENV{'CGI_BINARY_FILE'}, " ", 
        ($default_values{CGI_Content_Length} || "-"),
        "\n";
        close(ClientLog);
    };
    if($QueryLog)
    {
        open(QueryLog, ">>$QueryLog");
        print QueryLog  "$LocalTime\n", 
        ($ENV{REMOTE_USER} || "-"), " ",
        ($ENV{REMOTE_IDENT} || "-"), " ",
        ($ENV{REMOTE_HOST} || "-"), " ",
        $ENV{REMOTE_ADDR}, ": ",
        $ENV{PATH_INFO}, " ",
        $ENV{'CGI_BINARY_FILE'},  "\n";
        #
        # Write Query to Log file
        print QueryLog $default_values{CGI_Decoded_QS}, "\n\n";
        close(QueryLog);
    };
    #
    # Return the file path
    return $file_path;
}
#
# End of Initialize output
# 
#
############################################################################
#
# Handle foreign interpreters (i.e., scripting languages)
#
# Insert perl code to execute scripts in foreign scripting languages. 
# Actually, the scripts inside the <SCRIPT></SCRIPT> blocks are piped
# into an interpreter. 
# The code presented here is fairly confusing because it 
# actually writes perl code code to the output.
#
# A table with the file handles
%SCRIPTINGINPUT = ();
#
# A function to clean up Client delivered CGI parameter values
# (i.e., quote all odd characters)
%SHRUBcharacterTR =
(
"\'" => '&#39;',
"\`" => '&#96;',
"\"" => '&quot;',
'&' => '&amper;',
"\\" => '&#92;'
);

sub shrubCGIparameter     # ($String) -> Cleaned string
{
    my $String = shift || "";
    
    # Change all quotes [`'"] into HTML character entities
    my ($Char, $Transcript) = ('&', $SHRUBcharacterTR{'&'});
    
    # Protect &
    $String =~ s/\Q$Char\E/$Transcript/isg if $Transcript;
    
    while( ($Char, $Transcript) = each %SHRUBcharacterTR)
    {
        next if $Char eq '&';
        $String =~ s/\Q$Char\E/$Transcript/isg;
    };
    
    # Replace newlines
    $String =~ s/[\n]/\\n/g;
    # Replace control characters with their backslashed octal ordinal numbers 
    $String =~ s/([^\S \t])/(sprintf("\\0%o", ord($1)))/eisg; # 
    $String =~ s/([\x00-\x08\x0A-\x1F])/(sprintf("\\0%o", ord($1)))/eisg; # 
    
    return $String;
};

#
# The initial open statements: Open a pipe to the foreign script interpreter
sub OpenForeignScript   # ($ContentType) -> $DirectivePrefix
{
    my $ContentType = lc(shift) || return "";
    my $NewDirective = "";
    
    return $NewDirective if($SCRIPTINGINPUT{$ContentType});
    
    # Construct a unique file handle name
    $SCRIPTINGFILEHANDLE = uc($ContentType);
    $SCRIPTINGFILEHANDLE =~ s/\W/\_/isg;
    $SCRIPTINGINPUT{$ContentType} = $SCRIPTINGFILEHANDLE
    unless $SCRIPTINGINPUT{$ContentType};
    
    # Create the relevant script: Open the pipe to the interpreter
    $NewDirective .= <<"BLOCKCGISCRIPTOROPEN";
# Open interpreter for '$ContentType'
# Open pipe to interpreter (if it isn't open already)
open($SCRIPTINGINPUT{$ContentType}, "|$ScriptingLanguages{$ContentType}") || die "$ContentType: \$!\\n";
BLOCKCGISCRIPTOROPEN
    #
    # Insert Initialization code and CGI variables
    $NewDirective .= InitializeForeignScript($ContentType);
    
    # Ready
    return $NewDirective;
}

# 
# The final closing code to stop the interpreter
sub CloseForeignScript  # ($ContentType) -> $DirectivePrefix
{
    my $ContentType = lc(shift) || return "";
    my $NewDirective = "";
    
    # Do nothing unless the pipe realy IS open
    return "" unless $SCRIPTINGINPUT{$ContentType};
    
    # Initial comment
    $NewDirective .= "\# Close interpreter for '$ContentType'\n";
    
    #
    # Write the Postfix code 
    $NewDirective .= CleanupForeignScript($ContentType);
    
    # Create the relevant script: Close the pipe to the interpreter
    $NewDirective .= <<"BLOCKCGISCRIPTORCLOSE";
close($SCRIPTINGINPUT{$ContentType}) || die \"$ContentType: \$!\\n\";
select(STDOUT); \$|=1;
   
BLOCKCGISCRIPTORCLOSE
    
    # Remove the file handler of the foreign script
    delete($SCRIPTINGINPUT{$ContentType});
    
    return $NewDirective;
}

#
# The initialization code for the foreign script interpreter
sub InitializeForeignScript     # ($ContentType) -> $DirectivePrefix
{
    my $ContentType = lc(shift) || return "";
    my $NewDirective = "";
    
    # Add initialization code
    if($ScriptingInitialization{$ContentType})
    {
        $NewDirective .= <<"BLOCKCGISCRIPTORINIT";
# Initialization Code for '$ContentType'
# Select relevant output filehandle 
select($SCRIPTINGINPUT{$ContentType}); \$|=1;
#
# The Initialization code (if any)
print $SCRIPTINGINPUT{$ContentType} <<'${ContentType}INITIALIZATIONCODE';
$ScriptingInitialization{$ContentType}
${ContentType}INITIALIZATIONCODE
       
BLOCKCGISCRIPTORINIT
    };
    
    # Add all CGI variables defined
    if(exists($ScriptingCGIvariables{$ContentType}))
    {
        # Start writing variable definitions to the Interpreter
        if($ScriptingCGIvariables{$ContentType})
        {
            $NewDirective .= <<"BLOCKCGISCRIPTORVARDEF";
# CGI variables (from the %default_values table)
print $SCRIPTINGINPUT{$ContentType} << '${ContentType}CGIVARIABLES';
BLOCKCGISCRIPTORVARDEF
        };
        
        my ($N, $V);
        foreach $N (keys(%default_values))
        { 
            # Determine whether the parameter has been defined
            # (the eval is a workaround to get at the variable value)
            next unless eval("defined(\$CGIexecute::$N)");
            
            # Get the value from the EXECUTION environment
            $V = eval("\$CGIexecute::$N");
            # protect control characters (i.e., convert them to \0.. form)
            $V = shrubCGIparameter($V);
            
            # Protect interpolated variables
            eval("\$CGIexecute::$N = '$V';") unless $ScriptingCGIvariables{$ContentType};
            
            # Print the actual declaration for this scripting language
            if($ScriptingCGIvariables{$ContentType})
            {
                $NewDirective .=  sprintf($ScriptingCGIvariables{$ContentType}, $N, $V);
                $NewDirective .= "\n";
            };
        };
        
        # Stop writing variable definitions to the Interpreter
        if($ScriptingCGIvariables{$ContentType})
        {
            $NewDirective .= <<"BLOCKCGISCRIPTORVARDEFEND";
${ContentType}CGIVARIABLES
BLOCKCGISCRIPTORVARDEFEND
        };
    };
    
    # 
    $NewDirective .= << "BLOCKCGISCRIPTOREND";
   
# Select STDOUT filehandle 
select(STDOUT); \$|=1;
  
BLOCKCGISCRIPTOREND
    #
    
    return $NewDirective;
};

#
# The cleanup code for the foreign script interpreter
sub CleanupForeignScript        # ($ContentType) -> $DirectivePrefix
{
    my $ContentType = lc(shift) || return "";
    my $NewDirective = "";
    
    # Return if not needed
    return $NewDirective unless $ScriptingCleanup{$ContentType};
    
    # Create the relevant script: Open the pipe to the interpreter
    $NewDirective .= <<"BLOCKCGISCRIPTORSTOP";
# Cleanup Code for '$ContentType'
# Select relevant output filehandle 
select($SCRIPTINGINPUT{$ContentType}); \$|=1;
# Print Cleanup code to foreign script
print $SCRIPTINGINPUT{$ContentType} <<'${ContentType}SCRIPTSTOP';
$ScriptingCleanup{$ContentType}
${ContentType}SCRIPTSTOP
   
# Select STDOUT filehandle 
select(STDOUT); \$|=1;
BLOCKCGISCRIPTORSTOP
    #
    return $NewDirective;
};

#
# The prefix code for each <script></script> block
sub PrefixForeignScript # ($ContentType) -> $DirectivePrefix
{
    my $ContentType = lc(shift) || return "";
    my $NewDirective = "";
    
    # Return if not needed
    return $NewDirective unless $ScriptingPrefix{$ContentType};
    
    my $Quote = "\'";
    # If the CGIvariables parameter is defined, but empty, interpolate 
    # code string (i.e., $var .= << "END" i.s.o. $var .= << 'END')
    $Quote = '"' if exists($ScriptingCGIvariables{$ContentType}) &&
    !$ScriptingCGIvariables{$ContentType};
    
    # Add initialization code
    $NewDirective .= <<"BLOCKCGISCRIPTORPREFIX";
# Prefix Code for '$ContentType'
# Select relevant output filehandle 
select($SCRIPTINGINPUT{$ContentType}); \$|=1;
#
# The block Prefix code (if any)
print $SCRIPTINGINPUT{$ContentType} <<$Quote${ContentType}PREFIXCODE$Quote;
$ScriptingPrefix{$ContentType}
${ContentType}PREFIXCODE
# Select STDOUT filehandle 
select(STDOUT); \$|=1;
BLOCKCGISCRIPTORPREFIX
    #
    return $NewDirective;
};

#
# The postfix code for each <script></script> block
sub PostfixForeignScript        # ($ContentType) -> $DirectivePrefix
{
    my $ContentType = lc(shift) || return "";
    my $NewDirective = "";
    
    # Return if not needed
    return $NewDirective unless $ScriptingPostfix{$ContentType};
    
    my $Quote = "\'";
    # If the CGIvariables parameter is defined, but empty, interpolate 
    # code string (i.e., $var .= << "END" i.s.o. $var .= << 'END')
    $Quote = '"' if exists($ScriptingCGIvariables{$ContentType}) &&
    !$ScriptingCGIvariables{$ContentType};
    
    # Create the relevant script: Open the pipe to the interpreter
    $NewDirective .= <<"BLOCKCGISCRIPTORPOSTFIX";
# Postfix Code for '$ContentType'
# Select filehandle to interpreter 
select($SCRIPTINGINPUT{$ContentType}); \$|=1;
# Print postfix code to foreign script
print $SCRIPTINGINPUT{$ContentType} <<$Quote${ContentType}SCRIPTPOSTFIX$Quote;
$ScriptingPostfix{$ContentType}
${ContentType}SCRIPTPOSTFIX
# Select STDOUT filehandle 
select(STDOUT); \$|=1;
BLOCKCGISCRIPTORPOSTFIX
    #
    return $NewDirective;
};

sub InsertForeignScript # ($ContentType, $directive, @SRCfile) -> $NewDirective
{
    my $ContentType = lc(shift) || return "";
    my $directive = shift || return "";
    my @SRCfile = @_;
    my $NewDirective = "";
    
    my $Quote = "\'";
    # If the CGIvariables parameter is defined, but empty, interpolate 
    # code string (i.e., $var .= << "END" i.s.o. $var .= << 'END')
    $Quote = '"' if exists($ScriptingCGIvariables{$ContentType}) &&
    !$ScriptingCGIvariables{$ContentType};
    
    # Create the relevant script
    $NewDirective .= <<"BLOCKCGISCRIPTORINSERT";
# Insert Code for '$ContentType'
# Select filehandle to interpreter
select($SCRIPTINGINPUT{$ContentType}); \$|=1;
BLOCKCGISCRIPTORINSERT
    
    # Use SRC feature files
    my $ThisSRCfile;
    while($ThisSRCfile = shift(@_))
    {
        # Handle blocks
        if($ThisSRCfile =~ /^\s*\{\s*/)
        {
            my $Block = $';
            $Block = $` if $Block =~ /\s*\}\s*$/;
            $NewDirective .= <<"BLOCKCGISCRIPTORSRCBLOCK";
print $SCRIPTINGINPUT{$ContentType} <<$Quote${ContentType}SRCBLOCKCODE$Quote;
$Block
${ContentType}SRCBLOCKCODE
BLOCKCGISCRIPTORSRCBLOCK
            
            next;
        };
        
        # Handle files
        $NewDirective .=  <<"BLOCKCGISCRIPTORSRCFILES";
# Read $ThisSRCfile
open(SCRIPTINGSOURCE, "<$ThisSRCfile") ||  die "$ThisSRCfILE: \$!";
while(<SCRIPTINGSOURCE>) 
{
    print $SCRIPTINGINPUT{$ContentType} \$_;
};
close(SCRIPTINGSOURCE);
        
BLOCKCGISCRIPTORSRCFILES
    };
    
    
    # Add the directive
    if($directive)
    {
        $NewDirective .=  <<"BLOCKCGISCRIPTORINSERT";
print $SCRIPTINGINPUT{$ContentType} <<$Quote${ContentType}DIRECTIVECODE$Quote;
$directive
${ContentType}DIRECTIVECODE
BLOCKCGISCRIPTORINSERT
    };
    
    # 
    $NewDirective .=  <<"BLOCKCGISCRIPTORSELECT";
# Select STDOUT filehandle 
select(STDOUT); \$|=1;
BLOCKCGISCRIPTORSELECT
   
# Ready
return $NewDirective;
};

sub CloseAllForeignScripts      # Call CloseForeignScript on all open scripts
{
    my $ContentType;
    foreach $ContentType (keys(%SCRIPTINGINPUT))
    {
        my $directive = CloseForeignScript($ContentType);
        print STDERR "\nDirective $CGI_Date: ", $directive;
        CGIexecute->evaluate($directive);
    };
};

#
# End of handling foreign (external) scripting languages.
#
############################################################################
#
# A subroutine to handle "nested" quotes, it cuts off the leading 
# item or quoted substring
# E.g., 
# ' A_word and more words'   -> @('A_word', ' and more words')
# '"quoted string" The rest' -> @('quoted string', ' The rest')
# (this is needed for parsing the <TAGS> and their attributes)
my $SupportedQuotes = "\'\"\`\(\{\[";
my %QuotePairs = ('('=>')','['=>']','{'=>'}');  # Brackets
sub ExtractQuotedItem     # ($String) -> @($QuotedString, $RestOfString)
{
    my @Result = ();
    my $String = shift || return @Result;
    
    if($String =~ /^\s*([\w\/\-\.]+)/is)
    {
        push(@Result, $1, $');
    }
    elsif($String =~ /^\s*(\\?)([\Q$SupportedQuotes\E])/is)
    { 
        my $BackSlash = $1 || "";
        my $OpenQuote = $2;
        my $CloseQuote = $OpenQuote;
        $CloseQuote = $QuotePairs{$OpenQuote} if $QuotePairs{$OpenQuote};
        
        if($BackSlash)
        {
            $String =~ /^\s*\\\Q$OpenQuote\E/i;
            my $Onset = $';
            $Onset =~ /\\\Q$CloseQuote\E/i;
            my $Rest = $';
            my $Item = $`;
            push(@Result, $Item, $Rest);
            
        }
        else
        {
            $String =~ /^\s*\Q$OpenQuote\E([^\Q$CloseQuote\E]*)\Q$CloseQuote\E/i;
            push(@Result, $1, $');
        };
    }
    else
    {
        push(@Result, "", $String);
    };
    return @Result;
};

# Now, start with the real work
#
# Control the output of the Content-type: text/html\n\n message
my $SupressContentType = 0;     
#
# Process a file
sub ProcessFile  # ($file_path)
{
    my $file_path = shift || return 0;
    
    # 
    # Generate a unique file handle (for recursions)
    my @SRClist = ();
    my $FileHandle = "file";
    my $n = 0;
    while(!eof($FileHandle.$n)) {++$n;};
    $FileHandle .= $n;
    #
    # Start HTML output
    # Use the default Content-type if this is NOT a raw file
    unless(($RawFilePattern && $ENV{'PATH_INFO'} =~ m@($RawFilePattern)$@i)
    || $SupressContentType)
    { 
	$ENV{'PATH_INFO'} =~ m@($FilePattern)$@i;
	my $ContentType = $ContentTypeTable{$1};
        print "Content-type: $ContentType\n";
        print "\n";
        $SupressContentType = 1;    # Content type has been printed
    };
    #
    # 
    # Get access to the actual data. This can be from RAM (by way of an 
    # environment variable) or by opening a file.
    #
    # Handle the use of RAM images (file-data is stored in the 
    # $CGI_FILE_CONTENTS environment variable)
    # Note that this environment variable will be cleared, i.e., it is strictly for
    # single-use only!
    if($ENV{$CGI_FILE_CONTENTS})
    {
        # File has been read already
        $_ = $ENV{$CGI_FILE_CONTENTS};
        # Sorry, you have to do the reading yourself (dynamic document creation?)
        # NOTE: you must read the whole document at once
        if($_ eq '-')
        {
            $_ = eval("\@_=('$file_path'); do{$ENV{$CGI_DATA_ACCESS_CODE}}");
        }
        else    # Clear environment variable
        {
            $ENV{$CGI_FILE_CONTENTS} = '-';
        };
    }
    # Open Only PLAIN TEXT files (or STDIN) and NO executable files (i.e., scripts). 
    # THIS IS A SECURITY FEATURE!
    elsif($file_path eq '-' || (-e "$file_path"  && -r _ && -T _ && -f _ && ! (-x _ || -X _) ))
    { 
        open($FileHandle, $file_path) || die "<h2>File not found</h2>\n";
        push(@OpenFiles, $file_path);
        $_ = <$FileHandle>;  # Read first line
    }
    else
    { 
        print "<h2>File not found</h2>\n";
        die $file_path;
    };
    #
    $| = 1;    # Flush output buffers
    #
    # Initialize variables 
    my $METAarguments = "";  # The CGI arguments from the latest META tag
    my @METAvalues = ();  # The ''-quoted CGI values from the latest META tag
    my $ClosedTag = 0;	# <TAG> </TAG> versus <TAG/>
    
    #
    # Send document to output
    # Process the requested document. 
    # Do a loop BEFORE reading input again (this catches the RAM/Database
    # type of documents).
    do {
        # Catch <SCRIPT LANGUAGE="PERL" TYPE="text/ssperl" > directives in $_
        # There can be more than 1 <SCRIPT> or META tags on a line
        while(/\<\s*(SCRIPT|META|DIV)\s/is)
        {
            my $directive = "";
            # Store rest of line
            my $Before = $`;
            my $ScriptTag = $&;
            my $After = $';
            my $TagType = uc($1);
            # The before part can be send to the output
            print $Before;
            
            # Read complete Tag from after and/or file
            until($After =~ /([^\\])\>/)
            { $After .= <$FileHandle>;};
            
            if($After =~ /([^\\])\>/)
            {  
                $ScriptTag .= $`.$&;  # Keep the Script Tag intact
                $After = $';
            }
            else
            {  
                die "Closing > not found";
            };
	    
	    # The tag could be closed by />, we handle this in the XML way
	    # and don't process any content (we ignore whitespace)
	    $ClosedTag = ($ScriptTag =~ m@[^\\]/\s*\>\s*$@) ? 1 : 0;
	    
            #
            # TYPE or CLASS?
            my $TypeName = ($TagType =~ /META/is) ? "CONTENT" : "TYPE";
	    $TypeName = "CLASS" if $TagType eq 'DIV';
	    
            # Parse <SCRIPT> or <META> directive
            # If NOT (TYPE|CONTENT)="text/ssperl" (i.e., $ServerScriptContentType), 
            # send the line to the output and go to the next loop
            my $CurrentContentType = "";
            if($ScriptTag =~ /(^|\s)$TypeName\s*=\s*/is)
            {
                my ($Type) = ExtractQuotedItem($');
                $Type =~ /^\s*([\w\/\-]+)\s*[\,\;]?/;
                $CurrentContentType = lc($1);   # Note: mime-types are "case-less"
            };
            
            # 
            # Not a known server-side content type, print and continue
            unless(($CurrentContentType =~ 
            /$ServerScriptContentType|$ShellScriptContentType/is) ||
            $ScriptingLanguages{$CurrentContentType})
            {
                print $ScriptTag;
                $_ = $After;
                next;
            };
            
            #
            # A known server-side content type, evaluate
            #
            # First, handle \> and \<
            $ScriptTag =~ s/\\\>/\>/isg;
            $ScriptTag =~ s/\\\</\</isg;
            
            # Extract the CGI, SRC, ID, IF and UNLESS attributes
            my %ScriptTagAttributes = ();
            while($ScriptTag =~ /(^|\s)(CGI|IF|UNLESS|SRC|ID)\s*=\s*/is)
            {
                my $Attribute = $2;
                my $Rest = $';
                my $Value = "";
                ($Value, $ScriptTag) = ExtractQuotedItem($Rest);
                $ScriptTagAttributes{uc($Attribute)} = $Value;
            };
            
            #
            # The attribute used to define the CGI variables
            # Extract CGI-variables from 
            # <META CONTENT="text/ssperl; CGI='' SRC=''">
            # <SCRIPT TYPE='text/ssperl' CGI='' SRC=''>
            # <DIV CLASS='text/ssperl' CGI='' SRC='' ID=""> tags
            if($ScriptTagAttributes{'CGI'})                
            {
                @ARGV = ();             # Reset ARGV
                $ARGC = 0;
                $METAarguments = "";    # Reset the META CGI arguments
                @METAvalues = ();
                my $Meta_CGI = $ScriptTagAttributes{'CGI'};
                
                # Process default values of variables ($<name> = 'default value')
                # Allowed quotes are '', "", ``, (), [], and {}
                while($Meta_CGI =~ /(^\s*|[^\\])([\$\@\%]?)([\w\-]+)\s*/is)
                {
                    my $varType = $2 || '$';    # Variable or list
                    my $name = $3;              # The Name
                    my $default = "";
                    $Meta_CGI = $';
                    
                    if($Meta_CGI =~ /^\s*\=\s*/is)
                    {
                        # Locate (any) default value
                        ($default, $Meta_CGI) = ExtractQuotedItem($'); # Cut the parameter from the CGI
                    };
                    $RemainingTag = $Meta_CGI;
                    
                    #
                    # Define CGI (or ENV) variable, initalize it from the
                    # Query string or the default value
                    #
                    # Also construct the @ARGV and @_ arrays. This allows other (SRC=) Perl 
                    # scripts to access the CGI arguments defined in the META tag
                    # (Not for CGI inside <SCRIPT> tags)
                    if($varType eq '$')
                    {
                        CGIexecute::defineCGIvariable($name, $default)
                        || die "INVALID CGI name/value pair ($name, $default)\n";
                        push(@METAvalues, "'".${"CGIexecute::$name"}."'");      
                        # Add value to the @ARGV list
                        push(@ARGV, ${"CGIexecute::$name"});
                        ++$ARGC;
                    }
                    elsif($varType eq '@')
                    {
                        CGIexecute::defineCGIvariableList($name, $default)
                        || die "INVALID CGI name/value list pair ($name, $default)\n";
                        push(@METAvalues, "'".join("'", @{"CGIexecute::$name"})."'");   
                        # Add value to the @ARGV list
                        push(@ARGV, @{"CGIexecute::$name"});
                        $ARGC = scalar(@CGIexecute::ARGV);
                    }
                    elsif($varType eq '%')
                    {
                        CGIexecute::defineCGIvariableHash($name, $default)
                        || die "INVALID CGI name/value hash pair ($name, $default)\n";
                        my @PairList = map {"$_ => ".${"CGIexecute::$name"}{$_}} keys(%{"CGIexecute::$name"});
                        push(@METAvalues, "'".join("'", @PairList)."'");   
                        # Add value to the @ARGV list
                        push(@ARGV, %{"CGIexecute::$name"});
                        $ARGC = scalar(@CGIexecute::ARGV);
                    };
                    
                    # Store the values for internal and later use
                    $METAarguments .= "$varType".$name.",";    # A string of CGI variable names
                    
                    push(@METAvalues, "\'".eval("\"$varType\{CGIexecute::$name\}\"")."\'"); # ALWAYS add '-quotes around values
                    
                };
            };
            
            # The IF (conditional execution) Attribute
            # Evaluate the condition and stop unless it evaluates to true 
            if($ScriptTagAttributes{'IF'})
            {
                my $IFcondition = $ScriptTagAttributes{'IF'};
                #
                # Convert SCRIPT calls, ./<script>
                $IFcondition =~ s@([\W]|^)\./([\S])@$1$SCRIPT_SUB$2@g;
                #
                # Convert FILE calls, ~/<file>
                $IFcondition =~ s@([\W])\~/([\S])@$1$HOME_SUB$2@g;
                #
                # Block execution if necessary
                unless(CGIexecute->evaluate($IFcondition))
                {
                    %ScriptTagAttributes = ();
                    $CurrentContentType = "";
                };
            };
            
            # The UNLESS (conditional execution) Attribute
            # Evaluate the condition and stop if it evaluates to true 
            if($ScriptTagAttributes{'UNLESS'})
            {
                my $UNLESScondition = $ScriptTagAttributes{'UNLESS'};
                #
                # Convert SCRIPT calls, ./<script>
                $UNLESScondition =~ s@([\W]|^)\./([\S])@$1$SCRIPT_SUB$2@g;
                #
                # Convert FILE calls, ~/<file>
                $UNLESScondition =~ s@([\W])\~/([\S])@$1$HOME_SUB$2@g;
                #
                # Block execution if necessary
                if(CGIexecute->evaluate($UNLESScondition))
                {
                    %ScriptTagAttributes = ();
                    $CurrentContentType = "";
                };
            };
            
            # The SRC (Source File) Attribute
            # Extract any source script files and add them in 
            # front of the directive
            # The SRC list should be emptied
            @SRClist = ();          
            my $SRCtag = "";
	    my $Prefix = 1;
            my $PrefixDirective = "";
	    my $PostfixDirective = "";
	    # There is a SRC attribute
            if($ScriptTagAttributes{'SRC'})
            {
                $SRCtag = $ScriptTagAttributes{'SRC'};
                # Remove "file://" prefixes
                $SRCtag =~ s@([^\w\/\\]|^)file\://([^\s\/\@\=])@$1$2@gis;
                # Expand script filenames "./Script"
                $SRCtag =~ s@([^\w\/\\]|^)\./([^\s\/\@\=])@$1$SCRIPT_SUB/$2@gis;
                # Expand script filenames "~/Script"
                $SRCtag =~ s@([^\w\/\\]|^)\~/([^\s\/\@\=])@$1$HOME_SUB/$2@gis;
                
                #
                # File source tags
                while($SRCtag =~ /\S/is)
                {
		    my $SRCdirective = "";
		    
		    # Pseudo file, just a switch to go from PREFIXING to POSTFIXING
		    # SRC files
		    if($SRCtag =~ /^[\s\;\,]*(POSTFIX|PREFIX)([^$FileAllowedChars]|$)/is)
		    {
		    	my $InsertionPlace = $1;
			$SRCtag = $2.$';
			
			$Prefix = $InsertionPlace =~ /POSTFIX/i ? 0 : 1;
			# Go to next round
			next;
		    }
                    # {}-blocks are just evaluated by "do"
                    elsif($SRCtag =~ /^[\s\;\,]*\{/is)
                    {
                        my $SRCblock = $';
                        if($SRCblock =~ /\}[\s\;\,]*([^\}]*)$/is)
                        {
                            $SRCblock = $`;
                            $SRCtag = $1.$';
                            # SAFEqx shell script blocks
                            if($CurrentContentType =~ /$ShellScriptContentType/is)
                            {
                                # Handle ''-quotes inside the script
                                $SRCblock =~ s/[\']/\\$&/gis;
                                #
                                $SRCblock = "print do { SAFEqx(\'".$SRCblock."\'); };'';";
                                $SRCdirective .= $SRCblock."\n";
                            }
                            # do { SRCblocks }
                            elsif($CurrentContentType =~ /$ServerScriptContentType/is)
                            {
                                $SRCblock = "print do { $SRCblock };'';";
                                $SRCdirective .= $SRCblock."\n";
                            }
                            else # The interpreter should handle this
                            {
                                push(@SRClist, "{ $SRCblock }");
                            };            
                            
                        }
                        else
                        { die "Closing \} missing\n";};
                    }
                    # Files are processed as Text or Executable files
                    elsif($SRCtag =~ /[\s\;\,]*([$FileAllowedChars]+)[\;\,\s]*/is)
                    {
                        my $SrcFile = $1;
                        $SRCtag = $';
                        # 
                        # We are handling one of the external interpreters
                        if($ScriptingLanguages{$CurrentContentType})
                        {
                            push(@SRClist, $SrcFile);
                        }
			# We are at the start of a DIV tag, just load all SRC files and/or URL's
                        elsif($TagType eq 'DIV') # All files are prepended in DIV's
                        {
				# $SrcFile is a URL pointing to an HTTP or FTP server
				if($SrcFile =~ m!^([a-z]+)\://!)
				{
					my $URLoutput = CGIscriptor::read_url($SrcFile);
					$SRCdirective .= $URLoutput;
				}
				# SRC file is an existing file
				elsif(-e "$SrcFile")
				{
					open(DIVSOURCE, "<$SrcFile") || die "<$SrcFile: $!\n";
					my $Content;
					while(sysread(DIVSOURCE, $Content, 1024) > 0)
					{
						$SRCdirective .= $Content;
					};
					close(DIVSOURCE);
				};
                        }
                        # Executable files are executed as 
                        # `$SrcFile 'ARGV[0]' 'ARGV[1]'`
                        elsif(-x "$SrcFile")
                        {
                            $SRCdirective .= "print \`$SrcFile @METAvalues\`;'';\n";
                        }
			# Handle 'standard' files, using ProcessFile
                        elsif((-T "$SrcFile" || $ENV{$CGI_FILE_CONTENTS})
                                && $SrcFile =~ m@($FilePattern)$@) # A recursion
                        {
                            #
                            # Do not process still open files because it can lead
                            # to endless recursions
                            if(grep(/^$SrcFile$/, @OpenFiles))
                            { die "$SrcFile allready opened (endless recursion)\n"};
                            # Prepare meta arguments
                            $SRCdirective .= '@ARGV = (' .$METAarguments.");\n" if $METAarguments;
			    # Process the file 
                            $SRCdirective .= "main::ProcessFile(\'$SrcFile\');'';\n";
                        }
                        elsif($SrcFile =~ m!^([a-z]+)\://!) # URL's are loaded and printed
                        {
                            $SRCdirective .= GET_URL($SrcFile);
                        }
                        elsif(-T "$SrcFile") # Textfiles are "do"-ed (Perl execution)
                        {
                            $SRCdirective .= '@ARGV = (' .$METAarguments.");\n" if $METAarguments; 
                            $SRCdirective .= "do \'$SrcFile\';'';\n";
                        }
                        else # This one could not be resolved (should be handled by BinaryMapFile)
                        {
                            $SRCdirective .= 'print "'.$SrcFile.' cannot be used"'."\n";
                        };
			
                    };
		    
		    # Postfix or Prefix
		    if($Prefix)
		    {
			    $PrefixDirective .= $SRCdirective;
		    }
		    else
		    {
			    $PostfixDirective .= $SRCdirective;				
		    };
                };
		# The prefix should be handled immediately
		$directive .= $PrefixDirective;
		$PrefixDirective = "";
            };
            
            #
            # Handle the content of the <SCRIPT></SCRIPT> tags
	    # Do not process the content of <SCRIPT/>
            if($TagType =~ /SCRIPT/is && !$ClosedTag)  # The <SCRIPT> TAG
            {
                my $EndScriptTag = "";
                #
                # Execute SHELL scripts with SAFEqx()
                if($CurrentContentType =~ /$ShellScriptContentType/is)
                {
                    $directive .= "SAFEqx(\'";
                };                 
                #
                # Extract Program
                while($After !~ /\<\s*\/SCRIPT[^\>]*\>/is && !eof($FileHandle))
                {    
                    $After .= <$FileHandle>
                };
                
                if($After =~ /\<\s*\/SCRIPT[^\>]*\>/is)
                {    
                    $directive .= $`;
                    $EndScriptTag = $&;
                    $After = $';
                }
                else
                {   
                    die "Missing </SCRIPT> end tag in $ENV{'PATH_INFO'}\n";
                };
                #
                # Process only when content should be executed
                if($CurrentContentType)
                {
                    #
                    # Remove all comments from Perl scripts 
                    # (NOT from OS shell scripts)
                    $directive =~ s/[^\\\$]\#[^\n\f\r]*([\n\f\r])/\1/g 
                    if $CurrentContentType =~ /$ServerScriptContentType/i;
                    #
                    # Convert SCRIPT calls, ./<script>
                    $directive =~ s@([\W]|^)\./([\S])@$1$SCRIPT_SUB$2@g;
                    #
                    # Convert FILE calls, ~/<file>
                    $directive =~ s@([\W])\~/([\S])@$1$HOME_SUB$2@g;
                    #
                    # Execute SHELL scripts with SAFEqx(), closing bracket
                    if($CurrentContentType =~ /$ShellScriptContentType/i)
                    {
                        # Handle ''-quotes inside the script
                        $directive =~ /SAFEqx\(\'/;
                        $directive = $`.$&;
                        my $Executable = $';
                        $Executable =~ s/[\']/\\$&/gs;
                        #
                        $directive .= $Executable."\');";  # Closing bracket
                    };
                }
                else
                {
                    $directive = "";
                };
            }
            # Handle the content of the <DIV></DIV> tags
	    # Do not process the content of <DIV/>
            elsif($TagType eq 'DIV' && !$ClosedTag)  # The <DIV> TAGs
            {
                my $EndScriptTag = "";
                #
                # Extract Text
                while($After !~ /\<\s*\/$TagType[^\>]*\>/is && !eof($FileHandle))
                {    
                    $After .= <$FileHandle>
                };
                
                if($After =~ /\<\s*\/$TagType[^\>]*\>/is)
                {    
                    $directive .= $`;
                    $EndScriptTag = $&;
                    $After = $';
                }
                else
                {   
                    die "Missing </$TagType> end tag in $ENV{'PATH_INFO'}\n";
                };

		# Add the Postfixed directives (but only when it contains something printable)
		$directive .= "\n".$PostfixDirective if $PostfixDirective =~ /\S/;
		$PostfixDirective = "";
	    
                #
                # Process only when content should be handled
                if($CurrentContentType)
                {
		    #
		    # Get the name (ID), and clean it (i.e., remove anything that is NOT part of
		    # a valid Perl name). Names should not contain $, but we can handle it.
		    my $name = $ScriptTagAttributes{'ID'};
		    $name =~ /^\s*[\$\@\%]?([\w\-]+)/;
		    $name = $1;
		    #
		    # Assign DIV contents to $NAME value OUTSIDE the CGI values!
		    CGIexecute::defineCGIexecuteVariable($name, $directive);
		    $directive = "";
                };
		
		# Nothing to execute
                $directive = "";
            };
	    
            #
            # Handle Foreign scripting languages
            if($ScriptingLanguages{$CurrentContentType})
            {
                my $newDirective = "";
                $newDirective .= OpenForeignScript($CurrentContentType); # Only if not already done
                $newDirective .= PrefixForeignScript($CurrentContentType);
                $newDirective .= InsertForeignScript($CurrentContentType, $directive, @SRClist);
                $newDirective .= PostfixForeignScript($CurrentContentType);
                $newDirective .= CloseForeignScript($CurrentContentType); # This shouldn't be necessary
                
                $newDirective .= '"";\n';
                #
                $directive = $newDirective;
                
            };
	    
	    # Add the Postfixed directives (but only when it contains something printable)
	    $directive .= "\n".$PostfixDirective if $PostfixDirective =~ /\S/;
	    $PostfixDirective = "";
	    
            #
            # EXECUTE the script and print the results
            #
            # Use this to debug the program
            # print STDERR "Directive $CGI_Date: \n", $directive, "\n\n";
            #
            my $Result = CGIexecute->evaluate($directive) if $directive; # Evaluate as PERL code
            $Result =~ s/\n$//g;            # Remove final newline
            #
            # Print the Result of evaluating the directive
            # (this will handle LARGE, >64 kB output)
            my $BytesWritten = 1;
            while($Result && $BytesWritten)
            {
                $BytesWritten = syswrite(STDOUT, $Result, 64);
                $Result = substr($Result, $BytesWritten);
            };
            # print $Result;  # Could be used instead of above code
            #
            # Store result if wanted, i.e., if $CGIscriptorResults has been
            # defined in a <META> tag.
            push(@CGIexecute::CGIscriptorResults, $Result) 
            if exists($default_values{'CGIscriptorResults'});
            #
            # Process the rest of the input line (this could contain 
            # another directive)
            $_ = $After;
        };
        print $_;
    } while(<$FileHandle>);  # Read and Test AFTER first loop!
    
    close ($FileHandle);
    die "Error in recursion\n" unless pop(@OpenFiles) == $file_path;

}
#   
###############################################################################
#
# Call the whole package
#
sub Handle_Request
{
    my $file_path = "";
    
    # Initialization Code
    Initialize_Request();
    
    # SECURITY: ACCESS CONTROL
    Access_Control();
    
    # Start (HTML) output and logging
    $file_path = Initialize_output();
    
    # Record which files are still open (to avoid endless recursions)
    my @OpenFiles = (); 
    
    # Record whether the default HTML ContentType has already been printed
    # but only if the SERVER uses HTTP or some other protocol that might interpret
    # a content MIME type.
    
    $SupressContentType = !("$ENV{'SERVER_PROTOCOL'}" =~ /($ContentTypeServerProtocols)/i);
    
    # Process the specified file
    ProcessFile($file_path) if $file_path ne $SS_PUB;
    
    # Cleanup all open external (foreign) interpreters
    CloseAllForeignScripts();
    
    #
    ""  # SUCCESS
}
#
# Make a single call to handle an (empty) request
Handle_Request();
#
#
# END OF PACKAGE MAIN
#
#
####################################################################################
#
# The CGIEXECUTE PACKAGE
#
####################################################################################
#
# Isolate the evaluation of directives as PERL code from the rest of the program.
# Remember that each package has its own name space. 
# Note that only the FIRST argument of execute->evaluate is actually evaluated,
# all other arguments are accessible inside the first argument as $_[0] to $_[$#_].
#
package CGIexecute;

sub evaluate
{
    my $self = shift;
    my $directive = shift;
    $directive = eval($directive);
    warn $@ if $@;                  # Write an error message to STDERR
    $directive;                     # Return value of directive 
}

#
# defineCGIexecuteVariable($name [, $value]) -> 0/1
#
# Define and intialize variables inside CGIexecute
# Does no sanity checking, for internal use only
#
sub defineCGIexecuteVariable   # ($name [, $value]) -> 0/1
{
    my $name = shift || return 0;                   # The Name
    my $value = shift || "";          # The value

    ${$name} = $value;
        
    return 1;
};
#
# defineCGIvariable($name [, $default]) -> 0/1
#
# Define and intialize CGI variables
# Tries (in order) $ENV{$name}, the Query string and the
# default value. 
# Removes all '-quotes etc.
#
sub defineCGIvariable   # ($name [, $default]) -> 0/1
{
    my $name = shift || return 0;                   # The Name
    my $default = shift || "";          # The default value
    
    # Remove \-quoted characters
    $default =~ s/\\(.)/$1/g;
    # Store default values
    $::default_values{$name} = $default if $default;         
    
    # Process variables
    my $temp = undef;
    # If there is a user supplied value, it replaces the 
    # default value.
    #
    # Environment values have precedence
    if(exists($ENV{$name}))
    {
        $temp = $ENV{$name};
    }
    # Get name and its value from the query string
    elsif($ENV{QUERY_STRING} =~ /$name/) # $name is in the query string
    { 
        $temp = ::YOUR_CGIPARSE($name);
    }
    # Defined values must exist for security
    elsif(!exists($::default_values{$name}))
    {
        $::default_values{$name} = undef;
    };
    #
    # SECURITY, do not allow '- and `-quotes in 
    # client values. 
    # Remove all existing '-quotes
    $temp =~ s/([\r\f]+\n)/\n/g;                # Only \n is allowed                       
    $temp =~ s/[\']/&#8217;/igs;                # Remove all single quotes
    $temp =~ s/[\`]/&#8216;/igs;                # Remove all backtick quotes
    # If $temp is empty, use the default value (if it exists)
    unless($temp =~ /\S/ || length($temp) > 0)  # I.e., $temp is empty
    {  
        $temp = $::default_values{$name};
        # Remove all existing '-quotes
        $temp =~ s/([\r\f]+\n)/\n/g; # Only \n is allowed                          
        $temp =~ s/[\']/&#8217;/igs;            # Remove all single quotes
        $temp =~ s/[\`]/&#8216;/igs;            # Remove all backtick quotes
    }
    else  # Store current CGI values and remove defaults
    {
        $::default_values{$name} = $temp;
    };
    # Define the CGI variable and its value (in the execute package)
    ${$name} = $temp;
    
    # return SUCCES
    return 1;
};

sub defineCGIvariableList  # ($name [, $default]) -> 0/1)
{
    my $name = shift || return 0;                   # The Name
    my $default = shift || "";          # The default value
    
    # Defined values must exist for security
    if(!exists($::default_values{$name}))
    {
        $::default_values{$name} = $default;
    };
    
    my @temp = ();
    #
    #
    # For security: 
    # Environment values have precedence
    if(exists($ENV{$name}))
    {
        push(@temp, $ENV{$name});
    }
    # Get name and its values from the query string
    if($ENV{QUERY_STRING} =~ /$name/) # $name is in the query string
    { 
        push(@temp, ::YOUR_CGIPARSE($name, 1)); # Extract LIST
    }
    else
    {
        push(@temp, $::default_values{$name});
    };
    
    #
    # SECURITY, do not allow '- and `-quotes in 
    # client values. 
    # Remove all existing '-quotes
    @temp =  map {s/([\r\f]+\n)/\n/g; $_} @temp;    # Only \n is allowed                           
    @temp =  map {s/[\']/&#8217;/igs; $_} @temp;        # Remove all single quotes
    @temp =  map {s/[\`]/&#8216;/igs; $_} @temp;        # Remove all backtick quotes
    
    # Store current CGI values and remove defaults
    $::default_values{$name} = $temp[0];
    
    # Define the CGI variable and its value (in the execute package)
    @{$name} = @temp;
    
    # return SUCCES
    return 1;
};

sub defineCGIvariableHash  # ($name [, $default]) -> 0/1) Note: '$name{""} = $default';
{
    my $name = shift || return 0;                   # The Name
    my $default = shift || "";          # The default value
    
    # Defined values must exist for security
    if(!exists($::default_values{$name}))
    {
        $::default_values{$name} = $default;
    };
    
    my %temp = ();
    #
    #
    # For security: 
    # Environment values have precedence
    if(exists($ENV{$name}))
    {
        $temp{""} = $ENV{$name};
    }
    # Get name and its values from the query string
    if($ENV{QUERY_STRING} =~ /$name/) # $name is in the query string
    { 
        %temp = ::YOUR_CGIPARSE($name, -1); # Extract HASH table
    }
    elsif($::default_values{$name} ne "")
    {
        $temp{""} = $::default_values{$name};
    };
    
    #
    # SECURITY, do not allow '- and `-quotes in 
    # client values. 
    # Remove all existing '-quotes
    my $Key;
    foreach $Key (keys(%temp))
    {
        $temp{$Key} =~ s/([\r\f]+\n)/\n/g;                # Only \n is allowed                       
        $temp{$Key} =~ s/[\']/&#8217;/igs;                # Remove all single quotes
        $temp{$Key} =~ s/[\`]/&#8216;/igs;                # Remove all backtick quotes
    };
    
    # Store current CGI values and remove defaults
    $::default_values{$name} = $temp{""};
    
    # Define the CGI variable and its value (in the execute package)
    %{$name};
    my $tempKey;
    foreach $tempKey (keys(%temp))
    {
    	${$name}{$tempKey} = $temp{$tempKey};
    };
    
    # return SUCCES
    return 1;
};

#
# SAFEqx('CommandString')
#
# A special function that is a safe alternative to backtick quotes (and qx//)
# with client-supplied CGI values. All CGI variables are surrounded by
# single ''-quotes (except between existing \'\'-quotes, don't try to be
# too smart). All variables are then interpolated. Simple (@) lists are 
# expanded with join(' ', @List), and simple (%) hash tables expanded 
# as a list of "key=value" pairs. Complex variables, e.g., @$var, are
# evaluated in a scalar context (e.g., as scalar(@$var)). All occurrences of
# $@% that should NOT be interpolated must be preceeded by a "\".
# If the first line of the String starts with "#! interpreter", the 
# remainder of the string is piped into interpreter (after interpolation), i.e.,
# open(INTERPRETER, "|interpreter");print INTERPRETER remainder;
# just like in UNIX. There are  some problems with quotes. Be carefull in
# using them. You do not have access to the output of any piped (#!)
# process! If you want such access, execute 
# <SCRIPT TYPE="text/osshell">echo "script"|interpreter</SCRIPT> or  
# <SCRIPT TYPE="text/ssperl">$resultvar = SAFEqx('echo "script"|interpreter');
# </SCRIPT>.
#
# SAFEqx ONLY WORKS WHEN THE STRING ITSELF IS SURROUNDED BY SINGLE QUOTES 
# (SO THAT IT IS NOT INTERPOLATED BEFORE IT CAN BE PROTECTED)
sub SAFEqx   # ('String') -> result of executing qx/"String"/
{
    my $CommandString = shift;
    my $NewCommandString = "";
    #
    # Only interpolate when required (check the On/Off switch)
    unless($CGIscriptor::NoShellScriptInterpolation)
    {
        #
        # Handle existing single quotes around CGI values
        while($CommandString =~ /\'[^\']+\'/s)
        {
            my $CurrentQuotedString = $&;
            $NewCommandString .= $`;
            $CommandString = $';  # The remaining string
            # Interpolate CGI variables between quotes 
            # (e.g., '$CGIscriptorResults[-1]')
            $CurrentQuotedString =~ 
            s/(^|[^\\])([\$\@])((\w*)([\{\[][\$\@\%]?[\:\w\-]+[\}\]])*)/if(exists($main::default_values{$4})){
                "$1".eval("$2$3")}else{"$&"}/egs;
                #
                # Combine result with previous result
                $NewCommandString .= $CurrentQuotedString;
            };
            $CommandString = $NewCommandString.$CommandString;
            #
            # Select known CGI variables and surround them with single quotes, 
            # then interpolate all variables
            $CommandString =~ 
            s/(^|[^\\])([\$\@\%]+)((\w*)([\{\[][\w\:\$\"\-]+[\}\]])*)/
            if($2 eq '$' && exists($main::default_values{$4})) 
            {"$1\'".eval("\$$3")."\'";} 
            elsif($2 eq '@'){$1.join(' ', @{"$3"});}
            elsif($2 eq '%'){my $t=$1;map {$t.=" $_=".${"$3"}{$_}}
            keys(%{"$3"});$t}
            else{$1.eval("${2}$3");
        }/egs;
        #
        # Remove backslashed [$@%]
        $CommandString =~ s/\\([\$\@\%])/$1/gs;
    };
    #
    # Debugging
    # return $CommandString;
    # 
    # Handle UNIX style "#! shell command\n" constructs as
    # a pipe into the shell command. The output cannot be tapped.
    my $ReturnValue = "";
    if($CommandString =~ /^\s*\#\!([^\f\n\r]+)[\f\n\r]/is)
    {
        my $ShellScripts = $';
        my $ShellCommand = $1;
        open(INTERPRETER, "|$ShellCommand") || die "\'$ShellCommand\' PIPE not opened: &!\n";
        select(INTERPRETER);$| = 1;
        print INTERPRETER $ShellScripts;
        close(INTERPRETER);
        select(STDOUT);$| = 1;
    }
    # Shell scripts which are redirected to an existing named pipe. 
    # The output cannot be tapped.
    elsif($CGIscriptor::ShellScriptPIPE)
    {
        CGIscriptor::printSAFEqxPIPE($CommandString);
    }
    else  # Plain ``-backtick execution
    {
        # Execute the commands
        $ReturnValue = qx/$CommandString/;
    };
    return $ReturnValue;
}

####################################################################################
#
# The CGIscriptor PACKAGE
#
####################################################################################
#
# Isolate the evaluation of CGIscriptor functions, i.e., those prefixed with 
# "CGIscriptor::"
#
package CGIscriptor;

#
# The Interpolation On/Off switch
my $NoShellScriptInterpolation = undef;
# The ShellScript redirection pipe
my $ShellScriptPIPE = undef;
#
# Open a named PIPE for SAFEqx to receive ALL shell scripts
sub RedirectShellScript   # ('CommandString')
{
    my $CommandString = shift || undef;
    #
    if($CommandString)
    {
        $ShellScriptPIPE = "ShellScriptNamedPipe";
        open($ShellScriptPIPE, "|$CommandString") 
        || die "\'|$CommandString\' PIPE open failed: $!\n";
    }
    else
    {
        close($ShellScriptPIPE);                
        $ShellScriptPIPE = undef;
    }
    return $ShellScriptPIPE;
}
#
# Print to redirected shell script pipe
sub printSAFEqxPIPE # ("String") -> print return value
{
    my $String = shift || undef;
    #
    select($ShellScriptPIPE); $| = 1;
    my $returnvalue = print $ShellScriptPIPE ($String);
    select(STDOUT); $| = 1;
    #
    return $returnvalue;
}
#
# a pointer to CGIexecute::SAFEqx
sub SAFEqx   # ('String') -> result of qx/"String"/
{
    my $CommandString = shift;
    return CGIexecute::SAFEqx($CommandString);
}

#
# a pointer to CGIexecute::defineCGIvariable
sub defineCGIvariable   # ($name[, $default]) ->0/1
{
    my $name = shift;
    my $default = shift;
    return CGIexecute::defineCGIvariable($name, $default);
}

#
# Decode URL encoded arguments
sub URLdecode   # (URL encoded input) -> string
{
    my $output = "";
    my $char;
    my $Value;
    foreach $Value (@_)
    {
        my $EncodedValue = $Value; # Do not change the loop variable
        # Convert all "+" to " "
        $EncodedValue =~ s/\+/ /g;
        # Convert all hexadecimal codes (%FF) to their byte values
        while($EncodedValue =~ /\%([0-9A-F]{2})/i)
        {
            $output .= $`.chr(hex($1));
            $EncodedValue = $';
        };
        $output .= $EncodedValue;  # The remaining part of $Value
    };
    $output;
};

# Encode arguments as URL codes.
sub URLencode   # (input) -> URL encoded string
{
    my $output = "";
    my $char;
    my $Value;
    foreach $Value (@_)
    {
        my @CharList = split('', $Value);
        foreach $char (@CharList)
        { 
            if($char =~ /\s/)
            {  $output .= "+";}
            elsif($char =~ /\w\-/)
            {  $output .= $char;}
            else
            {  
                $output .= uc(sprintf("%%%2.2x", ord($char)));
            };
        };
    };
    $output;
};

# Extract the value of a CGI variable from the URL-encoded $string
# Also extracts the data blocks from a multipart request. Does NOT
# decode the multipart blocks
sub CGIparseValue    # (ValueName [, URL_encoded_QueryString [, \$QueryReturnReference]]) -> Decoded value
{
    my $ValueName = shift;
    my $QueryString = shift || $main::ENV{'QUERY_STRING'};
    my $ReturnReference = shift || undef;
    my $output = "";
    #
    if($QueryString =~ /(^|\&)$ValueName\=([^\&]*)(\&|$)/)
    {
        $output = URLdecode($2);
        $$ReturnReference =  $' if ref($ReturnReference);
    }
    # Get multipart POST or PUT methods
    elsif($main::ENV{'CONTENT_TYPE'} =~ m@(multipart/([\w\-]+)\;\s+boundary\=([\S]+))@i)
    {
        my $MultipartType = $2;
        my $BoundaryString = $3;
        # Remove the boundary-string
        my $temp = $QueryString;
        $temp =~ /^\Q--$BoundaryString\E/m;
        $temp = $';
        #
        # Identify the newline character(s), this is the first character in $temp
        my $NewLine = "\r\n";    # Actually, this IS the correct one
        unless($temp =~ /^(\-\-|\r\n)/)   # However, you never realy can be sure
        {
            $NewLine = "\r\n" if $temp =~ /^(\r\n)/;      # Double (CRLF, the correct one)
            $NewLine = "\n\r" if $temp =~ /^(\n\r)/;      # Double
            $NewLine = "\n"   if $temp =~ /^([\n])/;      # Single Line Feed
            $NewLine = "\r"   if $temp =~ /^([\r])/;      # Single Return
        };
        #
        # search through all data blocks
        while($temp =~ /^\Q--$BoundaryString\E/m)
        {
            my $DataBlock = $`;
            $temp = $';
            # Get the empty line after the header
            $DataBlock =~ /$NewLine$NewLine/;
            $Header = $`;
            $output = $';
            my $Header = $`;
            $output = $';
            #
            # Remove newlines from the header
            $Header =~ s/$NewLine/ /g;
            # 
            # Look whether this block is the one you are looking for
            # Require the quotes!
            if($Header =~ /name\s*=\s*[\"\']$ValueName[\"\']/m)
            {
                my $i;
                for($i=length($NewLine); $i; --$i) 
                {
                    chop($output);
                };
                # OK, get out
                last;
            };
            # reinitialize the output
            $output = "";
        };
        $$ReturnReference =  $temp if ref($ReturnReference);
    }
    elsif($QueryString !~ /(^|\&)$ValueName\=/)  # The value simply isn't there
    {
        return undef;
        $$ReturnReference =  undef if ref($ReturnReference);
    }
    else
    {
        print "ERROR: $ValueName $main::ENV{'CONTENT_TYPE'}\n";
    };
    return $output;
}

#
# Get a list of values for the same ValueName. Uses CGIparseValue
#
sub CGIparseValueList   # (ValueName [, URL_encoded_QueryString]) -> List of decoded values
{
    my $ValueName = shift;
    my $QueryString = shift || $main::ENV{'QUERY_STRING'};
    my @output = ();
    my $RestQueryString;
    my $Value;
    while($QueryString && 
    (($Value = CGIparseValue($ValueName, $QueryString, \$RestQueryString)) 
    || defined($Value)))
    {
        push(@output, $Value);
        $QueryString = $RestQueryString;   # QueryString is consumed!
    };
    # ready, return list with values
    return @output;
}

sub CGIparseValueHash   # (ValueName [, URL_encoded_QueryString]) -> Hash table of decoded values
{
    my $ValueName = shift;
    my $QueryString = shift || $main::ENV{'QUERY_STRING'};
    my $RestQueryString;
    my %output = ();
    while($QueryString && $QueryString =~ /(^|\&)$ValueName([\w]*)\=/)
    {
        my $Key = $2;
        my $Value = CGIparseValue("$ValueName$Key", $QueryString, \$RestQueryString);
        $output{$Key} = $Value;
        $QueryString = $RestQueryString;   # QueryString is consumed!
    };
    # ready, return list with values
    return %output;
}

sub CGIparseForm    # ([URL_encoded_QueryString]) -> Decoded Form (NO multipart)
{
    my $QueryString = shift || $main::ENV{'QUERY_STRING'};
    my $output = "";
    #
    $QueryString =~ s/\&/\n/g;
    $output = URLdecode($QueryString);
    #
    $output;
}

# Extract the header of a multipart CGI variable from the POST input 
sub CGIparseHeader    # (ValueName [, URL_encoded_QueryString]) -> Decoded value
{
    my $ValueName = shift;
    my $QueryString = shift || $main::ENV{'QUERY_STRING'};
    my $output = "";
    #
    if($main::ENV{'CONTENT_TYPE'} =~ m@(multipart/([\w\-]+)\;\s+boundary\=([\S]+))@i)
    {
        my $MultipartType = $2;
        my $BoundaryString = $3;
        # Remove the boundary-string
        my $temp = $QueryString;
        $temp =~ /^\Q--$BoundaryString\E/m;
        $temp = $';
        #
        # Identify the newline character(s), this is the first character in $temp
        my $NewLine = "\r\n";    # Actually, this IS the correct one
        unless($temp =~ /^(\-\-|\r\n)/)   # However, you never realy can be sure
        {
            $NewLine = "\n"   if $temp =~ /^([\n])/;      # Single Line Feed
            $NewLine = "\r"   if $temp =~ /^([\r])/;      # Single Return
            $NewLine = "\r\n" if $temp =~ /^(\r\n)/;      # Double (CRLF, the correct one)
            $NewLine = "\n\r" if $temp =~ /^(\n\r)/;      # Double
        };
        #
        # search through all data blocks
        while($temp =~ /^\Q--$BoundaryString\E/m)
        {
            my $DataBlock = $`;
            $temp = $';
            # Get the empty line after the header
            $DataBlock =~ /$NewLine$NewLine/;
            $Header = $`;
            my $Header = $`;
            #
            # Remove newlines from the header
            $Header =~ s/$NewLine/ /g;
            # 
            # Look whether this block is the one you are looking for
            # Require the quotes!
            if($Header =~ /name\s*=\s*[\"\']$ValueName[\"\']/m)
            {
                $output = $Header;
                last;
            };
            # reinitialize the output
            $output = "";
        };
    };
    return $output;
}

#
# Checking variables for security (e.g., file names and email addresses)
# File names are tested against the $::FileAllowedChars and $::BlockPathAccess variables
sub CGIsafeFileName    # FileName -> FileName or ""
{
    my $FileName = shift || "";
    return "" if $FileName =~ m?[^$::FileAllowedChars]?;
    return "" if $FileName =~ m@\.\.\Q$::DirectorySeparator\E@; # Higher directory not allowed
    return "" if $FileName =~ m@\Q$::DirectorySeparator\E\.\.@; # Higher directory not allowed
    return "" if $::BlockPathAccess && $FileName =~ m@$::BlockPathAccess@;                  # Invisible (blocked) file
    
    return $FileName;
}

sub CGIsafeEmailAddress    # email -> email or ""
{
    my $Email = shift || "";
    return "" unless $Email =~ m/^[\w\.\-]+[\@][\w\.\-\:]+$/;
    return $Email;
}

# Get a URL from the web. Needs main::GET_URL($URL) function
# (i.e., curl, snarf, or wget)
sub read_url	# ($URL) -> page/file
{
	my $URL = shift || return "";
	
	# Get the commands to read the URL, do NOT add a print command
	my $URL_command = main::GET_URL($URL, 1);
	# execute the commands, i.e., actually read it
	my $URLcontent = CGIexecute->evaluate($URL_command);
	
	# Ready, return the content.
	return $URLcontent;
};

################################################>>>>>>>>>>Start Remove
#
# BrowseDirs(RootDirectory [, Pattern, Start])
#
# usage:
# <SCRIPT TYPE='text/ssperl'>
# CGIscriptor::BrowseDirs('Sounds', '\.aifc$', 'Speech', 'DIRECTORY')
# </SCRIPT>
#
# Allows to browse subdirectories. Start should be relative to the RootDirectory,
# e.g., the full path of the directory 'Speech' is '~/Sounds/Speech'.
# Only files which fit /$Pattern/ and directories are displayed. 
# Directories down or up the directory tree are supplied with a
# GET request with the name of the CGI variable in the fourth argument (default
# is 'BROWSEDIRS'). So the correct call for a subdirectory could be:
# CGIscriptor::BrowseDirs('Sounds', '\.aifc$', $DIRECTORY, 'DIRECTORY')
#
sub BrowseDirs                  # (RootDirectory [, Pattern, Start, CGIvariable, HTTPserver]) -> Print HTML code
{
    my $RootDirectory = shift; # || return 0;
    my $Pattern = shift || '\S';
    my $Start = shift || "";
    my $CGIvariable = shift || "BROWSEDIRS";
    my $HTTPserver = shift || '';
    #
    $Start = CGIscriptor::URLdecode($Start);  # Sometimes, too much has been encoded
    $Start =~ s@//+@/@g;
    $Start =~ s@[^/]+/\.\.@@ig;
    $Start =~ s@^\.\.@@ig;
    $Start =~ s@/\.$@@ig;
    #
    my @Directory = glob("$::CGI_HOME/$RootDirectory/$Start");
    $CurrentDirectory = shift(@Directory);
    $CurrentDirectory = $' if $CurrentDirectory =~ m@(/\.\./)+@;
    $CurrentDirectory =~ s@^$::CGI_HOME@@g;
    print "<h1>";
    print "$CurrentDirectory" if $CurrentDirectory;
    print "</h1>\n";
    opendir(BROWSE, "$::CGI_HOME/$RootDirectory/$Start") || die "$::CGI_HOME/$RootDirectory/$Start $!";
    my @AllFiles = sort grep(!/^([\.]+[^\.]|\~)/, readdir(BROWSE));
    #
    # Print directories
    my $file;
    print "<pre><ul TYPE='NONE'>\n";
    foreach $file (@AllFiles)
    {
    	next unless -d "$::CGI_HOME/$RootDirectory/$Start/$file";
        # Check whether this file should be visible
        next if $::BlockPathAccess && 
	"/$RootDirectory/$Start/$file/" =~ m@$::BlockPathAccess@;
        
        my $NewURL = $Start ? "$Start/$file" : $file;
        $NewURL = CGIscriptor::URLencode($NewURL);
        print "<dt><a href='";
        print "$ENV{SCRIPT_NAME}" if $ENV{SCRIPT_NAME} !~ m@[^\w+\-/]@;
        print "$ENV{PATH_INFO}?$CGIvariable=$NewURL'>$file</a></dt>\n";
    };
    print "</ul></pre>\n";
    #
    # Print files
    print "<pre><ul TYPE='CIRCLE'>\n";
    my $TotalSize = 0;
    foreach $file (@AllFiles)
    {
    	next if $file =~ /^\./;
    	next if -d "$::CGI_HOME/$RootDirectory/$Start/$file";
    	next if -l "$::CGI_HOME/$RootDirectory/$Start/$file";
        # Check whether this file should be visible
        next if $::BlockPathAccess && 
	"$::CGI_HOME/$RootDirectory/$Start/$file" =~ m@$::BlockPathAccess@;
        
        if($file =~ m@$Pattern@)
        {
	    my $Date = localtime($^T - (-M "$::CGI_HOME/$RootDirectory/$Start/$file")*3600*24);
	    my $Size = -s "$::CGI_HOME/$RootDirectory/$Start/$file";
	    $Size = sprintf("%6.0F kB", $Size/1024);
	    my $Type = `file $::CGI_HOME/$RootDirectory/$Start/$file`;
	    $Type =~ s@\s*$::CGI_HOME/$RootDirectory/$Start/$file\s*\:\s*@@ig;
	    chomp($Type);
	    
            print "<li>";
	    print "<a href='$HTTPserver/$Start/$file'>" if $HTTPserver;
	    printf("%-40s", "$file</a>") if $HTTPserver;
	    printf("%-40s", "$file") unless $HTTPserver;
	    print "\t$Size\t$Date\t$Type";
        };
    };
    print "</ul></pre>";
    #
    return 1;
};

#
# ListDocs(Pattern [,ListType])
#
# usage:
# <SCRIPT TYPE=text/ssperl>
# CGIscriptor::ListDocs("/*", "dl");
# </SCRIPT> 
#
# This subroutine is very usefull to manage collections of independent
# documents. The resulting list will display the tree-like directory 
# structure. If this routine is too slow for online use, you can
# store the result and use a link to that stored file. 
#
# List HTML and Text files with title and first header (HTML)
# or filename and first meaningfull line (general text files). 
# The listing starts at the ServerRoot directory. Directories are
# listed recursively.
#
# You can change the list type (default is dl).
# e.g., 
# <dt><a href=<file.html>>title</a>
# <dd>First Header
# <dt><a href=<file.txt>>file.txt</a>
# <dd>First meaningfull line of text
#
sub ListDocs         # ($Pattern [, prefix]) e.g., ("/Books/*", [, "dl"])
{
    my $Pattern = shift;
    $Pattern =~ /\*/;
    my $ListType = shift || "dl";
    my $Prefix = lc($ListType) eq "dl" ? "dt" : "li";
    my $URL_root = "http://$::ENV{'SERVER_NAME'}\:$::ENV{'SERVER_PORT'}";
    my @FileList = glob("$::CGI_HOME$Pattern");
    my ($FileName, $Path, $Link);
    #
    # Print List markers
    print "<$ListType>\n";
    #
    # Glob all files
    File:  foreach $FileName (@FileList)
    {
        # Check whether this file should be visible
        next if $::BlockPathAccess && $FileName =~ m@$::BlockPathAccess@;
        
        # Recursively list files in all directories
        if(-d $FileName)
        {
            $FileName =~ m@([^/]*)$@;
            my $DirName = $1;
            print "<$Prefix>$DirName\n";
            $Pattern =~ m@([^/]*)$@;
            &ListDocs("$`$DirName/$1", $ListType);
            next;
        }
        # Use textfiles
        elsif(-T "$FileName")
        {
            open(TextFile, $FileName) || next;
        }
        # Ignore all other file types
        else
        { next;};
        #
        # Get file path for link
        $FileName =~ /$::CGI_HOME/;
        print "<$Prefix><a href=$URL_root$'>";
        # Initialize all variables
        my $Line = "";
        my $TitleFound = 0;
        my $Caption = "";
        my $Title = "";
        # Read file and step through
        while(<TextFile>)
        {
            chop $_;
            $Line = $_;
            # HTML files
            if($FileName =~ /\.ht[a-zA-Z]*$/i)
            {
                # Catch Title
                while(!$Title)
                {  
                    if($Line =~ m@<title>([^<]*)</title>@i) 
                    {  
                        $Title = $1;
                        $Line = $';
                    }
                    else
                    {  
                        $Line .= <TextFile> || goto Print;
                        chop $Line;
                    };
                };
                # Catch First Header
                while(!$Caption)
                {  
                    if($Line =~ m@</h1>@i) 
                    {  
                        $Caption = $`;
                        $Line = $';
                        $Caption =~ m@<h1>@i;
                        $Caption = $';
                        $Line = $`.$Caption.$Line;
                    }
                    else
                    {  
                        $Line .= <TextFile> || goto Print;
                        chop $Line;
                    };
                };
            }
            # Other text files
            else
            {
                # Title equals file name
                $FileName =~ /([^\/]+)$/;
                $Title = $1;
                # Catch equals First Meaningfull line
                while(!$Caption)
                {  
                    if($Line =~ /[A-Z]/ && 
                    ($Line =~ /subject|title/i || $Line =~ /^[\w,\.\s\?\:]+$/) 
                    && $Line !~ /Newsgroup/ && $Line !~ /\:\s*$/)
                    {
                        $Line =~ s/\<[^\>]+\>//g;             
                        $Caption = $Line;
                    }
                    else
                    {
                        $Line = <TextFile> || goto Print;
                    };
                };
            };
            Print: # Print title and subject
            print "$Title</a>\n";
            print "<dd>$Caption\n" if $ListType eq "dl";
            $TitleFound = 0;
            $Caption = "";
            close TextFile;
            next File;
        };
    };
    # Print Closing List Marker
    print "</$ListType>\n";
    "";   # Empty return value
};

#
# HTMLdocTree(Pattern [,ListType])
#
# usage:
# <SCRIPT TYPE=text/ssperl>
# CGIscriptor::HTMLdocTree("/Welcome.html", "dl");
# </SCRIPT> 
#
# The following subroutine is very usefull for checking large document
# trees. Starting from the root (s), it reads all files and prints out
# a nested list of links to all attached files. Non-existing or misplaced
# files are flagged. This is quite a file-i/o intensive routine
# so you would not like it to be accessible to everyone. If you want to
# use the result, save the whole resulting page to disk and use a link
# to this file. 
#
# HTMLdocTree takes an HTML file or file pattern and constructs nested lists 
# with links to *local* files (i.e., only links to the local server are
# followed). The list entries are the document titles.
# If the list type is <dl>, the first <H1> header is used too.
# For each file matching the pattern, a list is made recursively of all
# HTML documents that are linked from it and are stored in the same directory
# or a sub-directory. Warnings are given for missing files.
# The listing starts for the ServerRoot directory.
# You can change the default list type <dl> (<dl>, <ul>, <ol>).
#
%LinkUsed = ();

sub HTMLdocTree         # ($Pattern [, listtype]) 
# e.g., ("/Welcome.html", [, "ul"])
{
    my $Pattern = shift;
    my $ListType = shift || "dl";
    my $Prefix = lc($ListType) eq "dl" ? "dt" : "li";
    my $URL_root = "http://$::ENV{'SERVER_NAME'}\:$::ENV{'SERVER_PORT'}";
    my ($Filename, $Path, $Link);
    my %LocalLinks = {};
    #
    # Read files (glob them for expansion of wildcards)
    my @FileList = glob("$::CGI_HOME$Pattern");
    foreach $Path (@FileList)
    {
        # Get URL_path
        $Path =~ /$::CGI_HOME/;
        my $URL_path = $';
        # Check whether this file should be visible
        next if $::BlockPathAccess && $URL_path =~ m@$::BlockPathAccess@;
        
        my $Title = $URL_path;
        my $Caption = "";
        # Current file should not be used again
        ++$LinkUsed{$URL_path};
        # Open HTML doc
        unless(open(TextFile, $Path))
        {
            print "<$Prefix>$Title <blink>(not found)</blink><br>\n";
            next;
        };
        while(<TextFile>)
        {
            chop $_;
            $Line = $_;
            # Catch Title
            while($Line =~ m@<title>@i)
            {  
                if($Line =~ m@<title>([^<]*)</title>@i) 
                {  
                    $Title = $1;
                    $Line = $';
                }
                else
                {  
                    $Line .= <TextFile>;
                    chop $Line;
                };
            };
            # Catch First Header
            while(!$Caption && $Line =~ m@<h1>@i)
            {  
                if($Line =~ m@</h[1-9]>@i) 
                {  
                    $Caption = $`;
                    $Line = $';
                    $Caption =~ m@<h1>@i;
                    $Caption = $';
                    $Line = $`.$Caption.$Line;
                }
                else
                {  
                    $Line .= <TextFile>;
                    chop $Line;
                };
            };
            # Catch and print Links
            while($Line =~ m@<a href\=([^>]*)>@i)
            {
                $Link = $1;
                $Line = $';
                # Remove quotes
                $Link =~ s/\"//g;
                # Remove extras
                $Link =~ s/[\#\?].*$//g;
                # Remove Servername
                if($Link =~ m@(http://|^)@i)
                {
                    $Link = $';
                    # Only build tree for current server
                    next unless $Link =~ m@$::ENV{'SERVER_NAME'}|^/@;
                    # Remove server name and port
                    $Link =~ s@^[^\/]*@@g;
                    #
                    # Store the current link
                    next if $LinkUsed{$Link} || $Link eq $URL_path;
                    ++$LinkUsed{$Link};
                    ++$LocalLinks{$Link};
                };
            };
        };
        close TextFile;
        print "<$Prefix>";
        print "<a href=http://";
        print "$::ENV{'SERVER_NAME'}\:$::ENV{'SERVER_PORT'}$URL_path>";
        print "$Title</a>\n";
        print "<br>$Caption\n" 
        if $Caption && $Caption ne $Title && $ListType =~ /dl/i;
        print "<$ListType>\n";
        foreach $Link (keys(%LocalLinks))
        {
            &HTMLdocTree($Link, $ListType);
        };
        print "</$ListType>\n";
    };
};

###########################<<<<<<<<<<End Remove
#
# Make require happy
1;

=head1 NAME

CGIscriptor - 

=head1 DESCRIPTION

An HTML 4 compliant script/module for CGI-aware embeded 
Perl, shell-scripts, and other scripting languages, 
executed at the server side.   

=head1 README

Executes embeded Perl code in HTML pages with easy 
access to CGI variables. Also processes embeded shell 
scripts and scripts in any other language with an 
interactive interpreter (e.g., in-line Python, Tcl, 
Ruby, Awk, Lisp, Xlispstat, Prolog, M4, R, REBOL, Praat, 
sh, bash, csh, ksh).

CGIscriptor hides all the specifics and idiosyncrasies 
of correct output and CGI coding and naming. 
CGIscriptor complies with the W3C HTML 4.0 recommendations.

This Perl program will run on any WWW server that runs 
Perl scripts, just add a line like the following to your 
srm.conf file (Apache example):

ScriptAlias /SHTML/ /real-path/CGIscriptor.pl/

URL's that refer to http://www.your.address/SHTML/... will 
now be handled by CGIscriptor.pl, which can use a private 
directory tree (default is the DOCUMENT_ROOT directory tree, 
but it can be anywhere).

=head1 PREREQUISITES


=head1 COREQUISITES


=pod OSNAMES

Linux, *BSD, *nix

=pod SCRIPT CATEGORIES

Servers
CGI
Web

=cut
