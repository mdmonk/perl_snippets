#!/opt/perl5/bin/perl
#======================================================================
#
# HttpSniffer v2.1
#
# Copyright (c) 1998 Tim Meadowcroft <tim@compansr.demon.co.uk>.
# All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Not so quick'n'dirty program to listen in to HTTP conversations.
# See RFC 2068 for details of HTTP 1.1 (esp. section 4.1 -> 4.5)
#
# **** NOTEs ****
# - I presume the IO:Socket automatically makes an autoflush socket,
#   but some older versions didn't. If you have problems, check for a
#   newer version of IO:Socket.
#
# - Note on sockets - when a socket has been closed by the other end,
#   select->can_read indicates there's data on the socket, but a read
#   from the socket returns 0 bytes - this is how we recognise a socket needs
#   closing. This program uses blocking sockets, but avoids blocking.
#
# - I buffer up reading an entire HTTP header and body - this sniffer is
#   written for debugging convenience not speed, later versions may change.
#   Similarly the code is verbose and explicit not speedy and minimal.
#
# - I read the Content data out of headers, but almost no more except
#   for matching replies to HEAD requests (which must have no content)
#
# - This is NOT a proxy, it doesn't read the request and forward it to
#   the server specified in the request field. It's a tunnel, it forwards
#   all its requests to the same server (same machine, different port).
#   Turning it into a proxy wouldn't be hard, but I didn't want a proxy...
#   Note that RFC2068 says proxies must attach VIA headers and do other stuff
#   that proxies don't have to.
#
#======================================================================
use strict;
use IO;
use IO::Socket;
use IO::Select;
use Getopt::Std;

$::HttpEol = "\015\012";        # end of line marker....
$::Timeout = 10;                # default timeout period

#
# RemoveLine($data, [ $eol ] )
# Removes a line from the first param, as terminated by eol 2nd optional param
# and returns it (with the eol string), or undef if not found.
# Note that the first parameter has the line removed on success.
#
sub RemoveLine
{
    my ($data, $eol) = @_;
    my $line = undef;

    $eol = "\n" unless defined($eol);
    my $pos  = index($data, $eol);
    if ($pos >= 0)
    {
        $line = substr($data, 0, $pos + length($eol), "");
        $_[0] = $data;
    }

    return $line;
}

#
# RemoveBytes($data,$n)
# Removes $n bytes from $data and returns them, or undef if not enough
#
sub RemoveBytes
{
    my ($data, $n) = @_;
    my $ret = undef;

    if (defined($data) and length($data) >= $n)
    {
        $ret = substr($data, 0, $n, "");
        $_[0] = $data;
    }

    return $ret;
}

#----------------------------------------------------------------------
#
# Splits $data into a list of the HTTP header and what's left.
# Returns less than 2 defined values on error.
# HTTP headers are a series of lines terminated by a blank line.
#
sub RemoveHttpHeader
{
    my($data, $eof, $reqh) = @_;
    my $header = "";

    my $line;
    while (defined($line = RemoveLine($data, $::HttpEol)))
    {
        # **** Note from RFC 2068 section 4.1 ****
        # In the interest of robustness, servers SHOULD ignore any empty
        # line(s) received where a Request-Line is expected. In other words, if
        # the server is reading the protocol stream at the beginning of a
        # message and receives a CRLF first, it should ignore the CRLF.
        # This is the only spot where I change the bytes passing through...
        # latest logic looks at the opening bytes of a header to tell type
        #
        $header .= $line unless $line eq $::HttpEol and length($header) == 0;
        last if $line eq $::HttpEol and length($header) > 0;
    }

    return (defined($line) ? $header : undef, , $data);
}

