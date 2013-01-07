#!/usr/local/bin/perl
# Perl script to sort and report on disk usage
# Written 12/30/98  RGF

# Usage: du_report [directory] [minimum size]

$dir = $ARGV[0];
$min = $ARGV[1];
unless (defined($min)) { $min = 0; }
unless (-d $dir) {
        print "\nUsage: du_report [directory] [minimum size]\n\n";
        exit();
}

@du_data = qx(du $dir);

if ($min > 0) {
                &w_min;
        } else {
                &no_min;
        }

sub w_min {
        foreach (@du_data) {
                ($bytes,$path) = split (/\s+/);
                push(@data_culled, $_) if ($bytes >= $min);
                @data_sorted = sort rev_numeric (@data_culled);
        }
}

sub no_min {
        @data_sorted = sort rev_numeric (@du_data);
}

&print_results;

sub rev_numeric { $b <=> $a; }

sub print_results {
        system(clear);
        if ($min > 0) {
                print "Minimum size for reporting is $min bytes\n";
        }
        print "Disk usage, sorted by size:\n\n";
        print @data_sorted;
        print "\n";
}
