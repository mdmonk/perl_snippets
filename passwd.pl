#!/usr/bin/perl -T

# preliminaries to satisfy taint checks
$ENV{PATH} = '/bin:/usr/bin';
$ENV{IFS} = '';

# Prevent buffering problems
$| = 1;

use CGI qw/:standard :html3/;

print header,
    start_html(-title=>'Change Unix Password',
	       -bgcolor=>'white'),
    h1('Change your Unix password');

import_names('Q');

TRY: {
    last TRY unless $Q::user;
    my ($rv,$msg) = check_consistency();
    do_error($msg),last TRY unless $rv;

    # Change the password, after first temporarily turning off
    # an annoying (and irrelevant) error message from su
    open(SAVERR,">&STDERR");
    open(STDERR,">/dev/null"); 
    ($rv,$msg) = set_passwd($Q::user,$Q::old,$Q::new1);
    open(STDERR,">&SAVERR");
    do_error($msg),last TRY unless $rv;

    print $msg;
    $OK++;
}

create_form() unless $OK;

print 
    p,
    a({href=>"$Q::referer" || referer() },"[ EXIT SCRIPT ]");
    hr,
    a({href=>'/'},'Home page'),
    end_html;

sub check_consistency {
    return (undef,'Please fill in the user name field.') unless $Q::user;
    return (undef,'Please fill in the old password field.') unless $Q::old;
    return (undef,'Please fill in the new password fields.') unless $Q::new1 && $Q::new2;
    return (undef,"New password fields don't match.") unless $Q::new1 eq $Q::new2;
    return (undef,"Suspicious user name $Q::user.") unless $Q::user=~/^\w{3,8}$/;
    return (undef,'Suspiciously long old password.') unless length($Q::old) < 30;
    return (undef,'Suspiciously long new password.') unless length($Q::new1) < 30;
    my $uid = (getpwnam($Q::user))[2];
    return (undef,"Unknown user name $Q::user.") if $uid eq '';
    return (undef,"Can't use this script to set root password.") if $uid == 0;    
    return 1;
}

sub set_passwd ($$$) {
    require "chat2.pl";
    my $TIMEOUT = 2;
    my $PASSWD = "/usr/bin/passwd";
    my $SU = '/bin/su';

    my($user,$old,$new) = @_;

    my $h = chat::open_proc($SU,'-c',$PASSWD,$user) 
	|| return (undef,"Couldn't open $SU -c $PASSWD: $!");
    
    # wait for su to prompt for password
    my $rv = &chat::expect($h,$TIMEOUT,
			   'Password:'=>"'ok'",
			   'user \w+ does not exist'=>"'unknown user'"
			   );
    $rv eq 'unknown user' && return (undef,"User $user unknown.");
    $rv	|| return (undef,"Didn't get su password prompt.");
    chat::print($h,"$old\n");

    # wait for passwd to prompt for old password
    $rv = &chat::expect($h,$TIMEOUT,
			'Enter old password:'=>"'ok'",
			'incorrect password' =>"'not ok'");
    $rv || return (undef,"Didn't get prompt for old password.");
    $rv eq 'not ok' && return (undef,"Old password is incorrect.");

    # print old password
    chat::print($h,"$old\n");
    $rv = &chat::expect($h,$TIMEOUT,
			   'Enter new password: '=>"'ok'",
			   'Illegal'=>"'not ok'");
    $rv || return (undef,"Timed out without seeing prompt for new password.");
    $rv eq 'not ok' && return (undef,"Old password is incorrect.");

    # print new password
    chat::print($h,"$new\n");
    ($rv,$msg) = &chat::expect($h,$TIMEOUT,
			       'Re-type new password: ' => "'ok'",
			       '([\s\S]+)Enter new password:' => "('rejected',\$1)"
			       );
    $rv || return (undef,"Timed out without seeing 2d prompt for new password.");
    $rv eq 'rejected' && return (undef,$msg);

    # reconfirm password
    chat::print($h,"$new\n");
    $rv = &chat::expect($h,$TIMEOUT,
			'Password changed' => "'ok'");
    $rv || return (undef,"Password program failed at very end.");
    chat::close($h);

    return (1,"Password changed successfully for $Q::user.");
}

sub create_form {
    print
	start_form,
	table(
	      TR({align=>RIGHT},
		 th('User name'),   td(textfield(-name=>'user')),
		 th('Old password'),td(password_field(-name=>'old'))),
	      TR({align=>RIGHT},
		 th('New password'),td(password_field(-name=>'new1')),
		 th('Confirm new password'),td(password_field(-name=>'new2'))),
	      ),
	    hidden(-name=>'referer',-value=>referer()),
	    submit('Change Password'),
	    end_form;
}

sub do_error ($) {
    print font({-color=>'red',-size=>'+1'},b('Error:'),shift," Password not changed.");
}