#
# Given a block of HTTP data (described by the passed header - removed),
# read and return the body and whats left (either part undef on error).
# The header tells us what type of body follows, either a block of data, or
# a series of size-prefixed chunks.
#
sub RemoveHttpBody
{
    my($data, $eof, $header, $reqh) = @_;
    my $body = undef;

    #print STDERR "$_\n" foreach (split(/$::HttpEol/,$header));

    # **** Note from RFC 2068 section 4.1 ****
    #  The presence of a message-body in a request is signaled by the
    #  inclusion of a Content-Length or Transfer-Encoding header field in the
    #  request's message-headers.
    #
    # Sometimes we get replies like this
    #  HTTP/1.0 200 OK
    #  Server: Microsoft-PWS/2.0
    #  Date: Fri, 13 Nov 1998 17:31:45 GMT
    #  Content-type: text/html
    #  Set-Cookie: ASPSESSIONID=UZFWFNFOZVSRWONB; path=/FWeb
    #  Cache-control: private
    # where we have body but no proper indication of length. In these cases
    # we presume HTTP 1.0 behaviour and read body until the server closes
    # the socket (but only if we see "content-" headers, to avoid
    # closing GET requests etc.).
    #
    # Note order of checks, ignore Content-Length if Transfer-Encoding given.
    #
    # Also...
    #  For response messages, whether or not a message-body is included with
    #  a message is dependent on both the request method and the response
    #  status code (section 6.1.1). All responses to the HEAD request method
    #  MUST NOT include a message-body, even though the presence of entity-
    #  header fields might lead one to believe they do.
    #
    my $clength = 0;    # assume exactly 0 bytes of body....
    if ($header =~/^HTTP/ and defined($reqh) and $reqh =~ /^HEAD/)
        { $clength = 0; }   # replies to HEAD queries have no body ...
    elsif ($header =~ /^\s*Transfer-Encoding:\s+chunked/im)
        { $clength = "chunked"; }
    elsif ($header =~ /^\s*Content-Length:\s+(\d+)/im)
        { $clength = $1; }
    elsif ($header =~ /^\s*Content-/im)
    {
        # We have some content, but no length specified in any way.
        # Guess this is HTTP 1.0 or earlier and marked by eof on the socket.
        $clength = -1;
    }

    if ($clength eq "chunked")
    {
        # Chunked transfer - need to work out the length as we go....
        # Read multiple chunks, followed by a 0 chunk.
        # These may be followed by more headers...
        my $line;
        $body = "";
        while (defined($body) and
               defined($line = RemoveLine($data, $::HttpEol)))
        {
            $body .= $line;

            substr($line, -length($::HttpEol)) = "";
            # print STDERR "CHUNK: $line - ".length($data). " available\n";
            if ($line !~ /^\s*([0-9a-fA-F]+)\s*(;.*)?$/)
            {
                # bad chunk line or incomplete
                $body = undef;
            }
            else
            {
                # read the chunksize, ignore optional extensions
                my $chunksize = hex( $1 );
                last if $chunksize == 0;

                # each chunk is followed by an HttpEol
                my $c = RemoveBytes($data, $chunksize + length($::HttpEol));
                $body = defined($c) ? $body.$c : undef;
            }
        }
        $body = undef unless defined($line) and defined($data);

        # Read footer lines up to and including an empty line...
        #
        while (defined($body) and
               defined($line = RemoveLine($data, $::HttpEol)))
        {
            $body .= $line;
            last if $line eq $::HttpEol;
        }
        $body = undef unless defined($line) and defined($data);
    }
    elsif ($clength >= 0)
    {
        # **** Note from RFC 2068 section 4.1 ****
        # Note: certain buggy HTTP/1.0 client implementations generate an
        # extra CRLF's after a POST request. To restate what is explicitly
        # forbidden by the BNF, an HTTP/1.1 client must not preface or follow
        # a request with an extra CRLF.
        # IE4 does this !!
        # We try to look for the extra couple of bytes, but if we don't find
        # them and they come later, we'll be OK 'cos we skip leading CR/LF
        # in headers anyway
        if (defined($body = RemoveBytes($data, $clength)))
        {
            $body .= RemoveBytes($data, length($::HttpEol))
                if  $header =~ /^POST/ and $data =~ /^$::HttpEol/;
        }
    }
    else
    {
        # We think this is ended by the socket closing, so ignore it until
        # we get an eof marker
        ($body, $data) = ($data, "") if $eof;
    }

    return ($body, $data);
}

#----------------------------------------------------------------------
#
# Given a block of data which is known to start with an HTTP header,
# this tries to split it into header, body and what's left at the end.
# Returns these 3 item, some may be undef if parsing is incomplete.
# $eof tells us if this is the real socket eof (used for HTTP 1.0 replies).
# $req is the most outstanding Request header, HTTP responses may
# consult this to see what was asked for.
#
sub SplitHttp
{
    my ($data, $eof, $reqh) = @_;
    my ($head, $body, $next);

    ($head,$data) = RemoveHttpHeader($data, $eof, $reqh)
        if defined($data);
    ($body,$next) = RemoveHttpBody($data, $eof, $head, $reqh)
        if defined($head) and defined($data);

    return ($head, $body, $next);
}

