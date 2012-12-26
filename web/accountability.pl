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

    my $day = DateTime->today();
    $day->subtract(days=>7);
    my $r = $wd->get_report("username", $day->ymd , "7 DAY", "Last 7 Days", 1);
    push(@reports, $r);
    
    $day = DateTime->today();
    for(my $i = 0; $i < 7; $i++){
        $r = $wd->get_report("username", $day->ymd . " 12:00", "12 HOUR", $day->day_name . " " . $day->month_name . " " .  $day->day. " PM");
        push(@reports, $r);
        $r = $wd->get_report("username", $day->ymd . " 00:00", "12 HOUR", $day->day_name . " " . $day->month_name . " " .  $day->day. " AM");
        push(@reports, $r);
        $day->subtract(days=>1);
    }
    
    
    my $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			   file => "accountability.xhtml",
			   input => "XHTML",
			   output => "XHTML"
			  );
    
    print $wd->cgi->header,
	  $template->process(reports => \@reports,
			     notification => $notification,
                             report_date => DateTime->now->ymd
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
