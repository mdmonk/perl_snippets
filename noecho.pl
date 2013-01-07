    $pwd = (getpwuid($<))[1];
    $salt = substr($pwd, 0, 2);

    system "stty -echo";
    print "Password: ";
    chop($word = <STDIN>);
    print "\n";
    system "stty echo";

    if (crypt($word, $salt) ne $pwd) {
        die "Sorry...\n";
    } else {
        print "ok\n";
    }

