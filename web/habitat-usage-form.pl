#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
use CGI::Carp qw(fatalsToBrowser);
use Petal;
use Image::Magick;
use Digest::MD5 qw( md5_hex );
require '../WildlifeDB.pm';
use strict;

my $wd = new WildlifeDB();

my $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			   file => "habitat-usage-form.xhtml",
			   input => "XHTML",
			   output => "XHTML"
			  );
 
print $wd->cgi->header,
    $template->process(activity_list=>$wd->get_activity_list(),
		       species_list => $wd->get_species_list(),
		       landmark_list=>$wd->get_landmarks()
		      );
