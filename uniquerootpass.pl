#!/usr/bin/perl

use Digest::SHA1 qw(sha1_base64);

$secret="s3crut";
$host="d5ibrsec";

print substr(sha1_base64($host.$secret),0,8);
