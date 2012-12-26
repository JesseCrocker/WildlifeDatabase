#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
use CGI::Carp qw(fatalsToBrowser);
use Petal;
use Image::Magick;
use Digest::MD5 qw( md5_hex );
require '../WildlifeDB.pm';
use strict;

my $wd = new WildlifeDB();
my @fields = qw(name latitude longitude notes id);
my $table = "landmarks";

if ($wd->auth->loggedIn  && ($wd->auth->profile('landmarks') || $wd->auth->profile('admin') ) ) {
    my %p = $wd->cgi->Vars;
    my $notification;
    my $toEdit;
    if($p{'action'}){
	if($p{'action'} eq "delete" && $p{'id'}){
	    $wd->delete_record($table, $p{'id'});
	    $notification = "Landmark Deleted";
        }elsif($p{'action'} eq "new"){
	    my $input = parse_params(\%p);

	    if(!$input->{'name'}){
		$notification = "You must enter a name";
	    }elsif(!$input->{'latitude'} || !$input->{'longitude'}){
		$notification = "You must Choose a location";
	    }else{
		if($wd->cgi->param('uploaded_file')){
		    if(my $f = $wd->photo_upload()){
			$input->{'image'} = $f->{'filename'};
		    }
	        }
		
		$wd->insert_record($table, $input);
		$notification = "Landmark Added";
	    }	    
        }elsif($p{'action'} eq "update"){
     	    my $input = parse_params(\%p);

	    if($wd->cgi->param('uploaded_file')){
	        if(my $f = $wd->photo_upload()){
		    $input->{'image'} = $f->{'filename'};
		}
	    }
	    $wd->update_record($table, $input);
	    $notification = "Landmark Updated";
        }elsif($p{'action'} eq "edit"){
	    $toEdit = $p{'id'};
	}
	
    }
    my $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			   file => "landmark.xhtml",
			   input => "XHTML",
			   output => "XHTML"
			  );
    if($toEdit){
	print $wd->cgi->header,
	  $template->process(landmarks=>$wd->get_landmarks(),
			     elandmark=>$wd->get_landmark($toEdit),
			    notification => $notification,
			    edit => 1
		      );
    }else{
	my %blank;
	foreach my $field( qw(name latitude longitude notes id)){
	    $blank{$field} = "";
	}
	print $wd->cgi->header,
	  $template->process(landmarks=>$wd->get_landmarks(),
			     elandmark => \%blank,
			     notification => $notification,
			     edit => 0
			    );
    }
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
