################################################################
# Program Name: testserver.cgi
#
# Desc:
#   This program is for testing and learning about a new server.
#   What it can do and what commands it can run. 
#   Pulled from the perl-Win32-users mailing list.
# 
################################################################
use Cwd;

$start = (times)[0];

# Test if it needs a mime-type line before printing anything
# Actually, it is likely to not even compile if it needs this first.
#if (!(print "If you see this line, a mime-type line is not needed
# first.\n\n")) {
#	print "Can't print without first printing a mime header.";
#}

print "Content-type: text/plain\n\n";
print "Perl Version is $]\n";
print "Name of this program, using \$0: $0\n";
print "Process Number \$\$: $$\n";
print "The time this program started running: $^T\n";
#$the_cwd = cwd;
#print "cwd=$the_cwd\n";
print "Current Working Directory: ", &cwd, "\n";
print "Current Working Directory as \$ENV{PWD}: $ENV{PWD}\n";
print "Home Directory: $ENV{'HOME'}\n";
print "Real Group ID: $(\n";
print "Effective Group ID: $)\n";
print "Real User ID: $<\n\n";
print "Effective User ID: $>\n";

# Test the existence of a few modules
eval <<EOEVAL;
	require Cwd;
	require Text::Template;
	require Data::Dumper;
	require Non::Existent;
EOEVAL
if ($@) {print $@;print "\n";}

# Test file locking.
	my $LOCK_EX = 2;
	open F, ">/testing_delete.txt" or print "Couldn't open testing_delete file: $!\n\n";
	# get an exclusive lock
	flock F, $LOCK_EX or print "Couldn't use flock: $!\n\n";
	close F or print "Couldn't close testing_delete file: $!\n\n";
	print "Finished testing flock.\n\n";

#exit;
#########

print "OUTPUT THE \@INC ELEMENTS\n";
foreach (sort @INC) {
	print "$_\n";
}

#exit;
#########
print "\nOUTPUT THE ENVIRONMENT VARIABLES\n";
foreach (sort keys %ENV) {
	print "$_: $ENV{$_}\n";
}

$end = (times)[0];
print "That took %.2f CPU seconds\n", $end - $start;	#########

exit;
__END__
