#!/usr/bin/perl -w
use Carp;
use DateTime;
require '../WildlifeDB.pm';

my $wd = new WildlifeDB();

my $outfile = $wd->conf("base dir") . $wd->conf("backup dir") . "/". DateTime->now->ymd . ".sql";

my $cmd = "mysqldump -h " . $wd->{'conf_file'}->{'dbserver'} . " -u " . $wd->{'conf_file'}->{'dbuser'} .
" --password=" . $wd->{'conf_file'}->{'dbpassword'} . " " . $wd->{'conf_file'}->{'db'} . " > $outfile";

#print $cmd . "\n";

`$cmd`;
