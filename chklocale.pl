#!/usr/bin/perl

use POSIX qw(locale_h);

# Get a reference to a hash of locale-dependent info
$locale_values = localeconv();

# Output sorted list of the values
for (sort keys %$locale_values) {
	printf "%-20s = %s\n", $_, $locale_values->{$_}
}

