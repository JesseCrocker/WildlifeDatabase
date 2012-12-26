#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
use CGI::Carp qw(fatalsToBrowser);
use DateTime;
use GD::Graph;
use GD::Graph::bars;
use Digest::MD5 qw( md5_hex );
use Math::Round qw(nearest);
use Petal;
require '../WildlifeDB.pm';

use strict;

my $wd = new WildlifeDB();

my $lat_margin;
my $lon_margin;

my $error_message;
my $message;

my %params = $wd->cgi->Vars;

my %report_params;
$report_params{'sort_key'} = $params{'sort_key'};
$report_params{'unique_per_day'} = $params{'unique_per_day'};
$report_params{'graph'} = $params{"graph"};

if($params{'distance'}){
    $report_params{'distance'} = $params{'distance'};
}else{
   $error_message = "Error: You must enter a distance.";
   output();
}

if($params{'distance_unit'}){
    $report_params{'distance_unit'} = $params{'distance_unit'};
}else{
   $error_message = "Error: You must select a distance unit.";
   output();
}

if($params{'latitude'} && $params{'longitude'}){
    $report_params{'latitude'} = $params{'latitude'};
    $report_params{'longitude'} = $params{'longitude'};
}else{
    unless($params{"landmarks"}){
        $error_message = "Error: You choose a location or select a landmark.";
        output();
    }
}
if($params{'activity'}){    
    my @activities = split("\0", $params{'activity'});
    $report_params{'activity'} = \@activities;
    
    $report_params{'activity_op'} = $params{'activity_op'};
    if($report_params{'activity_op'} eq "inc"){
        $message = "Activities include: ";
    }else{
	$message = "Activities exclude: ";
    }
    my $c = 0;
    foreach $a(@activities){
	if($c++ != 0){
	    $message .= ", ";
	}
	$message .= $a;
    }
}

my @reports;

if($params{'species'}){
    my @species = split("\0", $params{'species'});
    foreach my $s(@species){
	$report_params{'species'} = $s;
	if($params{'landmarks'}){
	    my @landmarks = split("\0", $params{'landmarks'});
	    foreach my $landmarkID(@landmarks){
		my $landmark = $wd->get_landmark($landmarkID);
		$report_params{"latitude"} = $landmark->{'latitude'};
		$report_params{"longitude"} = $landmark->{'longitude'};
		$report_params{"landmark"} = $landmark->{"name"};
		my $report = get_location_report(\%report_params);
		push(@reports, $report);	
	    }
	}else{
	    my $report = get_location_report(\%report_params);
	    push(@reports, $report);
	}
    }
}else{
    $error_message = "Error: You must select at least one species.";
}

output();

sub output{
    my $template = new Petal(
			       base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			       file => "habitat-usage.xhtml",
			       input => "XHTML",
			       output => "XHTML"
			      );
    
    print $wd->cgi->header,
	$template->process(error_message => $error_message,
			   message => $message,
			   reports => \@reports,
			   distance => $report_params{'distance'},
			   distance_unit => $report_params{'distance_unit'},
			   report_date => DateTime->now->ymd
			  );
    
    exit;
}
############################
sub get_location_report {
    my %sightings_recorded;
    my %params = %{shift @_};
    my $sightings_proccessed = 0;
    my $duplicate_sightings = 0;
    my %data;
    if(!$lat_margin){
	calculate_margins($params{'latitude'}, $params{'longitude'}, $params{'distance'}, $params{'distance_unit'});
    }
    my %report;
    
    my $sql = "select * from sightings WHERE species LIKE ?";
    $sql .= " AND latitude BETWEEN " . 
	($params{'latitude'} - $lat_margin) . " and " . ($params{'latitude'} + $lat_margin) . 
	" AND longitude BETWEEN " .
	($params{'longitude'} - $lon_margin) . " and " . ($params{'longitude'} + $lon_margin);
	
    if($params{'activity'}){
	if($params{'activity_op'} eq "exc"){
	    $sql .= " and activity NOT in (";
	}else{
	    $sql .= " and activity in (";
	}
	my $count = 0;
	foreach my $a (@{$params{'activity'}}){
	    if($count++ != 0){
		$sql .= ", ";
	    }
	    $sql .= "'$a'";
	}
	$sql .= ")";
    }
    $sql .= " ORDER by date DESC";
    #carp $sql;
    my $sth = $wd->dbh->prepare($sql) 
	|| croak "failed to prepare sql statement: " . $wd->dbh->errstr;
    if($sth->execute($params{'species'})){	
	while(my $r = $sth->fetchrow_hashref){
	    $sightings_proccessed++;
	    if(distance($params{'latitude'}, $params{'longitude'}, $r->{'latitude'}, $r->{'longitude'},
			$params{'distance_unit'}) > $params{'distance'}){
		#next;
	    }
	    my $count = 0;
	    foreach my $l(@{$wd->count_fields}){
		$count +=  $r->{$l} || 0;
	    }
	    $sightings_recorded{$r->{'id'}} = $count;
	    if($r->{'date'} =~ /^(\d\d\d\d)\-(\d\d)-(\d\d)/){
		my $year = $1;
		my $month = $2;
		my $day = $3;
		my $pkey;
		my $skey;
		if($params{'sort_key'} eq 'season'){
		    $pkey = $month <= 6?(($year - 1) . "/$year"):("$year/" . ($year + 1));
		    $skey =  "$year-$month-$day";
		}elsif($params{'sort_key'} eq 'year'){
		    $pkey = $year;
		    $skey =  "$year-$month-$day";
		}elsif($params{'sort_key'} eq 'month'){
		    $pkey = $month;
		    $skey =  "$year-$month-$day";
		}else{
		    croak "unknown sort_key";
		}
		unless($params{'unique_per_day'} && grep(/^$count$/, @{$data{$pkey}{$skey}})){
		    push(@{$data{$pkey}{$skey}}, $count) ;
		}else{
		    $duplicate_sightings++;
		}
	    }else{
		croak "failed to extract year from date";
	    }
	}
	my $out = "<table><thead><tr><th>$params{'sort_key'}</th><th>days with sightings</th><th>Average group Size</th></tr></thead><tbody>";
	my %graph_data;
	if($params{'sort_key'} eq "month"){
	    foreach my $m ( 1 .. 12){
		if($m < 10){
		    $m = "0$m";
		    unless( exists $data{$m}){
			$data{$m} = {};
		    }
		}else{
		    unless( exists $data{$m}){
		        $data{$m} = {};
		    }
		}
	    }
	}
	foreach my $pkey (sort(keys(%data))){
	    my $days = 0;
	    my $total = 0;
	    my $sightings = 0;
	    foreach my $date (keys(%{$data{$pkey}})){
		$days++;
		foreach my $count (@{$data{$pkey}->{$date}}){
		    $sightings++;
		    $total += $count;
		}
	    }
	    my $average_group_size =  $sightings?sprintf('%.1f', $total/$sightings):0; 
	    if($params{'sort_key'} eq 'month'){
		my $mydate = Date::EzDate->new();
		$mydate->{'month number base 1'} = $pkey;	
		$out .= "<tr><td>" . $mydate->{'month long'} . "</td><td>$days</td><td>$average_group_size</td></tr>";
	    }else{
		$out .= "<tr><td>$pkey</td><td>$days</td><td>$average_group_size</td></tr>";
	    }
	    $graph_data{$pkey}{'days'} = $days;
	    $graph_data{$pkey}{'average'} =  $average_group_size;
	}
	$out .= "</tbody></table>";
	if($duplicate_sightings){
	    $report{'warn'} = "$duplicate_sightings duplicate sightings not counted.";
	}
	if($params{'graph'}){
	    $report{'graph_url'} =  draw_graph({species => $params{'species'},
				sort_key => $params{'sort_key'},
				location => $params{'landmark'} || $params{'latitude'} . $params{'longitude'},
				data => \%graph_data});
	}
        $report{'html'} = $out;
	$report{'species'} = $params{'species'};
	$report{'location'} = $params{'latitude'} . ", " . $params{'longitude'};
	if($params{"landmark"}){
	    $report{"location_name"} = $params{"landmark"};
	}
        return \%report;
    }else{
	croak "query failed: " . $sth->errstr;
    }
}

