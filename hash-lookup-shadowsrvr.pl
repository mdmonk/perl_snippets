#!/usr/bin/perl
use JSON;
use strict;

=item whitelisted ($hashfile)

Returns a nested hash reference of whitelisted hashes and their decoded
JSON attributes. 

=cut
sub whitelisted
{
	my ($hashfile) = @_;
	my %res;

	my $fh;
	open($fh, "curl -s http://bin-test.shadowserver.org/api -F"
		. " 'filename.1=\@$hashfile'|") || die("curl failed: $!");
	while (my $line = <$fh>)
	{
		if ($line =~ /^([^\s]+)\s(.+)$/)
		{
			$res{$1} = decode_json($2);
		}
	}
	close($fh);

	return \%res;	
}

my $res = whitelisted($ARGV[0]);
print join("\n", keys %{$res});

