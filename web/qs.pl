#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
use CGI::Carp;
use HTML::Entities;
use Date::EzDate;
use Petal;
require '../WildlifeDB.pm';

#this is a hack that allows use to search within a number of miles of a point
my $lat_unit;
my $lon_unit;


my $wd = new WildlifeDB();

my %anonymous_exclude = read_anonymous_exclude();

my $species = $wd->scrub_sql($wd->cgi->param('species'));
my $multiple_species = $wd->scrub_sql($wd->cgi->param('multiple_species'));
my $multiple_years = $wd->scrub_sql($wd->cgi->param('multiple_years'));
my $username = $wd->scrub_sql($wd->cgi->param('username'));
my $startdate = $wd->scrub_sql($wd->cgi->param('startdate'));
my $enddate = $wd->scrub_sql($wd->cgi->param('enddate'));
my $activity = $wd->scrub_sql($wd->cgi->param('activity'));
my $limit;
if(defined($wd->cgi->param('limit')) && $wd->cgi->param('limit') =~ /^\d+$/){
	$limit = $wd->cgi->param('limit');
}else{
	$limit = 1000;
}
my $sth;
my @sets;

if($wd->auth->loggedIn && $wd->cgi->param('mysightings')){
    $sth = $wd->dbh->prepare("SELECT * FROM sightings WHERE id in (SELECT sightingid FROM sighting_creator WHERE sessionid like ?)");
    $sth->execute($wd->auth->_session->id()) || 
	croak "failed to execute sql call" . $wd->dbh->errstr;
    my $set = proccess_results($sth) if $sth;
    if($set){
        $set->{'set_name'} = "This Report";
        push(@sets, $set);
    }
}elsif($wd->auth->loggedIn && $username){
    my $sql = "SELECT * FROM sightings WHERE username LIKE ? ORDER by date DESC";    
    $sql .=  " LIMIT $limit";
    $sth = $wd->dbh->prepare($sql)
	|| croak "failed to prepare sql statemen: " . $wd->dbh->errstr;
    $sth->execute($username) ||
	croak "failed to execute sql statement: " . $wd->dbh->errstr;
    my $set = proccess_results($sth) if $sth;
    if($set){
        $set->{'set_name'} = $username;
        push(@sets, $set);
    }
}elsif($multiple_years && $startdate && $enddate && $species){
    my @years = split(/:/, $multiple_years);
    foreach my $year(@years){
	query_species($species, "$year-$startdate", "$year-$enddate");
	my $set = proccess_results($sth) if $sth;
	if($set){
	    if($#{$set->{'sightings'}} > 0){
		$set->{'set_name'} = "$year $startdate to $enddate";
		push(@sets, $set);
	    }
	}
    }
}elsif($species){
    query_species($species, $startdate, $enddate);
    my $set = proccess_results($sth) if $sth;
    if($set){
	$set->{'set_name'} = $species;
        push(@sets, $set);
    }
}elsif($multiple_species){
    my @species_list = split(/:/, $multiple_species);
    foreach my $species (@species_list){
	query_species($species, $startdate, $enddate);
	my $set = proccess_results($sth) if $sth;
	if($set){
	    if($#{$set->{'sightings'}} > 0){
		$set->{'set_name'} = $species;
		push(@sets, $set);
	    }
	}
    }
}else{
#no species selected
}

my $template_file;
my $mimetype;
my $output_format = $wd->cgi->param("format") || "";

if($output_format eq "wildlifedb"){
  $template_file = "qs-wildlifedb.xml";
  $mimetype = "text/xml";
}elsif($output_format eq "kml"){
  $template_file = "qs-kml.kml";
  $mimetype = "application/vnd.google-earth.kml+xml\nContent-Disposition: attachment; filename=\"sightings.kml\"";
}else{
  $template_file = "qs-error.xml";
  $mimetype = "text/xml";
}

#push(@sets, proccess_results($sth)) if $sth;

my $template = new Petal(
			 base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			 file => $template_file,
			 input => "XML",
			 output => "XML"
);
print "Content-Type: $mimetype\n\n",
$template->process ( sighting_sets => \@sets,
		    count_fields => $wd->count_fields(),
		     user => $wd->auth );

sub query_species{
    my ($species, $start, $end) = @_;
        my $sql = "SELECT * FROM sightings WHERE species LIKE ?";
    if($start && $end){
	$sql .=  " AND date BETWEEN " . $wd->dbh->quote($start). 
	    " AND " . $wd->dbh->quote($end . " 23:59:59");
    }
    if($activity){
	$sql .= " AND activity LIKE " . $wd->dbh->quote($activity);
    }
    if($wd->cgi->param('centerlat') && $wd->cgi->param('centerlon') && 
       $wd->cgi->param('centerdist')){
	calculate_margins($wd->cgi->param('centerlat'), $wd->cgi->param('centerlon'), 1, "miles");
	
	$sql .= " AND latitude BETWEEN " .
	    ($wd->cgi->param('centerlat') - ($lat_unit * $wd->cgi->param('centerdist')))
	    . " and " . 
	    ($wd->cgi->param('centerlat') + ($lat_unit * $wd->cgi->param('centerdist')))
	    . " AND longitude BETWEEN " .
	    ($wd->cgi->param('centerlon') - ($lon_unit * $wd->cgi->param('centerdist')))
	    . " and " . 
	    ($wd->cgi->param('centerlon') + ($lon_unit * $wd->cgi->param('centerdist')));
    }
    if(!$wd->auth->loggedIn){
       	if(my $bdate = get_before_date($species)){
	    #carp "using before date < $bdate";
	    $sql .= " AND date < '$bdate'";
	}
    }
    $sql .= " ORDER by date DESC";
    $sql .=  " LIMIT $limit";
    #carp($sql);
    $sth = $wd->dbh->prepare($sql)
	|| croak "failed to prepare sql statemen: " . $wd->dbh->errstr;
    $sth->execute($species) ||
	croak "failed to execute sql statement: " . $wd->dbh->errstr;
}

