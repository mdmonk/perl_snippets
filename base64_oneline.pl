#!/usr/bin/perl

use MIME::Base64;

##$txt2decode = 'c2ViYXN0aWFuJXBva3V0dGEuZGUgOWI4OTNlNGI0M2NjNGI3YTM1MGViYmU3OWFkYWE3Y2E=';
$txt2decode = '3963ae5a267162ce7459e64a749281e1';
##perl -MMIME::Base64 -le 'print decode_base64("$txt2decode")'
print decode_base64("$txt2decode");
