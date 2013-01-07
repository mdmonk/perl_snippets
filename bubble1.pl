###################################################
# Program Name: bubble1.pl
#
# Description:  This script does a bubble sort on
#               an array of numeric values.
#
###################################################
@array = (3, 5, 2, 4, 1);
$newvalue = 8;
print "@array\n";
push (@array, $newvalue);                 # Push new value onto array, this
                                          # makes 6 elements.
@array = sort Numericaly @array;          # sort them numericaly lowest ->
                                          # highest.
#@array = reverse sort Numericaly @array; # sorts them highest -> lowest.
print "@array\n";
shift @array;                             # Drop (or 'shift') first
                                          # element off.
print "@array\n";

sub Numericaly { $a <=> $b }              # Function that performs the numerical
                                          # comparison.