sub format_fields{
    my %in = %{shift @_};
    my %out;
    foreach(@{$wd->count_fields()}){
	$out{$_} = defined($in{$_})?$in{$_}:0;
    }
    if($in{'date'} =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/){
	$out{'date'} = "$1-$2-$3";
	unless($4 eq "00" && $5 eq "00"){
	    $out{'date'} .= " $4:$5";
	}
    }
    if( $in{'date_end'} && $in{'date_end'} =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/){
	$out{'date_end'} = "$1-$2-$3";
	unless($4 eq "00" && $5 eq "00"){
	    $out{'date_end'} .= " $4:$5";
	}
    }
    if($in{'image'}){
      $out{'image'} = $wd->conf("image uri") . $in{'image'};
    }
    foreach(qw(id species latitude longitude latitude_end longitude_end activity notes username image_height image_width)){
	$out{$_} = defined($in{$_})?$in{$_}:""; 
    }
    return \%out;
}

sub proccess_results{
    my $sth = shift;
    my %res;
    my @results;
    while($res = $sth->fetchrow_hashref()){
	my %data = %{format_fields($res)};
	my $total = 0;
	my @cf;
	foreach $l(@{$wd->count_fields()}){
	    $total +=  $data{$l};
	    push(@cf, {"name" => $l, "value" => $data{$l}});
	}
	$data{'total'} = $total;
	$data{'counts'} = \@cf;
	$data{'caption'} = "$total $data{'species'} - $data{'date'}";
	if($wd->user_can_modify($data{'id'}, "sightings")){
	  $data{'update_link'} = "sighting.pl?action=update&id=$data{'id'}";
	  $data{'delete_link'} = "sighting.pl?action=delete&id=$data{'id'}";
	}
	push(@results, \%data);
    }
    my %out;
    $out{'set_name'} = "wildlife sightings";
    #$out{'set_name'} = "00";
    $out{'sightings'} = \@results;
    return \%out;
}

sub read_anonymous_exclude {
#carp "readin anonymous exclude";    
my $file = $wd->conf('anonymous exclude file');
    open(CF, $file) || croak "can't open anonymous_exclude_file: $!";
    my $line;
    my %excludes;
    while($line = <CF>){
	if($line !~ /^\#/){
	    my %data;
	    chomp $line;
	    my $species;
	    ($species, $data{'start month'}, $data{'start day'}, $data{'end month'},  $data{'end day'}) = 
		split(/:/, $line);
	    $excludes{$species} = \%data;
	}
    }
    close(CF);
    return %excludes;
}
sub get_before_date {
    my $species = shift @_;
    if($anonymous_exclude{$species}){
       	#carp "checking before data for $species"; 
my $start = Date::EzDate->new();
	$start->{'month number base 1'} = $anonymous_exclude{$species}->{'start month'};
	$start->{'day of month'} = $anonymous_exclude{$species}->{'start day'};
	my $end = Date::EzDate->new();
	$end->{'month number base 1'} = $anonymous_exclude{$species}->{'end month'};
	$end->{'day of month'} = $anonymous_exclude{$species}->{'end day'};
       	my $now = Date::EzDate->new();
	if($end < $start){
	    #crosses year boundary
	    if($now->{'month number base 1'} <= $end->{'month number base 1'}){
		$start->{'year'}--;
	    }elsif($now->{'month number base 1'} >= $start->{'month number base 1'}){
		$end->{'year'}++;
	    }
	}
	
	if(($start <= $now) && ($now <= $end)){
	    #carp "start $start end $end\n";
	    return "$start->{'year'}-$start->{'month number base 1'}-$start->{'days in month'} 23:59:00";
	}else{
	    return;
	}
    }else{
	return;
    }
}

#This function get the arccos function using arctan function
sub calculate_margins{
    my  ($lat, $lon, $distance, $unit) = @_;
    #latitude - the easy part 1 deg = 111.325 kilometers (69.172 miles)
    if($unit eq "km"){
	$lat_unit = ($distance/111.325);
    }else{#miles
	$lat_unit = ($distance/69.172);
    }
    
    #longitude
     if($unit eq "km"){
	my $oneDeg = cos($lat) * 111.325;
	$lon_unit = ($distance/$oneDeg);
    }else{#miles
	my $oneDeg = cos($lat) * 69.172;
	$lon_unit = ($distance/$oneDeg);
    }
}

sub acos {
    my ($rad) = @_;
    my $ret = atan2(sqrt(1 - $rad**2), $rad);
    return $ret;
}

sub deg2rad {
    my $pi = atan2(1,1) * 4;
    my ($deg) = @_;
    return ($deg * $pi / 180);
}

sub rad2deg {
    my $pi = atan2(1,1) * 4;
    my ($rad) = @_;
    return ($rad * 180 / $pi);
}
