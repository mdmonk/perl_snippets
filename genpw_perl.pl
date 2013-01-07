#!/usr/bin/perl -w

=for comment
This file is documented in Pod format. For a nicely-formatted
version of the documentation, run this file through perlpod or
some such.

=head1 NAME

genpw - generate a random password

=head1 SYNPOSIS

genpw [-Uldpv] [-n #] [-r device]

=head1 DESCRIPTION

The B<genpw> program prints on the standard output a
randomly-generated password of the desired length drawn from
various sets of characters.

The options are as follows:

=over

=item B<-U>

Include UPPERCASE letters in the password.

=item B<-l>

Include lowercase letters in the password.

=item B<-d>

Include numerical digits in the password.

=item B<-p>

Include punctuation characters in the password. These include:

C<< `~!@#$%^&*()-=_+[]\|;':",./<>?{} >>

=item B<-v>

Be verbose. All parameters are displayed along with an estimation
of the keyspace size (in bits).

=item B<-n LENGTH>

How many characters to include in the password. Must be numeric.

=item B<-r DEVICE>

Device from which the random characters are drawn. It is
I<strongly recommended> that this device provide an endless stream
of truly random data or else the integrity of the password will be
compromised.

=back

If none of the B<U, l, d,> or B<p> options are specified, the
password is drawn from all those sets.

If no length is specified, a password of 12 characters is generated.

If no device is specified, C</dev/urandom> is used.

=head1 EXAMPLES

C<genpw>

Generate a 12-character password using all possible characters.

C<genpw -Uldpn 12>

Do the same.

C<genpw -vUn6>

Generate a very insecure password and display extra information.

=head1 BUGS

The security of the generated password depends greatly upon the
random device used as a source. Using a less-than-random device
will result in a less-than-random password.

If the random device returns EOF before the requested number of
characters have been generated, the password will have fewer than
the requested number of characters. This is not likely to be a
problem with modern random device implementations.

In verbose mode, the program is unable to calculate the size of
the keyspace if it's larger than 1024 bits. In such cases, an
appropriately vague message is printed instead.

=head1 HISTORY

The genpw program was first written by Ben Goren
L<mailto:ben@trumpetpower.com> in 2005.

$Log: genpw,v $
Revision 1.2  2005/04/22 18:42:45  ben
Wrap the calculation of the keyspace in an eval to avoid
a crash with large (>1024) keyspaces.

Revision 1.1  2005/03/15 23:39:06  ben
Initial revision


=cut

use strict;
use Getopt::Std;

my $Length = 12;
my $RandomDevice = "/dev/urandom";

my $Password = "";

my $Matchlist = "";

my $UPPERCASE = q{ABCDEFGHIJKLMNOPQRSTUVWXYZ};
my $lowercase = q{abcdefghijklmnopqrstuvwxyz};
my $Digits = q{0123456789};
my $Punctuation = q{`~!@#$%^&*()-=_+[]\\|;':",./<>?} . '{}';

my %Options = ();

getopts('Uldpvn:r:', \%Options);

if ($Options{n}) {
	$Options{n} =~ /\d+/
		? $Length = $Options{n}
		: die "Password length (-n) must be numeric.\n";
}

$Matchlist .= $UPPERCASE if $Options{U};
$Matchlist .= $lowercase if $Options{l};
$Matchlist .= $Digits if $Options{d};
$Matchlist .= $Punctuation if $Options{p};

$Matchlist = "${UPPERCASE}${lowercase}${Digits}${Punctuation}"
	unless $Matchlist;

$RandomDevice = $Options{r} if $Options{r};

if ($Options{v}) {

	my $RandomBits;

	eval {
		$RandomBits = sprintf(
			"%0.0f",
			log(length($Matchlist) ** $Length) / log(2)
		);
	};

	$RandomBits = "an incalculable number (probably greater than 1024) of" if $@;

	warn qq(Generating a ${Length}-character password
using ${RandomDevice}
and the following characters:
${Matchlist}
This password is drawn from a keyspace of $RandomBits bits.
----8<----cut-here----8<----
); # warn information

} # if verbose

# Certain punctuation characters--most notably, ``\'' and
# the brackets, ``[]''--will cause problems if they're not
# escaped. It's easiest to just escape 'em all.
#
# Do this late to make everything above more readable.

$Matchlist =~ s|([^A-Za-z0-9])|\\$1|g;

open RANDOMDEVICE, $RandomDevice
	or die "Can't open random device $RandomDevice: $!\n";

# As is so often the case, the heart of this program is just a
# few lines long. And here they are.

until ($Password =~ /^.{$Length}$/) {
	$_ = getc RANDOMDEVICE;
	$Password .= $_ if (m/[$Matchlist]/)
}

print "$Password\n";

close RANDOMDEVICE;

$Options{v} && warn "---->8----cut-here---->8----\n";

sub VERSION_MESSAGE {

	$Getopt::Std::STANDARD_HELP_VERSION = 1;

	warn q{Copyright (c) 2005 Ben Goren <ben@trumpetpower.com>

Permission to use, copy, modify,  and distribute this software for
any purpose with  or without fee is hereby  granted, provided that
the above  copyright notice and  this permission notice  appear in
all copies.

THE  SOFTWARE IS  PROVIDED "AS  IS" AND  THE AUTHOR  DISCLAIMS ALL
WARRANTIES  WITH REGARD  TO  THIS SOFTWARE  INCLUDING ALL  IMPLIED
WARRANTIES  OF  MERCHANTABILITY  AND FITNESS. IN  NO  EVENT  SHALL
THE  AUTHOR  BE  LIABLE  FOR ANY  SPECIAL,  DIRECT,  INDIRECT,  OR
CONSEQUENTIAL  DAMAGES OR  ANY DAMAGES  WHATSOEVER RESULTING  FROM
LOSS OF  USE, DATA OR PROFITS,  WHETHER IN AN ACTION  OF CONTRACT,
NEGLIGENCE  OR  OTHER  TORTIOUS  ACTION,  ARISING  OUT  OF  OR  IN
CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

$Id: genpw,v 1.2 2005/04/22 18:42:45 ben Exp ben $
}; # warn copyright / version

} # VERSION_MESSAGE sub

sub HELP_MESSAGE {

	$Getopt::Std::STANDARD_HELP_VERSION = 1;

	warn '.' x 66, qq{
Usage: $0 [-Uldpv] [-n #] [-r device]

This program prints a random password on the standard output.

Options:

    -U        choose from UPPERCASE LETTERS
    -l        choose from lowercase letters
    -d        choose from digits
    -p        choose from punctuation
              If none of U, l, d, or p is specified, all are used.
    -v        be verbose
    -n #      password length (default: $Length)
    -r dev    device for random data (default: $RandomDevice)
}; # warn help / usage

} # HELP_MESSAGE sub

__END__
