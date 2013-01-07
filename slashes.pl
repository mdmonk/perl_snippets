#!/usr/bin/perl -w
#
# slashes.pl - Slashdot headlines news-ticker
# Copyright (c) 1998 Alex Shnitman <alexsh@linux.org.il>
# This code is distributed under the terms of the GNU General Public License.

use Gtk;
init Gtk;
use Socket;
use IO::Handle;

use strict;


# You can configure the script to use a proxy. If $PROXY is empty it
# will not use one. If you need to use a proxy define $PROXY to the
# proxy hostname.
my $PROXY = "";
my $PROXYPORT = 8080;

# $clist and $status hold the references to the Gtk CList holding the
# articles, and the status line which is actually a label. @articles
# holds the URLs of the articles.
my($clist, $status, @articles);

sub MainWindow {
    my $mainwin = new Gtk::Window;
    $mainwin->set_title("Slashdot headlines");
    $mainwin->signal_connect("destroy", \&Gtk::main_quit);
    $mainwin->signal_connect("delete_event", \&Gtk::false);
    $mainwin->set_usize(600,150); # This sets the window to useful
                                  # size; the problem is that the user
                                  # can't make it smaller. I'm not
                                  # sure what to do.
    my $vbox = new Gtk::VBox(0,5);
    $vbox->border_width(5);

    $clist = new_with_titles Gtk::CList("Title", "Author", "Topic", "Comments");
    $clist->column_titles_passive;
    $clist->set_policy("always", "automatic");
    $clist->set_column_width(0, 250);
    $clist->set_column_width(1, 70);
    $clist->set_column_width(2, 100);
    $clist->set_column_width(3, 20);
    $clist->show;
    $vbox->pack_start($clist, 1,1,0);

    my $hbox = new Gtk::HBox(0,0);
    my $but;
    $but = new_with_label Gtk::Button("  Refresh  ");
    $but->signal_connect("clicked", \&Refresh);
    $hbox->pack_start($but, 0,0,0);
    $but->show;
    $but = new_with_label Gtk::Button("  Read  ");
    $but->signal_connect("clicked", sub {
	       return unless(defined $clist->selection);
	       my $url = $articles[$clist->selection];
	       system("netscape -remote 'OpenURL($url, new_window)'");
	       $status->set("Sent URL to Netscape");
	   });
    $hbox->pack_start($but, 0,0,0);
    $but->show;
    $status = new Gtk::Label("Click \"Refresh\" to load headlines");
    $hbox->pack_start($status, 0,0,10);
    $status->show;
    $hbox->show;
    $vbox->pack_start($hbox, 0,0,0);

    $mainwin->add($vbox);
    $vbox->show;
    $mainwin->show;
}

sub Refresh {
    my($iaddr, $proto, $port, $paddr, $url);

    if($PROXY) {
	$iaddr = gethostbyname($PROXY);
	$port = $PROXYPORT;
	$url = "http://slashdot.org/ultramode.txt";
    } else {
	$iaddr = gethostbyname("slashdot.org");
	$port = 80;
	$url = "/ultramode.txt";
    }

    $proto = getprotobyname("tcp");
    $paddr = sockaddr_in($port, $iaddr);

    $status->set("Connecting to slashdot.org...");  # this actually
                                                    # won't show...
    socket(SLASH, PF_INET, SOCK_STREAM, $proto) or die "socket: $!";
    connect(SLASH, $paddr) or die "connect: $!";
    autoflush SLASH 1;
    print SLASH "GET $url HTTP/1.0\r\n\r\n";
    $status->set("Connected; waiting for reply...");

    my(@header, @body, $hdr);
    $hdr = 1;
    while(<SLASH>) {
	s/\r?\n$//;  # Strip the newline; chop won't work as it won't
                     # strip the \r
	if(/^$/) {
	    $hdr = 0;
	    next;
	}
	push @header, $_ if $hdr;
	push @body, $_ unless $hdr;
    }
    close SLASH;

    if($header[0] !~ m:^HTTP/1.[01] 200:) {
	$status->set("Error connecting to server: $header[0]");
	return;
    }
    $status->set("Headlines retrieved.");

    $clist->clear;
    undef @articles;
    my $line = "";
    while($line !~ /^%%$/ && $#body != -1) {   # skip the header of
	$line = shift @body;                   # of the file
    }
    while($#body != -1) {
	my $title = shift @body;   # Any suggests how to make all this
	my $link = shift @body;    # shorter? :-) Mail me.
	my $time = shift @body;
	my $author = shift @body;
	my $dept = shift @body;
	my $topic = shift @body;
	my $numcomments = shift @body;
	my $storytype = shift @body;
	shift @body;   # skip the %%

	$clist->append($title, $author, $topic, $numcomments);
	push @articles, $link;
    }
}

&MainWindow;

main Gtk;
