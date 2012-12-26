#!/usr/bin/perl -w
use Carp;
use DBI;
use LWP::Simple;
use Date::EzDate;
require '../site-funcs.pl';


my %conf = read_conf();
my $table = 'weather';
my $dbh = DBI->connect("DBI:mysql:$conf{'db'}:$conf{'dbserver'}", 
		       $conf{'dbuser'}, $conf{'dbpassword'}) || 
    (croak 'failed to connect to database');

my $location_name = "West Yellowstone Airport";
my $location_lat = 44.68739;
my $location_lon = -111.114435;
my $startdate = shift @ARGV;
my $date = Date::EzDate->new($startdate?$startdate:"yesterday");
my $now = Date::EzDate->new();

while($date <= $now){
    do_date($date->{'year'}, $date->{'month number base 1'}, $date->{'day of month'});
    $date->{'epochday'}++;
}

sub do_date{
    my $year = shift;
    my $month = shift;
    my $day = shift;
    print ("doing date $year-$month-$day\n");
    do_url("http://www.weatherunderground.com/history/airport/KWEY/$year/$month/$day/DailyHistory.html?format=1", "$year-$month-$day");
}

sub do_url{
    my $url = shift;
    my $date = shift;
    my $content = get($url);
    unless($content){
	carp "failed to retrieve url: $url";
	return;
    }
#    print $content;
    foreach(split(/<BR>/, $content)){
	my $data = parse_line($_, $date);
	if($data->{'date'}){
	    if(insert_record($dbh, $table, $data)){
		print "added record\n";
	    }else{
		print "failed to add record\n";
	    }
	}
    }   
}

sub parse_line {
    #returns a hash of weather data to be inserted into db
    my $line = shift;
    my $date = shift;
    my %data;
    my @vals = split(/,/, $line);
    $data{'location_name'} = $location_name;
    $data{'location_lat'} = $location_lat;
    $data{'location_lon'} = $location_lon;
    unless($vals[0]){
	croak "failed to split string: $line\n";
    }
    unless($#vals == 11){
	print "not the the right number of tokens from split\n";
	return 0;
    }
    if($vals[0] =~ /TimeMST/){
	return 0;
    }
    if($vals[0] =~ /(\d+):(\d\d) (\w\w)/){
	my $hour = $1;
	if($3 eq "PM"){
	    $hour += 12;
	}
	$data{'date'} = "$date $hour:$2";
    }else{
	print "failed to parse time: $vals[0]\n";
	return 0;
    }
    $data{'temp'} = $vals[1];
    $data{'humidity'} = $vals[3];
    $data{'pressure'} = $vals[4];
    $data{'wind_direction'} = $vals[6];
    if($vals[7] && $vals[7] ne "Calm"){
	$data{'wind_speed'} = $vals[7];
    }
    if($vals[8] && $vals[8] ne "-"){
	$data{'wind_gust'} = $vals[8];
    }
    if($vals[9] && $vals[9] ne "N/A"){
	$data{'precip'} = $vals[9];
    }
    $data{'conditions'} = $vals[11];
    return \%data;
}
