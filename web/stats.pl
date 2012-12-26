#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
use CGI::Carp qw(fatalsToBrowser);
use Petal;
use DateTime;
require '../WildlifeDB.pm';
use strict;

my $wd = new WildlifeDB();
my $table = "sightings";

if ($wd->auth->loggedIn ) {
    my $notification;
    my @reports;
    
    my $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			   file => "stats.xhtml",
			   input => "XHTML",
			   output => "XHTML"
			  );
    
    print $wd->cgi->header,
	  $template->process( notification => $notification,
                             report_date => DateTime->now->ymd,
                             species_report => $wd->get_report("species", DateTime->today->subtract(years=>30)->ymd, "30 YEAR", "Species", "1"),
                             species_report_30 => $wd->get_report("species", DateTime->today->subtract(days=>30)->ymd, "30 DAY", "Species", "1"),
                             species_report_90 => $wd->get_report("species", DateTime->today->subtract(days=>90)->ymd, "90 DAY", "Species", "1"),
                             user_report => $wd->get_report("username", DateTime->today->subtract(years=>30)->ymd, "30 YEAR", "User", "1"),
                             user_report_30 => $wd->get_report("username", DateTime->today->subtract(days=>30)->ymd, "30 DAY", "User 30 days", "1"),
                             user_report_90 => $wd->get_report("username", DateTime->today->subtract(days=>90)->ymd, "90 DAY", "User 90 days", "1")
			    );
}else{
  #not authorized
  my $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			   file => "not_authorized.xhtml",
			   input => "XHTML",
			   output => "XHTML"
			  );
  print $wd->cgi->header,
    $template->process();
}
