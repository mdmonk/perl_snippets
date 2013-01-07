#!/usr/bin/perl -wT
#
# ----------------------------------------------------------------------
# update-nessus-plugins
#
# Written by George A. Theall, theall@tifaware.com
#
# Copyright (c) 2004-2010, George A. Theall. All rights reserved.
#
# This module is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# $Id: update-nessus-plugins 38 2010-01-30 02:34:16Z theall $
# ---------------------------------------------------------------------


=head1 NAME

update-nessus-plugins - Updates Nessus plugins with various options.


=head1 SYNOPSIS

  # updates nessus plugins. NB: this does nothing more than call
  #   nessus-update-plugins.
  update-nessus-plugins

  # creates a backup of old plugins and updates plugins.
  update-nessus-plugins -b

  # creates a backup, updates plugins, and prints a summary of 
  #   new / changed plugins.
  update-nessus-plugins -bs

  # updates plugins and parses new / changed plugins for errors.
  update-nessus-plugins -p


=head1 DESCRIPTION

This script updates to the latest set of plugins for Nessus and
optionally creates a backup of existing plugins, prints a summary of new
/ changed plugins, and parses updated plugins to check for errors.  It
calls B<nessus-update-plugins> to do the actual updates and
B<describe-nessus-plugin> to obtain descriptive information about
updated plugins for the summary report. 

Optional behaviour can be selected using one or more variables or
commandline arguments:

    Variable            Commandline         Purpose
    $backup             -b|--backup         Create a backup of existing
                                                plugins first.
    $DEBUG              -d|--debug          Turn on debugging. NB: this
                                                will still update plugins!
    @ignores            -i|--ignores        Ignore the specified files found
                                                in the plugins directory from
                                                the summary report and parse
                                                check.
    $parse              -p|--parse          Parse new / changed plugins
                                                and report whether errors
                                                exist.
    $summary            -s|--summary        Print a summary report of 
                                                new / changed plugins.

B<update-nessus-plugins> is written in Perl and calls
B<nessus-update-plugins> to actually update the plugins as well as
B<describe-nessus-plugin> to obtain descriptive information about new /
changed plugins.  It should work on any unix-like system with Perl 5 or
better (Perl 5.005 if you choose to generate summary reports).  It also
requires the following Perl modules:

    o Algorithm::Diff
    o Archive::Tar
    o Carp
    o Digest::SHA
    o File::Find
    o Getopt::Long
    o IO::Zlib (used by Archive::Tar to output file in compressed form)
    o POSIX

