#!/usr/bin/perl -w
use Carp;
use DBI;
use LWP::Simple;
use Date::EzDate;
require '../site-funcs.pl';

#SNOTEL 
my %conf = read_conf();
my $table = 'weather';
my $dbh = DBI->connect("DBI:mysql:$conf{'db'}:$conf{'dbserver'}", 
		       $conf{'dbuser'}, $conf{'dbpassword'}) || 
    (croak 'failed to connect to database');

my $location_name = "West Yellowstone Snotel";
my $location_lat = 44.658333;
my $location_lon = -111.091983;

my $file = shift @ARGV;
open(FILE, $file) || croak "failed to open file:$!";
while(my $line = <FILE>){
    my $data = parse_line($line);
    if($data->{'date'}){
	if(insert_record($dbh, $table, $data)){
	    print "added record\n";
	}else{
	    print "failed to add record\n";
	}
    }
}

sub parse_line {
    #returns a hash of weather data to be inserted into db
    my $line = shift;
    my %data;
    $data{'location_name'} = $location_name;
    $data{'location_lat'} = $location_lat;
    $data{'location_lon'} = $location_lon;
    my ($date, $pill, $prec, $tmax, $tmin, $tavg, $prcp) = split(/\s+/, $line);
    if($date =~ /(\d\d)(\d\d)(\d\d)/){
	if($3 < 20){
	    $data{'date'} = "20$3-$1-$2";
	}else{
	    $data{'date'} = "19$3-$1-$2";
	}
    }else{
	return;
    }
    if(defined($pill)){
	$data{'snow_water_equiv'} = $pill;
    }else{
	croak "no pill data\n";
    }
    $data{'temp_max'} = c2f($tmax) if defined $tmax;
    $data{'temp_min'} = c2f($tmin) if defined $tmin;
    $data{'temp_avg'} = c2f($tavg) if defined $tavg;
    return \%data;
}
sub c2f{
    my $c = shift @_;
    return ($c * (9/5)) + 32;
}
