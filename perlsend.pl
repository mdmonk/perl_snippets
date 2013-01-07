#!/usr/bin/perl -w

use Mail::Sendmail;

$to = "";
$from = "";
$bcc = "";
$cc = "";
$subject = "";
$message = "";
$smtp = "mail.lssi.net";

while(<STDIN>) {
    chomp;

    if($_ eq "") { last; }
    if(index($_, ":") < 0) { next; }

    ($key, $value) = split(/:/, $_, 2);
    $key =~ tr/[A-Z]/[a-z]/;

    $value =~ s/^\s+//;   # remove end white space
    $value =~ s/\s+$//;

    if($key eq "from") {
        $from = $value;
    } elsif($key eq "to") {
        $to = $value;
    } elsif($key eq "bcc") {
        $bcc = $value;
    } elsif($key eq "cc") {
        $cc = $value;
    } elsif($key eq "subject") {
        $subject = $value;
    }
}

for($x=0; $x <= $#ARGV; $x++) {
    if(substr($ARGV[$x], 0, 1) eq "-") {
        my $option = substr($ARGV[$x], 1);

        if($option eq "to") {
	    $to = $ARGV[$x+1];
	    $x++;
	} elsif($option eq "from") {
	    $from = $ARGV[$x+1];
	    $x++;
	} elsif($option eq "smtp") {
	    $smtp = $ARGV[$x+1];
	    $x++;
	} elsif($option eq "cc") {
	    $cc = $ARGV[$x+1];
	    $x++;
	} elsif($option eq "bcc") {
	    $bcc = $ARGV[$x+1];
	    $x++;
	} elsif($option eq "subject") {
	    $subject = $ARGV[$x+1];
	    $x++;
	}
    }
}

while(<STDIN>) {
    $message = $message . $_;
}

%mail = (
    'To' => $to,
    'From' => $from,
    'Message' => $message,
    'Smtp' => $smtp,
    'Subject' => $subject,
);

if($cc ne "") {
    $mail{'Cc'} = $cc;
}

if($bcc ne "") {
    $mail{'Bcc'} = $bcc;
}

if(sendmail %mail) {
    exit(0);
} else {
    print "Error sending mail: $Mail::Sendmail::error\n";
    exit(1);
}
