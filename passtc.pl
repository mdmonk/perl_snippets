#!/usr/bin/perl

# 1st place in toorcon password challenge
# challenge was to create a program or algorithm that generates a password
# for a user that's difficult for people to crack or brute force but is easy
# for the user to remember (takes a word as a command line arguement and randomly
# modifies it with a simple algorithm)
# i shortened and obfuscated it just to be cool :)
# -cp5

s''%{uc c}=(a,4,b,6,e,3,i,1,l,1,t,7);for(keys%{uc c}){C{uc}=C{_};C{C{_}}=_}
for(0..Z2){myB;for(split//,ARGV[0]){_=C{_}ifC{_}&&int Z2;B.=_}Z2?D.=reverseB:D.=B}
print"D\n"';s/Z/rand /g;s/[A-D_]/\$$&/g;eval