sub draw_graph {
    my %params = %{shift @_};
    my %data = %{$params{'data'}};
    my @days_values;
    my @avg_values;
    my $max = 0;
    my @keys = sort(keys(%data));    
    foreach my $key (@keys){
	push(@days_values, ($data{$key}{'days'} || 0));
	push(@avg_values, ($data{$key}{'average'} || 0));
	if($data{$key}{'days'} > $max){
	    $max = $data{$key}{'days'};
	}
	if($data{$key}{'average'} > $max){
	    $max = $data{$key}{'average'};
	}
    }
    if(!@days_values || $#days_values == 0 ){
	return;
    }
    if($params{'sort_key'} eq "month"){
	my @new_keys;
	foreach my $m (@keys){
	    my $mydate = Date::EzDate->new();
	    $mydate->{'month number base 1'} = $m;	
	    push(@new_keys,  $mydate->{'month long'});
	}
	@keys = @new_keys;
    }
    my $filename = md5_hex(localtime, $params{'location'} . $params{"species"}) . ".png";
    my $graph = GD::Graph::bars->new($wd->conf("graph size x"), $wd->conf("graph size y"));
    $graph->set( 
		 x_label           => $params{'sort_key'},
		 y_label           => "",
		 title             => "",
		 bar_spacing       => 10,
		 cumulate          => 0,
		 y_max_value       => nearest(10, $max) + 10,
		 show_values  => 1
		 ) or croak $graph->error;
    $graph->set_legend(("Days With Sightings", "Average Group Size"));
    my $gd = $graph->plot([\@keys, \@days_values, \@avg_values]) or croak $graph->error;
    my $filePath =  $wd->conf('base_dir') . $wd->conf('graph_dir') . $filename;
    open(IMG, ">" . $filePath) or croak "Can't open graph file: $filePath $!";
    binmode IMG;
    print IMG $gd->png;
    close(IMG);
    return $wd->conf('graph_web_dir') . "$filename";
}

#distance stuff
sub calculate_margins{
    my  ($lat, $lon, $distance, $unit) = @_;
    #latitude - the easy part 1 deg = 111.325 kilometers (69.172 miles)
    if($unit eq "km"){
	$lat_margin = ($distance/111.325) * 0.5;
    }else{#miles
	$lat_margin = ($distance/69.172) * 0.5;
    }
    
    #longitude
     if($unit eq "km"){
	my $oneDeg = cos($lat) * 111.325;
	$lon_margin = ($distance/$oneDeg) * 0.5;
    }else{#miles
	my $oneDeg = cos($lat) * 69.172;
	$lon_margin = ($distance/$oneDeg) * 0.5;
    }
}

sub distance {
    my ($lat1, $lon1, $lat2, $lon2, $unit) = @_;
    my $theta = $lon1 - $lon2;
    my $dist = sin(deg2rad($lat1)) * sin(deg2rad($lat2)) + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * cos(deg2rad($theta));
    $dist = acos($dist);
    $dist = rad2deg($dist);
    $dist = $dist * 60 * 1.1515;
    if ($unit eq "km") {
 	$dist = $dist * 1.609344;
    }
    return ($dist);
}

#This function get the arccos function using arctan function
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