If your system does not have these modules installed already, visit CPAN
(L<http://search.cpan.org/>) for help.  Note that C<Algorithm::Diff>,
C<Archive::Tar>, and C<IO::Zlib> are not included with Perl
distributions and that C<Digest::SHA> is not included with Perl
distributions prior to 5.8.0 so you may need to install them yourself. 


=head1 KNOWN BUGS AND CAVEATS

Currently, I am not aware of any bugs in this script. 

You need a working version of B<nessus-update-plugins> to use this
script.  If you are having trouble getting that to work, please join
C<nessus@list.nessus.org> (L<http://list.nessus.org>) and ask for
assistance there. 

If you wish to generate summary reports of new / changed plugins, you
also need B<describe-nessus-plugin> version 2.01 or better, which is
available from L<http://www.tifaware.com/perl/describe-nessus-plugin/>. 

If you encounter an error similar to C<Insecure dependency in chdir
while running with -T switch at /usr/lib/perl/5.00503/File/Find.pm line
133> when trying to run B<update-nessus-plugins>, it's likely that
you're using an older version of the Perl module C<File::Find>. 
Versions distributed with Perl versions prior to 5.6.0 don't support the
C<no_chdir> option, which is used in this script to avoid problems with
taint checks.  The solution is to either upgrade C<File::Find>, upgrade
Perl itself, or disable taint checks (ie, remove the C<-T> option on the
first line of the script). 

The option for parsing new / changed plugins requires that the NASL
interpreter support the C<-p> option, which was introduced with Nessus
version 2.0.7. 

If you encounter a problem with this script, I encourage you to rerun it
in debug mode (eg, add C<-d> to your commandline) and examine the
resulting output before contacting me.  Often, this will enable you to
resolve the problem by yourself. 


=head1 DIAGNOSTICS

Failure to change into the plugin directory, to read a plugin, to create
a backup, or to run an external command (B<nessus-update-plugins>,
B<describe-nessus-plugin>, B<nasl>) will be treated as fatal errors and
reported to stderr using C<croak>. 

Warnings / errors from running B<describe-nessus-plugin> will be
reported to stderr using C<warn>. 


=head1 SEE ALSO

L<nessus-update-plugins(5)>,
L<http://www.tifaware.com/perl/describe-nessus-plugin/>,
L<http://www.tifaware.com/perl/update-nessus-plugins/>.

=cut


############################################################################
# Make sure we have access to the required modules.
use 5;
use strict;
use Algorithm::Diff qw(diff);
use Archive::Tar;
use Carp;
use Digest::SHA;
use File::Find;
use Getopt::Long;
use POSIX qw(strftime);


############################################################################
# Initialize variables.
delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};   # Make %ENV safer
$ENV{PATH} = '/bin:/usr/bin:/usr/local/bin:/usr/local/sbin:/opt/nessus/bin:/opt/nessus/sbin';    # nb: also passed to nessus-update-plugins
$| = 1;
my $DEBUG = 0;
my $backup = 0;                             # retain backup of old plugins?
my @ignores = (                             # ignore selected files from reports.
    'MD5',                                  #   - used to verify transfer starting with 2.1.0
);
my @info_funcs = (                          # descriptive funcs of interest.
                                            # nb: passed to describe-nessus-plugin
    'bugtraq_id',
    'category',
    'cve_id',
    'family',
    'id',
    'name',
    'risk',
    'summary',
    'version',
    'xref',
);
my $parse = 0;                              # parse new / changed plugins?
my $plugins_dir = '/opt/nessus/lib/nessus/plugins';  # where plugins are stored.
my $scratch_dir = '/tmp';                   # where archive is stored.
my $summary = 0;                            # summarize changes to plugins?


############################################################################
# Process commandline arguments.
my %options = (
    'backup'   => \$backup,
    'debug'    => \$DEBUG,
    'parse'    => \$parse,
    'summary'  => \$summary,
);
Getopt::Long::Configure('bundling');
GetOptions(
    \%options,
    'backup|b!',
    'debug|d!',
    'help|h|?!',
    'ignores|i=s@',
    'parse|p!',
    'summary|s!',
) or $options{help} = 1;
$0 =~ s/^.+\///;
if ($options{help} or @ARGV) {
    warn "\n",
        "Usage: $0 [options]\n",
        "\n",
       "Options:\n",
        "  -?, -h, --help             Display this help and exit.\n",
        "  -b, --backup               Create a backup of existing plugins first.\n",
        "  -d, --debug                Display copious debugging messages while\n",
        "                               running. Note: this will still update\n",
        "                               the plugins!\n",
        "  -i, --ignores <files>      Ignore the specified files in the plugins\n",
        "                               directory from the summary report and\n",
        "                               the parse check.\n",
        "  -p, --parse                Parse new / changed plugins and report\n",
        "                               whether errors exist.\n",
        "  -s, --summary              Print a summary report of new / changed plugins.\n";
    exit(9);
}
@ignores = split(/,\s*/, join(',', @{$options{ignores}}))
    if ($options{ignores});

chdir $plugins_dir or croak "Can't change directory to '$plugins_dir' - $!\n";


############################################################################
# Take a snapshot of plugins directory.
my %old_plugins;
if ($backup or $parse or $summary) {
    warn "debug: files in '$plugins_dir' before update:\n" if $DEBUG;
    find(
        { wanted => sub {
                if ($File::Find::dir eq '.' and -f and !/^\.\/\.desc/ and !/^\.\/\.bootstrap\.done$/ and /^\.\/(.+)$/) {
                    warn "debug:   $1\n" if $DEBUG;
                    $old_plugins{$1}++;
                }
            },
          no_chdir => 1,
          untaint => 1,
        },
        '.'
    );
}

if ($parse or $summary) {
    # Compute hashes for plugins so we can detect changes.
    warn "debug: computing hashes for plugins:\n" if $DEBUG;
    foreach my $file (sort keys %old_plugins) {
        open(FILE, $file) or croak "Can't open '$file' - $!\n";
        binmode(FILE);
        my $sha256 = Digest::SHA->new(256)->addfile(*FILE)->hexdigest;
        close(FILE);
        warn "debug:   $file -> $sha256\n" if $DEBUG;
        $old_plugins{$file} = $sha256;
    }
}


############################################################################
# Create backup.
my($archive, $tar);
if ($backup or $summary) {
    warn "debug: generating backup of files in '$plugins_dir'.\n" if $DEBUG;
    $archive = "$scratch_dir/plugins-pre-" . 
        strftime("%Y%m%d-%H%M%S", localtime) .
        ".tar.gz";
    $tar = Archive::Tar->new;
    $tar->add_files(keys %old_plugins);
    $tar->write($archive, 1) or
        croak "Can't create '$archive' - " . $tar->error() . "!\n";
    # nb: for some reason, it's necessary to reread the archive 
    #     into memory; otherwise, it will appear empty. :-(
    $tar->read($archive, 1);
}


############################################################################
# Update plugins.
warn "debug: updating plugins.\n" if $DEBUG;
my $cmd = 'nessus-update-plugins';
system $cmd;
my $rc = $? >> 8;
croak "Can't retrieve plugins ($rc)!\n" if ($rc);


############################################################################
# Take a second snapshot of plugins directory.
my %new_plugins;
if ($parse or $summary) {
    warn "debug: files in '$plugins_dir' after update:\n" if $DEBUG;
    find(
        { wanted => sub {
                if ($File::Find::dir eq '.' and -f and !/^\.\/\.desc/ and !/^\.\/\.bootstrap\.done$/ and /^\.\/(.+)$/) {
                    warn "debug:   $1\n" if $DEBUG;
                    $new_plugins{$1}++;
                }
            },
          no_chdir => 1,
          untaint => 1,
        },
        '.'
    );

    # Compute hashes anew.
    warn "debug: computing hashes for plugins:\n" if $DEBUG;
    foreach my $file (sort keys %new_plugins) {
        next if (! -f $file);

        open(FILE, $file) or croak "Can't open '$file' - $!\n";
        binmode(FILE);
        my $sha256 = Digest::SHA->new(256)->addfile(*FILE)->hexdigest;
        close(FILE);
        warn "debug:   $file -> $sha256\n" if $DEBUG;
        $new_plugins{$file} = $sha256;
    }
}


############################################################################
# Report changes.
if ($summary) {
    foreach my $plugin (sort keys %new_plugins) {
        next if (grep($plugin eq $_, @ignores));
        next unless (-f $plugin);

        # Determine status and skip plugins that weren't updated.
        #
        # nb: nessus-update-plugins doesn't remove plugins.
        my $status;
        if (exists $old_plugins{$plugin}) {
            if ($old_plugins{$plugin} eq $new_plugins{$plugin}) {
                next;
            }
            $status = 'changed';
        }
        else {
            $status = 'added';
        }

        # Get descriptive info about plugin.
        #
        # nb: we've already chdir'd into $plugin_dir.
        my($indent, @info);
        if ($plugin =~ /\.nasl$/) {
            my $cmd = 'describe-nessus-plugin ' . 
                '-f ' . join(',', @info_funcs) . ' ' .
                $plugin;
            open(CMD, "$cmd 2>&1 |") or croak "Can't run '$cmd' - $!\n";
            while (<CMD>) {
                chomp;
                warn "$_\n" if (/^\*{3} /); # nb: display any warnings / errors.
                next unless (/^\s/);
                $indent = length($1) - 4 if (!$indent and /^(.+?:\s*)/);
                push(@info, $_);
            }
            close(CMD);
            my $rc = $? >> 8;
            if ($rc or !$indent) {
                warn "*** Can't get descriptive info for '$plugin' (rc=$rc)! ***\n";
            }
        }
        # nb: some files don't have a descriptive part.
        elsif ($plugin !~ /\.(inc|nbin|nlib)$/) {
            warn "*** '$plugin' has an unsupported plugin type! ***\n";
        }
        $indent = 15 unless ($indent);

        # If plugin was changed, compute diffs.
        my $diffs;
        if ($status eq 'changed' and $plugin =~ /\.(inc|nasl)$/ and -T $plugin) {
            warn "debug:   computing diffs.\n" if $DEBUG;
            my @old = split(/\n/, $tar->get_content($plugin));

            my @new;
            open(NEW, $plugin) or croak "Can't read '$plugin' - $!\n";
            chomp(@new = <NEW>);
            close(NEW);

            $diffs = diff(\@old, \@new);
        }

        # Print report.
        #
        # nb: some of the files we're reporting on may be includes
        #     and hence won't have script ids.
        print "$plugin\n";
        printf "  %-${indent}s  %s\n", "Status:", $status;
        foreach (@info) {
            print "$_\n";
        }
        if ($diffs) {
            print "  Changes:\n";

            # nb: this block comes more or less from diff.pl as supplied 
            #     with Algorithm::Diff.
            foreach my $chunk (@$diffs) {
                foreach my $line (@$chunk) {
                    my($sign, $lineno, $text) = @$line;
                    printf "  %7d$sign %s\n", $lineno+1, $text;
                }
                print "    --------\n";
            }
        }
        print "\n";
    }
}


############################################################################
# Parse new / changed plugins to check for errors.
if ($parse) {
    my %errors;
    foreach my $plugin (keys %new_plugins) {
        next if (grep($plugin eq $_, @ignores));

        next if (
            exists $old_plugins{$plugin} and 
            ($old_plugins{$plugin} eq $new_plugins{$plugin})
        );
        next unless (-f $plugin);
        if ($plugin =~ /\.(nbin|nlib)$/ or -B $plugin) {
            next;
        }
        unless ($plugin =~ /\.(inc|nasl)$/) {
            warn "*** unsure if '$plugin' is a NASL script; skipped! ***\n";
            next;
        }
        warn "debug: parsing '$plugin'.\n" if $DEBUG;

        my $cmd = "nasl -p $plugin";
        open(CMD, "$cmd 2>&1 |") or croak "Can't run '$cmd' - $!\n";
        while (<CMD>) {
            warn "debug:   >>$_<<.\n" if $DEBUG;
            $errors{$plugin} .= $_;
        }
        close(CMD);
    }

    if (keys %errors) {
        print "Parse Errors in New / Changed Plugins\n";
        foreach my $plugin (sort keys %errors) {
            print "  $plugin:\n",
                  "    ", join("\n    ", split("\n", $errors{$plugin})), "\n";
        }
    }
    else {
        print "No errors found parsing new / changed plugins.\n";
    }
}


############################################################################
# Clean up.
if ($backup) {
    print "Backup of '$plugins_dir' available as '$archive'.\n";
}
elsif ($summary) {
    unlink $archive;
}