#----------------------------------------------------------------------
#
# A socket $reader has a read event (from select), usually data to be sent
# to $writer.
# Note that this is the same routine for both directions (browser --> server
# and vice-versa).
# For now we read and write the whole reply, or push it back into the buffer
# for when more data arrives, but later we might want to do this over
# multiple calls (eg read and write a header or partial body).
#
# $rqRequests is a queue of outstanding requests for this conversation.
# New requests get added to the end, responses clear a request from the head.
#
# Returns 0 if this socket is now dead and should be closed.
#
sub HandleSocketData
{
    my($reader, $writer, $rqRequests, $mprefix, $log) = @_;

    # Read all the available bytes for this socket - 0 if real EOF and
    # the socket is closing.
    my $eof = ($reader->FillReadBuffer() == 0);

    # HTTP 1.0 replies are terminated by closing the socket, so
    # still parse any queued data...
    if ($reader->NumBytesAvailable > 0)
    {
        # Look for a complete message - if found, interpret and send,
        # else push it back and wait for more.
        my $data = $reader->ReadBufferedData();
        my($header,$body, $next) = SplitHttp($data, $eof, $rqRequests->[0]);
        while (defined($header) and defined($body) and defined($next))
        {
            $writer->Write($header);
            $writer->Write($body);

            $log->print("$mprefix ========== Request queue length "
                        .scalar(@{$rqRequests})." ==========\n");
            $log->print("$mprefix $_\n")
                foreach (split(/$::HttpEol/, $header));
            $log->print("$mprefix (Body was ".length($body)." bytes)\n");

            # fix up the queue of outstanding requests
            if (substr($header,0,4) eq "HTTP")
            {
                # don't drop a request for "100 Continue" interim replies
                shift @{$rqRequests} unless $header =~ /^HTTP\/[0-9.]+\s+100/m;
            }
            else
                { push(@{$rqRequests}, $header); }

            $log->print("$mprefix ---------- Request queue length "
                        .scalar(@{$rqRequests})." ----------\n");

            # push back the data for the next item, and try to read another...
            $reader->PushBytes($next);
            $data = $reader->ReadBufferedData();
            ($header,$body, $next) = SplitHttp($data, $mprefix, $log);
        }
        # push back any remaining data....
        $reader->PushBytes( $data );
    }
    return ! $eof;
}

#----------------------------------------------------------------------
#
# Main program, see usage message....
#
my %opts = (
    p => 8080,
    r => "localhost",
    l => undef(),
);
if (! getopts("p:l:r:h", \%opts) or @ARGV > 0 or exists($opts{h}))
{
    print STDERR "Unknown arg $ARGV[0]\n\n" if @ARGV > 0;
    die "Usage: HttpSniffer [-p port] [-r realhost[:realport]] [-l logfile]\n";
}

