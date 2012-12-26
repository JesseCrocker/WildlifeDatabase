#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
require '../WildlifeDB.pm';
use Petal;
use Petal::Utils qw(Each);
use CGI::Carp qw(fatalsToBrowser);
use strict;

my $wd = new WildlifeDB();
my @fields = qw(userid username passwd admin moderator post landmarks password_change);
my $table = "auth_user";


if ($wd->auth->loggedIn && $wd->auth->profile('admin')) {
    my %p = $wd->cgi->Vars;
    my $notification;

    if($p{'action'}){
	if($p{'action'} eq "delete" && $p{'userid'}){
	    $wd->delete_record($table, $p{'userid'}, "userid");
	    $notification = "User Deleted";
        }elsif($p{'action'} eq "new"){
	    my $input = parse_params(\%p);
	    $input->{'userid'} = $wd->auth->uniqueUserID;
	    if(!$input->{'username'}){
		$notification = "Username can not be blank";
	    }elsif(!$input->{"passwd"}){
		$notification = "Password can not be blank";
	    }else{
		$wd->insert_record($table, $input);
		$notification = "User Added.";
	    }
	}elsif($p{'action'} eq "update"){
     	    my $input = parse_params(\%p);
	    if(!$input->{'username'}){
		$notification = "Username can not be blank";
	    }elsif(!$input->{"passwd"}){
		$notification = "Password can not be blank";
	    }else{
		$wd->update_record($table, $input, "userid");
		$notification = "User Modified.";
	    }
	}
    }
    
    my $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			   file => "user.xhtml",
			   input => "XHTML",
			   output => "XHTML"
			  );
    print $wd->cgi->header,
	  $template->process(users => $wd->get_users(),
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

sub parse_params{
#take a hash of args from cgi
#return a hash of data that has been sanitized and had unecesary fields removed
    my %params = %{shift @_};
    my %o;
    foreach my $p (@fields){
	$o{$p} = $params{$p} if $params{$p};
	#carp $p . " : " . $params{$p};
    }
    return \%o;
}
