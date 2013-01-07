###############################################
# rundir.pl
#
# Tells which directory the running Perl
# script resides in.
###############################################
# LARRY @ SMTP (Rubinow, Larry) version.
# Apparently this ver runs better than $Bill's.
# (listed below.
use Cwd 'cwd', 'abs_path';

$path = $0;                               # get what information we have
$path =~ s|\\|/|g;                        # normalize the dir dividers
$path =~ s|/\./|/|g;                      # remove redundant /. constructs
$path =~ s|/[^/]+/\.\.||g;                # remove /foobar/.. constructs
$path =~ s|([^/:]+)$||;                   # strip off filename for abs_path
$path = lc( abs_path( $path ) . "/$1" );  # run abs_path; restore filename
$path =~ s|/|\\|g;                        # use M$ backslash standards
print $path, "\n";

###################################################################

## $Bill Luebkert's version. 

#use Cwd;
#use File::Basename;
#
#if ($0 =~ /^\w:/ or $0 =~ m|^[\\\/]|) {
#  $path = $0;		         # got whole path - evrything is ok
#} else {
#  $path = &cwd;		      # get dir
#  $d = $0;		            # get relative script name
#	$d =~ s|^\.[\\\/]||;    # remove ./ if present
#	$path = "$path/$d";	   # append script to dir
#	$path =~ s|[\\\/]+|/|g;	# drop double /'s
#}
#
#$path =~ s|\\|/|g;
#
## or $path =~ s|/|\\|g; depending on your preference
## just to get all the slashes the same
#
#print $path, "\n";
## Doesn't remove ../'s from path.

###################################################################

## Another version.
## Don't know who the author is.

#sub is_abs_path
#{
# local $_ = shift if (@_);
# if ($^O eq 'MSWin32' || $^O eq 'dos')
#  {
#   #return m#^[a-z]:[\\/]#i;			# Problem area is here
#   return m#^[\\/]|[a-z]:[\\/]#i;		# This fixes it.
#  }
# elsif ($^O eq 'VMS')
#  {
#    # If it's a logical name, expand it.
#    $_ = $ENV{$_} while /^[\w\$\-]+$/ and $ENV{$_};
#    return m!^/! or m![<\[][^.\-\]>]! or /:[^<\[]/;
#  }
# else
#  {
#   return m#^/#;
#  }
#}
