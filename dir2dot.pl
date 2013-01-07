#!/usr/bin/perl

# dir2dot.pl  v0.5 (C) Darxus@ChaosReigns.com, released under the GPL.
# Download from: http://www.chaosreigns.com/code/
#
# Generates a directed graph of a directory tree using graphviz like so:
# 
# find / -type d -xdev -maxdepth 2 -print | ./dir2dot.pl > dirtree.dot
# neato -Tps dirtree.dot > dirtree.ps
#
# Graphviz can be downloaded from: http://www.research.att.com/sw/tools/graphviz/

while ($line = <STDIN>)
{
  chomp $line;
  $target_name=$line;
  @target = split(/\//,$line);
  $target_label = (reverse(@target))[0];
  $#target--;
  $source_name = join('/',@target);
  next if $target_name eq '';
  $source_name = '/' if $source_name eq "";
  $target_label = '/' if $target_label eq "";
  push (@nodes,"\"$target_name\" [label=\"$target_label\"]");
  $edges{$target_name} = $source_name;
}

print "digraph \"directory tree\" {\n";
print join("\n",@nodes),"\n";
for $key (sort keys %edges)
{
  print "\"$edges{$key}\" -> \"$key\" [len=3]\n";
}
print "}\n";
