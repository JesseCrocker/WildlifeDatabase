#!/usr/bin/perl -w
require '../WildlifeDB.pm';

my $wd = new WildlifeDB();
#my $cmd = "find " . $wd->conf("base dir") . $wd->conf("graph_dir") . " -name '*.png' -mtime 1 -delete";
my $cmd = "find " . $wd->conf("base dir") . $wd->conf("graph_dir") . " -name '*.png' -delete";
#print $cmd . "\n";
`$cmd`;