my($rhost,$rport) = ($opts{r} =~ m!^(?:http://)?([^:]+):?(\d*)$!i);
$rport = 80 unless $rport;
$rhost = "localhost" unless defined($rhost);

my $log = defined($opts{l}) ? new IO::File($opts{l}, "w") : *STDERR;
$log->autoflush;

my $listener = IO::Socket::INET->new(LocalPort   => $opts{p},
                                     Type        => SOCK_STREAM,
                                     Reuse       => 1,
                                     Listen      => 10,
                                     TimeOut     => $main::Timeout);
my $select   = new IO::Select ( $listener );
die "Can't setup listener or selecter\n"
    unless defined($listener) and defined($select);

my %clients;    # the client socket for a given socket
my %servers;    # the server socket for a given socket
my %requests;   # queue of outstanding request headers from each client
while (my @ready = $select->can_read)
{
    my @readyhandles = map { $_->fileno } @ready;
    my @allhandles   = map { $_->fileno } $select->handles;
    $log->print("#### Sockets ".join(",", @readyhandles)." of "
                .join(",",@allhandles)." need checking ####\n");

    # don't close sockets inside this loop, or we'd have to
    # remove them from @ready too, so make a list of what to close
    #
    my(%closeList);
    foreach my $fh (@ready)
    {
        if ($fh == $listener)
        {
            # Accept (create) a new socket - it's a new client.
            # Make a new partner socket to the real host.
            my $c = BufferedSocket->new($listener->accept);
            my $ss = IO::Socket::INET->new(PeerAddr => $rhost,
                                           PeerPort => $rport,
                                           Proto    => 'tcp',
                                           Timeout  => $main::Timeout)
                or die "Can't connect to $rhost:$rport\n";
            my $s = BufferedSocket->new($ss);
            $log->print("#### Adding new client ".$c->fileno.
                        " and server ".$s->fileno."\n");

            # Add them both to the select list....
            ($clients{$c->fileno}, $servers{$c->fileno}) = ($c, $s);
            ($clients{$s->fileno}, $servers{$s->fileno}) = ($c, $s);
            $requests{$c->fileno} = [];
            $select->add($c->Socket, $s->Socket);
        }
        else
        {
            # Data socket, work out the client and server sockets
            my $c = $clients{$fh->fileno};
            my $s = $servers{$fh->fileno};
            my $readfrom = $fh->fileno == $c->fileno ? $c : $s;

            # we write to the one of the pair that we don't read from
            my $writeto = ($readfrom == $c) ? $s : $c;
            my $mprefix = ($readfrom == $c)
                ? "Client ".$c->fileno." to server ".$s->fileno
                : "Server ".$s->fileno." to client ".$c->fileno;

            if (! HandleSocketData($readfrom, $writeto,
                                   $requests{$c->fileno}, $mprefix, $log))
            {
                $closeList{$c->fileno} = $c;
                $closeList{$s->fileno} = $s;
            }
        }
    }

    # mark for closing any socket pairs with errors (rarely if ever happens)
    my @errs = $select->has_error(0);
    foreach (@errs)
    {
        $closeList{$clients{$_->fileno}} = $clients{$_->fileno};
        $closeList{$servers{$_->fileno}} = $servers{$_->fileno};
    }

    # Now close all the sockets that need it
    foreach (keys %closeList)
    {
        $log->print("Removing dead socket $_\n");
        $select->remove( $closeList{$_}->Socket );

        delete $clients{$_};
        delete $servers{$_};
        delete $requests{$_};

        $closeList{$_}->Socket->close;
        $closeList{$_} = undef;
    }
}

die "Done and die\n";   # never really gets here... just for completeness

package BufferedSocket;
#----------------------------------------------------------------------
#
# A BufferedSocket reads data from a socket and returns it a char at a time.
# Data can be pushed back onto a buffered socket, but more importantly we can
# reda up to a certain string, or read a number of bytes.
#
#----------------------------------------------------------------------

# Takes one param, the socket to use
sub new
{
    shift;
    my $self = bless {};
    $self->{socket} = shift;
    $self->{data} = "";
    return $self;
}

# Basic inline type methods - return the raw socket object etc.
sub Socket              { $_[0]->{socket}; }
sub fileno              { $_[0]->{socket}->fileno; }
sub NumBytesAvailable   { length($_[0]->{data}); }
sub Write               { syswrite( $_[0]->{socket}, $_[1], length($_[1]) ); }

#
# Reads as many bytes as possible from the socket without blocking and
# return the number of bytes read from the socket.
# To do this, we read until the first time we get less bytes than we asked for
#
sub FillReadBuffer
{
    my $self    = shift;
    my $numIn   = (@_ == 0) ? 4096 : shift;
    my $nr      = 0;
    my $total   = 0;

    do {
        my $buf;
        $nr = sysread($self->{socket}, $buf, $numIn);
        if (defined($nr) and $nr > 0)
        {
            $total          += $nr;
            $self->{data}   .= $buf;
        }
    } while (defined $nr and $nr == $numIn);

    return $total;
}

#
# Return the current n chars, or up to end of buffered data.
# If numbytes isn't specified, reads whatever is in the cache.
#
sub ReadBufferedData
{
    my ($self, $n) = @_;
    $n = length($self->{data}) unless defined($n) and $n >= 0;
    return substr($self->{data}, 0, $n, "");
}

#
# Push back the specified bytes into the socket read buffer
#
sub PushBytes
{
    my ($self, $str) = @_;
    $self->{data} = $str . $self->{data} if defined($str);
}

