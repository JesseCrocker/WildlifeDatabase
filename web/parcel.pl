#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
use CGI::Carp qw(fatalsToBrowser);
use Petal;
require '../WildlifeDB.pm';
use strict;

my $wd = new WildlifeDB();
my $table = "parcels";
my @fields = qw(ParcelID owner_code date_mod source mapper county_code county
		gis_acre owner_name care_od access township legal_desc
		total_acre property_address mail_addr mail_city mail_state
		mail_zip source_desc mapper_desc doing_business notes buffalo_friendly cows);

my %p = $wd->cgi->Vars;
my $edit = 0;
my $notification;

if ($wd->auth->loggedIn  && ($wd->auth->profile('landmarks') || $wd->auth->profile('admin') ) ) {
  if($p{'action'}){
    if($p{'action'} eq "delete" && $p{'id'}){
      $wd->delete_record($table, $p{'ParcelID'}, "ParcelID");
      $notification = "Parcel Deleted";
    }elsif($p{'action'} eq "update"){
      $wd->update_record($table, parse_params(\%p), "ParcelID");
      $notification = "Parcel Updated";
    }elsif($p{'action'} eq "edit" && $p{'ParcelID'}){
      $edit = 1;
    }
  }
}

my $parcel;
if( $p{'ParcelID'}){
  $parcel = $wd->get_parcel($wd->scrub_sql($p{'ParcelID'}) );
}

my $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			   file => "parcel.xhtml",
			   input => "XHTML",
			   output => "XHTML"
			  );

print $wd->cgi->header,
    $template->process(edit => $edit,
		       parcel => $parcel,
		       notification => $notification
		      );

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
