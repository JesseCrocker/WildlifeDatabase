#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
use CGI::Carp qw(fatalsToBrowser);
use Petal;
require '../WildlifeDB.pm';
use strict;

my $wd = new WildlifeDB();
my $table = "layer";
my @fields = qw(name url id visible cgi);

if ($wd->auth->loggedIn  && ($wd->auth->profile('landmarks') || $wd->auth->profile('admin') ) ) {
  my %p = $wd->cgi->Vars;
  my $notification;
  if($p{'action'}){
    if($p{'action'} eq "delete" && $p{'id'}){
      $wd->delete_record($table, $p{'id'});
      $notification = "Layer Deleted";
    }elsif($p{'action'} eq "new"){
      $wd->insert_record($table, parse_params(\%p));
      $notification = "Layer Added";
    }elsif($p{'action'} eq "update"){
      $wd->update_record($table, parse_params(\%p));
      $notification = "Layer Updated";
    }
  }

  my $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			   file => "layers.xhtml",
			   input => "XHTML",
			   output => "XHTML"
			  );
  print $wd->cgi->header,
    $template->process(layers=>$wd->get_layers(),
		       notification => $notification
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

##############################################
sub parse_params{
#take a hash of args from cgi
#return a hash of data that has been sanitized and had unecesary fields removed
    my %params = %{shift @_};
    my %o;
    foreach my $p (@fields){
	$o{$p} = $params{$p} if $params{$p};
	#carp $p . " : " . $params{$p};
    }
    if(!$o{"visible"}){
      $o{"visible"} = "0";
    }
    return \%o;
}
