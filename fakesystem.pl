###############################################################################
# Just require('fakesystem.pl'), and change all system() calls to fakesystem()
# calls.  This will probably work for most cases where the subprograms are
# well written and aren't doing anything too crazy.
###############################################################################

use Symbol;

# package scoped lexical, won't pollute main:: package
my %subs;

sub fakesystem {
    my $file = shift;

    # check to see if we've already loaded the program
    unless (exists $subs{$file}) {
        my ($buf,$pack);
        { # slurp that file!
            local $/ = chr(0);
            my $fh = gensym;
            sysopen($fh,$file,0) || die "fakesystem:$file:$!\n";
            $buf = <$fh>;
            close($fh);
        }

        # sanitize the file name
        ($pack = $file) =~ s/\W/_/go;

        # create code ref in a semi-safe package
        $subs{$file} = eval "
            sub {
                package $pack;
                local(\$ARGV,\@ARGV,\%SIG);
                \$ARGV = \@ARGV = \@_;
                eval { $buf };
            };
        " || die "Execution of $file aborted due to compilation errors.\n";
    }

    # just to be safe...
    my $fh = select(STDOUT);
    $subs{$file}->(@_);
    select($fh);
    1;
}

1;
