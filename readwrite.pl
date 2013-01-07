############################################################
#
############################################################

$filename      = $ARGV[0];
$something     = "";
$somethingelse = "";


# open the file for read, read it in, close it.
open(FD, "<$filename") || die "Can't open 'filename' for read, $!";
my @slurp = <FD>;
close(FD);

# make changes
foreach my $line (0..$#slurp) {
    if ($slurp[$line] =~ s/$something/$somethingelse/ ) {
        ...make changes;
    }
}

# open the file for write, and save the data
open(FD, ">$filename") || die "Can't open 'filename' for write, $!";
print FD join("",@slurp);
close(FD);

# All done
