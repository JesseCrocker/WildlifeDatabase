#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
use CGI::Carp;
use HTML::Entities;
use Petal;
require '../WildlifeDB.pm';
use strict;

my $latMile = .0145;
my $lonMile = .0204277038;

my $wd = new WildlifeDB();


my $sql = "SELECT * FROM landmarks";

my $landmarkList;
if($landmarkList = $wd->cgi->param("landmarkList")){
    my @landmarks = split(/,/, $landmarkList);
    
    $sql .= " WHERE name IN (";
    my $first = 0;
    foreach my $l(@landmarks){
	$sql .= "," if $first++;
	$sql .= "'$l'";
    }
    $sql .= ")";
}elsif($wd->cgi->param('centerlat') && $wd->cgi->param('centerlon') && 
   $wd->cgi->param('centerdist')){
    $sql .= " WHERE latitude BETWEEN " .
	($wd->cgi->param('centerlat') - ($latMile * $wd->cgi->param('centerdist')))
	. " and " . 
	($wd->cgi->param('centerlat') + ($latMile * $wd->cgi->param('centerdist')))
	. " AND longitude BETWEEN " .
	($wd->cgi->param('centerlon') - ($lonMile * $wd->cgi->param('centerdist')))
	. " and " . 
	($wd->cgi->param('centerlon') + ($lonMile * $wd->cgi->param('centerdist')));
}
$sql .= " ORDER by name";
my $limit;
if(defined($wd->cgi->param('limit')) && $wd->cgi->param('limit') =~ /^\d+$/){
    $limit = $wd->cgi->param('limit');
}else{
    $limit = 100;
}
$sql .=  " LIMIT $limit";
my $sth = $wd->dbh->prepare($sql)
    || croak "failed to prepare sql statement: $wd->dbh->errstr";
$sth->execute ||
    croak "failed to execute sql statement: " . $wd->dbh->errstr;

#################Output

my $template_file;
my $mimetype;
my $output_format = $wd->cgi->param("format") || "";

if($output_format eq "wildlifedb"){
  $template_file = "q-landmark.xml";
  $mimetype = "text/xml";
}elsif($output_format eq "kml"){
  $template_file = "q-landmark.kml";
  $mimetype = "application/vnd.google-earth.kml+xml\nContent-Disposition: attachment; filename=\"landmarks.kml\"";
}else{
  $template_file = "qs-error.xml";
  $mimetype = "text/xml";
}

my $template = new Petal(
			 base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			 file => $template_file,
			 input => "XML",
			 output => "XML"
);
print "Content-Type: $mimetype\n\n",
$template->process ( landmarks => proccess_results($sth) );

sub format_fields{
    my %in = %{shift @_};
    my %out;
    foreach(qw(name notes latitude longitude id)){
	$out{$_} = defined($in{$_})?$in{$_}:""; 
    }
    return \%out;
}

sub proccess_results{
    my $sth = shift;
    my @results;
    while(my $res = $sth->fetchrow_hashref()){
	my %data = %{format_fields($res)};
	push(@results, \%data);
    }
    return \@results;
}
