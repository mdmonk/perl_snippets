#!/usr/bin/perl

# Configuration	########################################
my $config = {

	# Location of template files
	templates => '/usr/local/apache/cgi-bin/mailform/templates',

	# Default from address, if none provided
	from      => 'webmaster@cre8tivegroup.com',
};
#########################################################

use CGI_Lite;
use Mail::Sendmail;
use Text::Template;
use strict;

my ($cgi, $form, $fill_in, $message, $template,
	%mail,
	);

$cgi = new CGI_Lite;
$form = $cgi->parse_form_data;
exit(0) if $form->{template}=~/\.\./;
foreach (keys %$form)	{
	$form->{$_} = join ', ', @{$form->{$_}} if ref $form->{$_};
}

$fill_in = new Text::Template ( TYPE => 'FILE',
		SOURCE => $config->{templates} . "/" . $form->{template} . ".email");
$message = $fill_in->fill_in( HASH => [ $form ],
			DELIMITERS => [ '<%', '%>' ]
			);

$form->{email} ||= $config->{from};

%mail = ( To      => $form->{to},
		  From    => $form->{email},
		  Subject => $form->{subject},
		  Message => $message,
		);
sendmail(%mail);

print "Location: $form->{redirect}\n\n";

__END__

=head1 NAME

mailform.pl - Send email messages from a web form

=head1 SYNOPSIS

Generic HTML form, with some required fields, will send an email message, and then
redirect to some specified C<Location>.

=head1 DESCRIPTION

Given an HTML form with some required fields (to, email, subject, redirect, template)
and a email template file, this will send email to the specified address, and then
print a redirect C<Location:> header.

The template file should contain the formatting for the email message, and should
be placed in the templates directory specified at the top of the script. The
template should contain the names of the various fields in the form, thusly:

	<% $foo %> <% $bar %> <% $baz %>

This program uses Text::Template to fill in the template, and Mail::Sendmail to
send it.

The template file should be called something.email (ie, have a .email file
extension).	Making a restriction on the name of the file, and specifying a 
template directory prevents (or should prevent) people from downloading 
arbitrary files from your system. Perhaps this could be made more secure.

To get a series of checkboxes to display as desired in the email message, give them
all the same NAME, like this:

	<checkbox name="interests" value="skiing">Skiing
	<checkbox name="interests" value="kites">Kites
	<checkbox name="interests" value="explosives">Explosives

These will then appear in the email message as a comma-separated list (if more
than one is checked). Multiple-select lists will work in the same way.

=head1 AUTHOR

Rich Bowen <rich@cre8tivegroup.com>

=head1 README

Generic CGI form processor, sending results somewhere via email

=head1 PREREQUISITES

	C<CGI_Lite>, C<Mail::Sendmail>, C<Text::Template>

=pod OSNAMES

Any

=pod SCRIPT CATEGORIES

CGI

=cut
