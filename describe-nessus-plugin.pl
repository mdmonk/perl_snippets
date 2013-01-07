#!/usr/bin/perl -wT
#
# ----------------------------------------------------------------------
# describe-nessus-plugin
#
# Written by George A. Theall, theall@tifaware.com
#
# Copyright (c) 2003 - 2005, George A. Theall. All rights reserved.
#
# This module is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# $Id: describe-nessus-plugin 185 2005-09-28 02:38:10Z theall $
# ---------------------------------------------------------------------


=head1 NAME

describe-nessus-plugin - describes one or more Nessus plugins.


=head1 SYNOPSIS

  # Describe assorted NASL plugins related to MS SQL.
  describe-nessus-plugin /usr/local/lib/nessus/plugins/mssql*.nasl

  # Describe assorted NASL plugins related to Zope using 
  #   French strings whenever possible.
  describe-nessus-plugin -l francais /usr/local/lib/nessus/plugins/zope*.nasl

  # Show how the script parses the specified NASL plugin.
  describe-nessus-plugin -d wip.nasl

  # Report CVE ID(s) for all Oracle-related plugins.
  describe-nessus-plugin -f cve_id /usr/local/lib/nessus/plugins/oracle*.nasl

  # Same as above but avoid line-wrap.
  describe-nessus-plugin -f cve_id -w 999 /usr/local/lib/nessus/plugins/oracle*.nasl

  # Report all information except the description for all Apache-related plugins.
  describe-nessus-plugin -f _all_ -f '!description' /usr/local/lib/nessus/plugins/apache*.nasl


=head1 DESCRIPTION

This script prints out assorted descriptive information about each
Nessus plugin named on the commandline: id, name, family, category, etc. 
It works by reading the plugin directly and parsing out the information
of interest from the various C<script_*> functions in the its
description block.  As such, it only works with plugins written in NASL
(C<*.nasl>), not NASL include files (C<*.inc>) or plugins written in C
(C<*.nes>).  It does not require access to a Nessus server but does
require read access to the plugin. 

The decision about what information to report can be controlled either
by setting C<@funcs> in this script or by using the option
C<--functions> on the commandline.  In either case, function names
should be specified without the leading C<script_> string; for example,
C<cve_id> represents the information supplied as an argument to
C<script_cve_id>.  The order in which information is reported is
controlled by setting C<@func_order> in this script; there is no way to
change it via the commandline. 

Some of the descriptive information is available in languages other than
English -- typically French, but occasionally German and Portuguese. 
You can control the language used by adjusting the variable C<$lang> in
the source or with the option C<--language>; if information in the
desired language is not available, this script defaults to English, like
the NASL interpreter. 

B<describe-nessus-plugin> is written in Perl.  It should work on any
system with Perl 5.005 or better.  It also requires the following Perl
modules:

    o Carp
    o Getopt::Long
    o Text::Balanced
    o Text::Wrap

