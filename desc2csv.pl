#!/usr/bin/perl -wT

# desc2csv - convert output of describe-nessus-plugin to CSV format.
#
# updated: 17-Mar-2004, George A. Theall

# Read / parse output.
while (<>) {
    chomp;
    # - filename.
    if (/^\S/ and /([^\/]+)\.nasl/) {
        push(@fnames, $fname = $1);
    }
    # - function.
    #   nb: report format uses two spaces at start of line 
    #       to introduce functions!
    elsif ($fname and /^  \b([^:]+):\s+(.+)$/) {
        $func = $1;
        $funcs{$func}++;
        $info{$fname}{$func} = $2;
    }
    # - function continued.
    elsif ($fname and $func and /^\s+\b(.*)$/) {
        $info{$fname}{$func} .= "\\n" . $1;
    }
    # - end for information about plugin.
    elsif (/^$/) {
        $fname = $func = "";
    }
}

# Output information in CSV format.
#
# - column headers
print '"', "Filename", '"';
foreach $func (sort keys %funcs) {
    print ',"', $func, '"';
}
print "\n";
# - descriptive information for each plugin.
foreach $fname (sort @fnames) {
    print '"', $fname, '"';
    foreach $func (sort keys %funcs) {
        print ',"', $info{$fname}{$func}, '"';
    }
    print "\n";
}
