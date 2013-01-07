use strict;
use MIME::Base64::Perl;

print "# Testing MIME::Base64::Perl-", $MIME::Base64::Perl::VERSION, "\n";

    local $SIG{__WARN__} = sub { print $_[0] };  # avoid warnings on stderr

    my $encoded = 'NHV0MHQzNG0=';
    my $decoded = decode_base64($encoded);
    print "($encoded): got $decoded\n";
