#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);

require '../WildlifeDB.pm';
use Petal;
use Petal::Utils qw(Each);
use CGI::Carp qw(fatalsToBrowser);

use strict;

my $wd = new WildlifeDB();

my @month_list = ({number=>1, name=>"Jan"},
		  {number=>2, name=>"Feb"},
		  {number=>3, name=>"Mar"},
		  {number=>4, name=>"Apr"},
		  {number=>5, name=>"May"},
		  {number=>6, name=>"Jun"},
		  {number=>7, name=>"Jul"},
		  {number=>8, name=>"Aug"},
		  {number=>9, name=>"Sep"},
		  {number=>10, name=>"Oct"},
		  {number=>11, name=>"Nov"},
		  {number=>12, name=>"Dec"});
my @date_list;
for(my $i = 1; $i <= 31; $i++){push(@date_list, $i)}

my %page_conf;
$page_conf{'countfields'} = join(",", @{$wd->count_fields()});
$page_conf{'default latitude'} = $wd->conf("default latitude"); 
$page_conf{'default longitude'} = $wd->conf("default longitude");
$page_conf{'default zoom'} = $wd->conf("default zoom");
$page_conf{'logged in'} = $wd->auth->loggedIn?"1":"0";
$page_conf{'admin'} = $wd->auth->profile("admin")?"1":"0";
$page_conf{'landmark_privledge'} = $wd->auth->profile("landmarks")?"1":"0";
$page_conf{'post'} = $wd->auth->profile("post")?"1":"0";
$page_conf{'max_per_query'} = $wd->conf("max sightings per query");
$page_conf{'max_on_map'} = $wd->conf("max sightings on map");
$page_conf{'sighting_distance'} = $wd->conf("sighting_distance");

my $mobile = 0;
if($wd->cgi->user_agent("iphone")){
    $mobile = 1;
}

my $template = new Petal(
			 base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			 file => "index.xhtml",
			 input => "XHTML",
			 output => "XHTML"
);
my @layers;
foreach my $l ( @{$wd->get_layers()} ){
    if($l->{'cgi'}){
        $l->{'url'} = "dynamic:" . $l->{'url'};
    }
    push(@layers, $l);
}

print "Content-Type: text/html\n\n",
  $template->process ( "gmap_url" => "http://maps.googleapis.com/maps/api/js?v=3.6&sensor=false",
		       year_list => $wd->get_year_list(),
		       date_list => \@date_list,
		       month_list => \@month_list,
		       species_list => $wd->get_species_list(),
		       activity_list => $wd->get_activity_list(),
                       user_list => $wd->get_sighting_username_list(),
		       layers => \@layers,
		       conf => \%page_conf,
                       mobile =>  $mobile
		     );
