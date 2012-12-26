#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
use CGI::Carp;
use Petal;
use strict;
require '../WildlifeDB.pm';

my $wd = new WildlifeDB();

my $base_url = $wd->conf('baseurl') || "";

if($wd->cgi->param('logout')){
    $wd->auth->logout;
    print $wd->cgi->header(), $wd->cgi->start_html,
    '<meta http-equiv="Refresh" content="0; URL=' . $base_url . '/sighting.pl">', 
    $wd->cgi->end_html; 
}elsif($wd->auth->loggedIn){
    print $wd->cgi->header( -cookie=>$wd->auth->sessionCookie), $wd->cgi->start_html,
    '<meta http-equiv="Refresh" content="0; URL=' . $base_url . '/sighting.pl">', 
    $wd->cgi->end_html;
}else{
    my $notification;
    if($wd->cgi->referer() =~ /login.pl/){
	$notification = "Login Failed";
    }
    my $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			   file => "login.xhtml",
			   input => "XHTML",
			   output => "XHTML"
			  );
    print $wd->cgi->header,
	$template->process(notification => $notification);
}