If your system does not have these modules installed already, visit CPAN
(L<http://search.cpan.org/>) for help.  Note that C<Text::Balanced> does
not work with versions of Perl older than 5.005; further, it is not
included with Perl distributions prior to 5.8.0 so you will probably
need to install it if you're running an older version of Perl. 


=head1 KNOWN BUGS AND CAVEATS

Currently, I am not aware of any bugs in this script. 

Understand that this script is not a NASL parser - on one hand, it may
not handle some constructs the language allows; on the other, it may
accept some the language prohibits. Still, it seems to properly process
all the scripts currently available via B<nessus-update-plugins>. 

Long lines in the output are wrapped and indented to agree with the
report format, which sometimes messes up formatting that plugin authors
have done. 

There is a limit to the size of the arguments passed to
C<script_cve_id()>, which sets the CVE IDs of the flaws tested by the
plugin.  Additional CVE IDs, which by convention are listed in comments,
are not reported by this script since they can not be reliably
identified. 

If you encounter a problem with this script, I encourage you to rerun it
in debug mode (eg, add C<-d> to your commandline) and examine the
resulting output before contacting me.  Often, this will enable you to
resolve the problem by yourself. 


=head1 DIAGNOSTICS

Failure to read a plugin or to isolate the description part will result
in a warning and cause that plugin to be skipped. 

Failure to identify function argument(s) will result in a warning and
cause that function to be skipped.  Failure to fully parse the arguments
will cause them to be reported as missing. 


=head1 SEE ALSO

L<http://cgi.nessus.org/plugins/>,
L<http://www.nessus.org/doc/nasl2_reference.pdf>,
L<http://www.tifaware.com/perl/describe-nessus-plugin/>. 

=cut


############################################################################
# Make sure we have access to the required modules.
use 5.005;
use strict;
use Carp;
use Getopt::Long;
use Text::Balanced qw(extract_bracketed extract_delimited extract_multiple);
use Text::Wrap;


############################################################################
# Initialize variables.
$| = 1;
my $DEBUG = 0;
my %cat_labels = (                      # see nessus-core/doc/WARNING.En and
                                        #     send_plug_info() in 
                                        #     nessus-core/nessusd/comm.c
    'ACT_ATTACK'                => 'attack',
    'ACT_DENIAL'                => 'denial',
    'ACT_DESTRUCTIVE_ATTACK'    => 'destructive_attack',
    'ACT_END'                   => 'unknown',
    'ACT_FLOOD'                 => 'flood',
    'ACT_GATHER_INFO'           => 'infos',
    'ACT_KILL_HOST'             => 'kill_host',
    'ACT_MIXED_ATTACK'          => 'mixed',
    'ACT_SCANNER'               => 'scanner',
    'ACT_SETTINGS'              => 'settings',
);
my @funcs = (                           # functions to report
    'id',
    'name',
    'version',
#    'copyright',
    'family',
    'category',
    'risk',
    'summary',
#    'description',
    'cve_id',
    'bugtraq_id',
    'xref',
#    'add_preference',
#    'dependencies',
#    'exclude_keys',
#    'require_keys',
#    'require_ports',
#    'require_udp_ports',
#    'timeout',
);
my %func_labels = (                     # descriptive labels for functions.
    'add_preference'    => 'Preference(s)',
    'bugtraq_id'        => 'BugTraq Id(s)',
    'category'          => 'Category',
    'copyright'         => 'Copyright',
    'cve_id'            => 'CVE Id(s)',
    'dependencies'      => 'Dependencies',
    'description'       => 'Description',
    'exclude_keys'      => 'KB Items That Must Be Unset',
    'family'            => 'Family',
    'id'                => 'Id',
    'name'              => 'Name',
    'require_keys'      => 'Required KB Items',
    'require_ports'     => 'Required TCP Ports',
    'require_udp_ports' => 'Required UDP Ports',
    'risk'              => 'Risk Factor',
    'summary'           => 'Summary',
    'timeout'           => 'Timeout',
    'version'           => 'Version',
    'xref'              => 'X-Reference(s)',
);
my @func_order = (                      # order of functions in output.
    'id',
    'name',
    'version',
    'copyright',
    'family',
    'category',
    'risk',
    'summary',
    'description',
    'cve_id',
    'bugtraq_id',
    'xref',
    'add_preference',
    'dependencies',
    'require_keys',
    'exclude_keys',
    'require_ports',
    'require_udp_ports',
    'timeout',
);
my $lang = 'english';       # 'deutsch', 'english', 'francais', or 'portugues'

# Subroutine prototypes.
sub find_args($;$);
sub eval_expr($);


############################################################################
# Process commandline arguments.
my %options = (
    'debug'       => \$DEBUG,
    'language'    => \$lang,
);
Getopt::Long::Configure('bundling');
GetOptions(
    \%options,
    'debug|d!',
    'functions|f=s@',
    'help|h|?!',
    'language|l=s',
    'width|w=i',
) or $options{help} = 1;
$0 =~ s/^.+\///;
if ($options{help} or @ARGV == 0) {
    warn "\n",
          "Usage: $0 [options] file(s)\n",
          "\n",
          "Options:\n",
          "  -?, -h, --help             Display this help and exit.\n",
          "  -d, --debug                Display copious debugging messages.\n",
          "  -f, --functions <funcs>    Display information about the functions <funcs>.\n",
          "                             Possible values are:\n",
          "                               'add_preference', 'bugtraq_id', 'category',\n",
          "                               'copyright', 'cve_id', 'dependencies',\n",
          "                               'description', 'exclude_keys', 'family', 'id',\n",
          "                               'name', 'require_keys', 'require_ports',\n",
          "                               'require_udp_ports', 'risk', 'summary',\n",
          "                               'timeout', 'version', 'xref', and '_all_'.\n",
          "                             Functions prefixed with '!' are ignored.\n",
          "  -l, --language <lang>      Use <lang> as language preference; must be one of\n",
          "                               'deutsch', 'english', 'francais', and\n",
          "                               'portugues'.\n",
          "  -w, --width <width>        Use <width> as the screen width (for controlling\n",
          "                               line wrap).\n";
    exit(9);
}

@funcs = split(/,\s*/, join(',', @{$options{functions}})) 
    if ($options{functions});


############################################################################
# Validate @funcs.
my @badfuncs;
foreach (@funcs) {
    my $func = $_;
    next if ($func eq '_all_');
    $func =~ s/^!//;
    push(@badfuncs, $_) unless (exists $func_labels{$func});
}
croak "Invalid function(s) - '" . join("' & '", @badfuncs) . "'!\n" 
    if (@badfuncs);


############################################################################
# Adjust selected functions if necessary.
my @negates = grep(s/^!//, @funcs);
@funcs = split(/,/, join(',', keys %func_labels))
    if (grep($_ eq '_all_', @funcs));
foreach my $negate (@negates) {
    @funcs = grep($_ ne $negate, @funcs);
}
if ($DEBUG) {
    warn "debug: functions to describe:\n";
    foreach (@funcs) {
        warn "debug:   $_\n";
    }
}


############################################################################
# Iterate over each plugin named on the commandline.
my $contents;                           # nb: scope must be global.
$Text::Wrap::columns = $options{width} if (exists $options{width});
$Text::Wrap::unexpand = 0;
foreach my $plugin (@ARGV) {

    # Read contents of plugin into a scalar.
    warn "debug: reading '$plugin'.\n" if $DEBUG;
    open(FILE, $plugin) or warn "Can't read '$plugin' - $!\n" and next;
    { local $/; $contents = <FILE>; }
    close(FILE);
    unless ($contents) {
        warn "*** '$plugin' is empty! ***\n";
        next;
    }
    unless ($contents =~ /(?s)if\s*\(\s*description\s*\)\s*{.+}/) {
        warn "*** '$plugin' does not have a description part! ***\n";
        next;
    }

    # Isolate description part of the plugin.
    my $desc;
    # nb: call extract_bracketed in array context to preserve $contents.
    ($desc) = extract_bracketed(
        $contents,
        '{}',
        '(?s).*?if\s*\(\s*description\s*\)\s*'
    );
    unless ($desc) {
        if ($@) {
            warn "*** extract_bracketed returned '$@' when parsing '$plugin'! ***\n";
        }
        else {
            warn "*** Can't isolate description part of '$plugin'! ***\n";
        }
        next;
    }
    # nb: we need to escape any backslashes in $desc to ensure
    #     things like extract_delimited work.
    $desc =~ s/\\/\\\\/g;

    # Parse description info.
    warn "debug:   parsing description info.\n" if $DEBUG;
    my %info;
    # nb: spurious leading characters are removed since extract_bracketed()
    #     expects string to start with '(' in order to isolate the argument.
    while ($desc =~ s/^(?s).*?script_(\w+)\s*\(/(/) {
        # nb: ignore it if part of a comment
        next if ($& =~ /(?s)#[^\n]*script_\w+\($/);
        my $func = $1;

        # Process only functions of interest.
        $func = 'dependencies' if ($func eq 'dependencie');
        next unless (
            grep(
                (
                    $func eq $_ or 
                    # nb: name is used in outputing info about add_preference.
                    ($func eq 'name' and $_ eq 'add_preference') or
                    # nb: risk is embedded in description, not a separate function.
                    ($func eq 'description' and $_ eq 'risk')
                ), 
                @funcs
            )
        );
        warn "debug:     function name is '$func'.\n" if $DEBUG;

        # Identify arguments.
        my $argstr = extract_bracketed(
            $desc,
            '()',
        );
        unless ($argstr and $argstr =~ s/^(?s)\(\s*(.+)\s*\)$/$1/) {
            warn "*** Can't identify arg string for '$func' in '$plugin'! ***\n";
            next;
        }
        # nb: unescape any backslashes.
        $argstr =~ s/\\\\/\\/g;
        warn "debug:       arg string at start is '$argstr'.\n" if $DEBUG;
        my @args = find_args($argstr);
        if ($DEBUG) {
            warn "debug:       args:\n";
            foreach (@args) {
                warn "debug:         '$_'.\n";
            }
        }

        # Adjust args for language preferences if applicable.
        # 
        # nb: according to the NASL 2 reference, named arguments are not 
        #     mixed with unnamed ones in the description functions so we 
        #     simply replace @args with the result.
        if (grep(/^$lang\s*:/, @args)) {
            @args = grep(s/^$lang\s*:\s*//, @args);
            if ($DEBUG) {
                warn "debug:       args adjusted for language pref ($lang):\n";
                foreach (@args) {
                    warn "debug:         '$_'\n";
                }
            }
        }
        if (grep(/^english\s*:/, @args)) {
            @args = grep(s/^english\s*:\s*//, @args);
            if ($DEBUG) {
                warn "debug:       args adjusted for english language:\n";
                foreach (@args) {
                    warn "debug:         '$_'\n";
                }
            }
        }

        # Evaluate / expand arguments.
        foreach (@args) {
            $_ = eval_expr($_);
        }
        my %named_args = map { /^(?s)(\w+)\s*:\s*(.*)$/ && $1 => $2 } @args;

        # Handle other named variables.
        if ($func eq 'add_preference') {
            if (exists($named_args{name}) and exists($named_args{type}) and exists($named_args{value})) {
                if ($named_args{type} eq 'radio') {
                    # nb: make radio-type preferences look nicer.
                    $named_args{value} =~ s/;/\n  /g;
                    $named_args{value} = "\n  " . $named_args{value};
                }
                @args = (
                    '[' . $named_args{type} . ']:' .
                    $named_args{name} . 
                    ' = ' . 
                    $named_args{value}
                );
            }
            else {
                warn "*** Can't handle arguments for 'add_preference' in '$plugin'! ***\n";
                next;
            }
        }
        elsif ($func eq 'xref') {
            if (exists($named_args{name}) and exists($named_args{value})) {
                @args = (
                    $named_args{name} . 
                    ':' . 
                    $named_args{value}
                );
            }
            else {
                warn "*** Can't handle arguments for 'xref' in '$plugin'! ***\n";
                next;
            }
        }

        # Regenerate $argstr.
        $argstr = join(", ", @args);

        # Fix up $argstr for a few functions.
        $argstr = $cat_labels{$argstr}
            if ($func eq 'category' and exists $cat_labels{$argstr});
        $argstr =~ s/^\$Revision: (\S+) \$$/$1/i if ($func eq 'version');

        # Identify risk if desired.
        #
        # nb: this must occur *before* removing newlines.
        if ($func eq 'description' and grep($_ eq 'risk', @funcs)) {
            # nb: pattern catches last instance of risk factor and uses
            #     rest of the line, until the last non-whitespace 
            #     character (to avoid trailing whitespace).
            if ($argstr =~ /.+(Risk|Risk\s+factor)\s*:\s*(\S+\s+\/\s+CVSS [^"']+|[^\n]*\S)/is) {
                $info{risk} = $2;
                $info{risk} =~ s/\n+/ /s;
            }
        }

        # Removing newlines except those separating paragraphs.
        $argstr =~ s/^\n*(.*)\n*$/$1/s;
        $argstr =~ s/\n{3,}/\n\n/sg;
        $argstr =~ s/(\S)[ \t]*\n(?!(\-|(Synopsis|Description|Note|See also|Solution|Risk(\s*Factor)?)\s*:))(\S)/$1 $5/sig;

        # Stash $argstr for the report, allowing for multiple occurences.
        warn "debug:       arg string at end is '$argstr'.\n" if $DEBUG;
        if (exists $info{$func}) {
            $info{$func} .= ($func eq 'add_preference' ? "\n" : ", ") . $argstr;
        }
        else {
            $info{$func} = $argstr;
        }
    }

    # Print report.
    # - determine maximal function label width
    my $width = 0;
    grep(
        $width = (
            $width < length($func_labels{$_}) ? 
                length($func_labels{$_}) : 
                $width
            ), 
        @funcs
    );
    # - account for colon.
    $width++;
    # - print report.
    print "$plugin\n";
    foreach my $func (@func_order) {
        next unless (grep($func eq $_, @funcs));
        my $label = exists($func_labels{$func}) ? $func_labels{$func} : $_;
        print wrap(
            "", 
            " " x ($width+4), 
            sprintf "  %-${width}s  %s", "$label:", $info{$func} || 'n/a'
        ), "\n";
    }
    print "\n";
}


############################################################################
# Finds arguments in the string $str delimited by $delim (or a comma if not
#   specified). Comments and empty lines are ignored.
#
# Returns an array of arguments or undef on failure.
#
sub find_args($;$) {
    confess "syntax error" unless (@_ == 1 or @_ == 2);
    my $str = shift;
    my $delim = shift || ',';

    warn "debug find_args: finding args in '$str' delimited by '$delim'.\n" if $DEBUG;

    my @args = extract_multiple(
        $str,
        [
            # - comment(s).
            sub {
                if ($_[0] =~ s/^(?s)(\s*\Q$delim\E\s*)?(\s*#.+?(\n|$))+//) {
                    # nb: need to reset \G for Text::Balanced routines.
                    pos($_[0]) = 1;
                    warn "debug find_args:   found comment.\n" if $DEBUG;
                    return undef;
                }
            },
            # - empty line(s).
            sub {
                if ($_[0] =~ s/^(?s)(\s*(\n|$))+//) {
                    # nb: need to reset \G for Text::Balanced routines.
                    pos($_[0]) = 1;
                    warn "debug find_args:   found empty line(s).\n" if $DEBUG;
                    return undef;
                }
            },
            # - end of statement.
            sub {
                if ($_[0] =~ s/^(?s)\s*;.*$//) {
                    # nb: need to reset \G for Text::Balanced routines.
                    pos($_[0]) = 1;
                    warn "debug find_args:   found end of statement.\n" if $DEBUG;
                    return undef;
                }
            },
            # - function.
            sub {
                if ($_[0] =~ s/^(?s)(\s*\Q$delim\E\s*)?(\w+\s*:\s*)?(ereg_replace|raw_string|string)\s*\(\s*/(/) {
                    # nb: $1 is leading garbage,
                    #     $2 is named argument, if any
                    #     $3 is function name
                    my $item = extract_bracketed($_[0], '(');
                    unless ($item) {
                        warn "*** extract_bracketed returned '$@'! ***\n" if ($@);
                        return "";
                    }
                    $item = $3 . $item;
                    $item = $2 . $item if ($2);
                    warn "debug find_args:   found $3 function '$item'.\n" if $DEBUG;
                    return $item;
                }
            },
            # - array value.
            sub {
                if ($_[0] =~ s/^(?s)(\s*\Q$delim\E\s*)?(\w+\s*:?\s*\w*)\s*\[/[/) {
                    my $item = extract_bracketed($_[0], '[');
                    unless ($item) {
                        warn "*** extract_bracketed returned '$@'! ***\n" if ($@);
                        return "";
                    }
                    $item = $2 . $item;
                    warn "debug find_args:   found bracketed item '$item'.\n" if $DEBUG;
                    return $item;
                }
            },
            # - quoted item.
            sub {
                if ($_[0] =~ s/^(?s)(\s*\Q$delim\E\s*)?(\w+\s*:\s*)?(['"])/$3/) {
                    # nb: $1 is leading garbage,
                    #     $2 is named argument, if any
                    #     $3 is quote character
                    # nb: extract_delimited by default uses '\' as an
                    #     escape when generating Friedl-style optimized
                    #     regexes. This will lead to problems if the
                    #     string contains something like "c:\". To 
                    #     get around this, I use an arbitrary value
                    #     (ASCII 0) that should never occur in the
                    #     string.
                    my $item = extract_delimited($_[0], $3, undef, "\000");
                    unless ($item) {
                        warn "*** extract_delimited returned '$@'! ***\n" if ($@);
                        return "";
                    }
                    $item = $2 . $item if ($2);
                    warn "debug find_args:   found quoted item '$item'.\n" if $DEBUG;
                    return $item;
                }
            },
            # - delimited item.
            sub {
                if ($_[0] =~ s/^(?s)(\s*\Q$delim\E?\s*)?([^\Q$delim\E;#]+)//) {
                    # nb: need to reset \G for Text::Balanced routines.
                    pos($_[0]) = 1;
                    my $item = $2;
                    $item =~ s/^(?s)\s*(.+?)\s*$/$1/;
                    warn "debug find_args:   found delimited item '$item'.\n" if $DEBUG;
                    return $item;
                }
            },
        ],
        undef,
        0
    );
    return @args;
}


############################################################################
# Evaluates the expression in the scalar $expr, handling quoted values, 
# string functions, sums, and references.
#
# Returns an array of arguments or undef on failure.
#
sub eval_expr($) {
    confess "syntax error" unless (@_ == 1);
    my $expr = shift;
    warn "debug eval_expr: evaluating '$expr'.\n" if $DEBUG;

    # Strip off name temporarily if it's a named argument.
    my $name;
    $name = $1 if ($expr =~ s/^(?s)(\w+)\s*:\s*//);

    # Evaluate quoted values.
    if ($expr =~ /^(?s)("[^"]*"|'[^']*')$/) {
        warn "debug eval_expr:   it's a quoted value.\n" if $DEBUG;
        $expr = $1;
        # nb: pattern above captures enclosing quotes.
        $expr =~ s/^(?s)(['"])(.*)\1$/$2/;
    }
    # Evaluate string functions.
    elsif ($expr =~ /^(?s)string\s*\(\s*(.+)\s*\)/) {
        warn "debug eval_expr:   it's a string function.\n" if $DEBUG;
        my @args;
        foreach (find_args($1)) {
            # nb: expand selected escape sequences.
            s/\\n/\n/gs;
            s/\\t/\t/gs;
            push(@args, eval_expr($_));
        }
        $expr = join('', @args);
    }
    # Evaluate ereg_replace functions.
    elsif ($expr =~ /^(?s)ereg_replace\s*\(\s*(.+)\s*\)/) {
        warn "debug eval_expr:   it's an ereg_replace function.\n" if $DEBUG;
        my @args = find_args($1);
        my %named_args = map { /^(?s)(\w+)\s*:\s*(.*)$/ && $1 => $2 } @args;
        if (exists($named_args{pattern}) and exists($named_args{replace}) and exists($named_args{string})) {
            my $pattern = eval_expr($named_args{pattern});
            my $replace = eval_expr($named_args{replace});
            my $str = eval_expr($named_args{string});
            if (exists($named_args{icase}) and $named_args{icase}) {
                $str =~ s/\Q$pattern\E/$replace/gsi;
            }
            else {
                $str =~ s/\Q$pattern\E/$replace/gs;
            }
            $expr = $str;
        }
    }
    # Evaluate raw_string functions.
    #
    # nb: this mirrors its NASL version incompletely - it only converts 
    #     integers to ASCII; other args are treated as strings but 
    #     otherwise left alone.
    elsif ($expr =~ /^(?s)raw_string\s*\(\s*(.+)\s*\)/) {
        warn "debug eval_expr:   it's a raw_string function.\n" if $DEBUG;
        $expr = '';
        foreach my $arg (find_args($1)) {
            $arg = eval_expr($arg);
            if ($arg =~ /^(\d+|0x[0-9a-f]{2})$/i) {
                $expr .= pack('C', oct($1));
            }
            else {
                $expr .= $arg;
            }
        }
    }
    # Evaluate sums.
    elsif ($expr =~ /^(?s)\s*("[^"]+"|'[^']+'|\S+)\s*\+\s*\S/) {
        warn "debug eval_expr:   it's a sum.\n" if $DEBUG;
        my @args;
        foreach (find_args($expr, '+')) {
            push(@args, eval_expr($_));
        }
        # nb: evaluate sum depending on whether there are any non-numeric args.
        if (grep(!/^[\d\.]$/, @args)) {
            $expr = join('', @args);
        }
        else {
            $expr = 0;
            foreach (@args) {
                $expr += $_;
            }
        }
    }
    # Evaluate references.
    #
    # nb: the convoluted regex pattern ensures we use definitions that
    #     aren't commented out and we focus only on the reference.
    elsif ($expr =~ /\w/ and $contents =~ /(?s)(^|\n)[^#\n]*\b\Q$expr\E\s*=\s*(("[^"]*"|'[^']*'|[^"';]*)+);/) {
        warn "debug eval_expr:   it's a reference.\n" if $DEBUG;
        $expr = eval_expr($2);
    }

    $expr = $name . ':' . $expr if ($name);
    warn "debug eval_expr: result is '$expr'.\n" if $DEBUG;
    return $expr;
}
