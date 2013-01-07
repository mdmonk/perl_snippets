#########################################################
# Attempt to run FTP through Perl on a Win32 system.
#########################################################

require "ftp.pl";

ftp'open(ov00ux1,21,3,3);
ftp'login(mdmonk, chuckie7);
@lines=ftp'ls();
ftp'quit;
print @lines;

