#!/usr/local/bin/perl
########################################################################
#I call this dfscan, and it works in a similar fashion to printf, et
#al. To use it, you just need to execute dfscan with a format string,
#and any arguments that you want passed on to df. So, to find out how
#much space is used on /usr, just type "dfscan %c /usr".
# -AJS
########################################################################
#
# Scan output of df and provide it via command-line options
# By Aaron Sherman (I-Kinetics, Inc.), 1993
#
# $Id$

$0	=~ s/^.*\///;
$usage	=  "Usage: $0 [-f <file>] [-h <hostname>] [--] <format> [<df options>]\n";
$file	= undef;
$format	= undef;
%mapping= (			# Mapping of format letter to field number
	    'f',0,		# Filesystem
	    't',1,		# Total space
	    'u',2,		# Space used
	    'a',3,		# Space available
	    'c',4,		# Capacity
	    'p',4,		# Percent (same as c)
	    'm',5,		# Mount-point
	    'h',6,		# Host
	    's',6		# Server (same as h)
	    );
$host	= `hostname`;
chop($host);

while(defined($arg = shift))
{
    if ($arg =~ s/^-//)
    {
	if ($arg eq 'f')	# File to read for df output
	{
	    die $usage unless(defined($file = shift));
	}
	elsif ($arg eq 'h')	# Host name
	{
	    die $usage unless(defined($host = shift));
	}
	elsif ($arg eq '-')	# End argument processing
	{
	    die $usage unless(defined($format = shift));
	    last;
	}
	else
	{
	    die $usage;
	}
    }
    else
    {
	$format = $arg;
	last;
    }
}

die $usage unless(defined($format));

@options = @ARGV;

if (defined($file))
{
    open(IN,"<$file") || die("$0: Cannot open \"$file\": $!\n");
}
else
{
    $cmd = 'df '.join(' ',@options);
    open(IN,"$cmd |") || die("$0: Cannot fork: $!\n");
}

while(<IN>)
{
    chop;

    next if (/^File/);		# Header

    if ($cont ne '')		# Continued lines
    {
	substr($_,0,0) = $cont;
	$cont = '';
    }
    else
    {
	if (/^\S+\s*$/)
	{
	    $cont = $_;
	    next;
	}
    }

    die "$0: Unexpected df output on line $.\n"
	unless((@fields = split(/\s+/,$_)) == 6);
    if ($fields[0] =~ /^(\S+):/)
    {
	push(@fields,$1);
    }
    else
    {
	push(@fields,$host);
    }
    $fields[4] =~ s/\%$//;

    &out($format,@fields);
}

exit 0;

sub out
{
    local($output,@f) = @_;
    local($i,$m);

    $output =~ s/\%(.)/($1 eq "%")?"%":&form($1,@f)/eg;
    print $@ if $@;
    print $output, "\n";
}

sub form
{
    local($c,@f) = @_;

    unless (defined($mapping{$c}))
    {
	die "$0: No mapping for \"\%$c\".\n";
    }
    $f[$mapping{$c}];
}
__END__

