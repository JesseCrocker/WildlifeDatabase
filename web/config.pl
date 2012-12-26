#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
require '../WildlifeDB.pm';
use Petal;
use Petal::Utils qw(Each);
use CGI::Carp qw(fatalsToBrowser);

use strict;

my $template;

my $wd = new WildlifeDB();
if ($wd->auth->loggedIn && $wd->auth->profile('admin')) {
  my %params = $wd->cgi->Vars;
  foreach my $key(keys(%params)){
    if($key =~ /^conf\ (.*)/){
      $wd->conf($1, $params{$key});
    }
  }

  $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			   file => "config.xhtml",
			   input => "XHTML",
			   output => "XHTML"
			  );
}else{
  $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			   file => "not_authorized.xhtml",
			   input => "XHTML",
			   output => "XHTML"
			  );  
}  
  print "Content-Type: text/html\n\n",
    $template->process( wd => $wd);
