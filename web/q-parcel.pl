#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
use strict;
use CGI::Carp qw(fatalsToBrowser);
use DBI;
use Petal;
use Petal::Utils qw(:hash);
use CGI;
#use Data::Dumper;
use IO::Compress::Zip qw(zip $ZipError) ;
require '../WildlifeDB.pm';

my $wd = new WildlifeDB();

my $zip = 0;#zip is broken

my $sw = scrub_number($wd->cgi->param('sw_corner'));
my $ne = scrub_number($wd->cgi->param('ne_corner'));
my $min_lat = scrub_number($wd->cgi->param('min_lat'));
my $max_lat = scrub_number($wd->cgi->param('max_lat'));
my $min_lon = scrub_number($wd->cgi->param('min_lon'));
my $max_lon = scrub_number($wd->cgi->param('max_lon'));
my $limit = scrub_number($wd->cgi->param('limit') || 1000);
my $template_file = scrub($wd->cgi->param('template'));
my $output_format = scrub($wd->cgi->param('format') || "kml");
my $owner_code = scrub_number($wd->cgi->param('owner_code'));

my $bbox;

if($sw && $ne){
    my ($s_lat, $w_lon) = split(/,/, $sw);
    my ($n_lat, $e_lon) = split(/,/, $ne);
    $bbox = "$n_lat $w_lon, $n_lat $e_lon, $s_lat $e_lon, $s_lat $w_lon, $n_lat $w_lon";
}elsif($min_lat && $min_lon && $max_lat && $max_lon){
    $bbox = "$min_lat $min_lon, $min_lat $max_lon, $max_lat $max_lon, $max_lat $min_lon, $min_lat $min_lon";
}

my $sql = "SELECT *,AsText(ExteriorRing(poly)),AsText(Centroid(poly)) FROM parcels";
if($bbox){
    $sql .= " where Intersects(poly, GeomFromText('POLYGON(($bbox))'))";
}
if($owner_code){
    if($bbox){
        $sql .= " AND"
    }else{
        $sql .= " WHERE"
    }
    $sql .= "  owner_code like " . $wd->dbh->quote($owner_code);
}
if($limit){
    $sql .= " LIMIT $limit";
}
#carp $sql;
my $sth = $wd->dbh->prepare($sql);
$sth->execute;

my @results;
while(my $res = $sth->fetchrow_hashref()){
    #decode polygon
    my %out;
    delete($res->{'poly'});
    my $linestring = $res->{'AsText(ExteriorRing(poly))'};
    delete($res->{'AsText(ExteriorRing(poly))'});
    
    my @coords;
    if($linestring =~ /LINESTRING\((.*)\)/){
        my @raw_coords = split(/,/, $1);
        foreach my $c(@raw_coords){
            my ($lat, $lon) = split(/\s/, $c);
            push(@coords, "$lon,$lat");
        }
    }
    $out{'coord_string'} = join(" ", @coords);
    
    my $centerString = $res->{'AsText(Centroid(poly))'};
    delete($res->{'AsText(Centroid(poly))'});
    if($centerString =~ /([\d\-\.]+) ([\d\-\.]+)/){
	$out{'center'} = "$1,$2";
    }
    $out{'data'} = $res;
    push(@results, \%out);
}

#print Dumper(@results);

my $mimetype;

if($output_format eq "wildlifedb"){
    $template_file = "template.xml";
    $mimetype = "text/xml";
}elsif($output_format eq "kml"){
    if($template_file){
	$template_file .= ".kml";
    }else{
        $template_file = "template.kml";
    }
    $mimetype = "application/vnd.google-earth.kml+xml\nContent-Disposition: attachment; filename=\"parcels.kml\"";
    if($zip){
	$mimetype = "application/vnd.google-earth.kmz\nContent-Disposition: attachment; filename=\"parcels.kmz\"";
    }else{
        $mimetype = "application/vnd.google-earth.kml+xml\nContent-Disposition: attachment; filename=\"parcels.kml\"";
    }
}else{
  $template_file = "qs-error.xml";
  $mimetype = "text/xml";
}

my $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir') . "/parcel",
			   file => $template_file,
			   input => "XML",
			   output => "XML"
			  );

print  "Content-Type: $mimetype\n\n";
if($zip){
    my $z = new IO::Compress::Zip "-",
        or croak "zip failed: $ZipError\n";
    $z->print($template->process(parcels => \@results));
}else{
    print $template->process(parcels => \@results);
}

######################
sub scrub{
  my $val = shift;
  if($val){
    $val =~ s/[^\w\ \.\-\?\/\#\:,]//g;
  }
  return $val;
}
sub scrub_number{
    my $val = shift;
    if($val){
      $val =~ s/[^\d\.,\-]//g;
    }
    return $val;
}
