#!/usr/bin/perl
use Carp;
require '../WildlifeDB.pm';

my $wd = new WildlifeDB();

my $sth = $wd->dbh->prepare("DELETE FROM sighting_creator WHERE ts < DATE_SUB(now(), INTERVAL 2 DAY)");
$sth->execute || croak "failed to exec sql call" . $sth->errstr;

