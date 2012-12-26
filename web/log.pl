#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
use CGI::Carp qw(fatalsToBrowser);
use Petal;
use Image::Magick;
use Digest::MD5 qw( md5_hex );
require '../WildlifeDB.pm';
use strict;

my $wd = new WildlifeDB();
my @fields = qw(operator message important);
my $table = "log";

if ($wd->auth->loggedIn  && $wd->auth->profile('post') ) {
    my %p = $wd->cgi->Vars;
    my $notification;
    my $toEdit;
    my $operator = "";
    if($p{'message'}){
        my $input = parse_params(\%p);

        if(!$input->{'operator'}){
	    $notification = "You must enter your name";
	}else{
	    if($input->{'important'} eq "TRUE"){
		$input->{'important'} = 1;
	    }else{
		$input->{'important'} = 0;
	    }
	    $wd->insert_record($table, $input);
	    $notification = "Message Logged";
	    $operator = $input->{'operator'};
	}
    }
    
    my $sth = $wd->dbh->prepare("SELECT * FROM log ORDER BY date DESC LIMIT 200");
    $sth->execute;
    my @results;
    while(my $row = $sth->fetchrow_hashref){
	push(@results, $row);
    }
    my $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			   file => "log.xhtml",
			   input => "XHTML",
			   output => "XHTML"
			  );
    print $wd->cgi->header,
	  $template->process(logRows => \@results,
			     operator => $operator,
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
    return \%o;
}
