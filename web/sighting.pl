#!/usr/bin/perl -w
#copyright 2011 Jesse Crocker
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
use CGI::Carp qw(fatalsToBrowser);
use Image::Magick;
use Digest::MD5 qw( md5_hex );
require '../WildlifeDB.pm';

use strict;

my $table = "sightings";

my $wd = new WildlifeDB();

my @fields = qw(latitude longitude latitude_end longitude_end species username date date_end activity image notes id);
push(@fields, @{$wd->count_fields()});

my %formdefaults;
set_form_defaults();

my %inputdata;
if ($wd->auth->loggedIn) {
  if($wd->auth->profile('post')){
    my $onload = "parent.set_logged_in(); parent.clear_click_markers(); parent.set_can_report_sightings();set_update_markers()";
    if($wd->auth->profile("admin")){
      $onload .= ";parent.set_admin()";
    }elsif($wd->auth->profile("landmarks")){
       $onload .= ";parent.set_landmark_privledge()";
    }
    if($wd->auth->profile("password_change") || $wd->auth->profile("admin")){
      $onload .= ";parent.set_password()";
    }
    print $wd->cgi->header(),
      $wd->cgi->start_html(-title=>'add wildlife sighting',
			   -style=>{'src'=>'css/input.css'},
			   -script=>{'src'=> 'js/sighting.js', language=>"javascript"},
			   -onload=>$onload);
    my %p = $wd->cgi->Vars;
    $wd->cgi->delete("action");
    print "<div id='notification'>";
    if($p{'action'}){
      %inputdata = %{parse_params(\%p)};
      if($p{'action'} eq "update" && $p{'id'} && $wd->user_can_modify($p{'id'}, $table)){
	if(set_defaults_from_id($p{'id'})){
	  print "Update sighting";
	  $wd->cgi->delete_all();
	  print "</div>", myform("updatecommit");
	}else{
	  print "Error: That sighting does not exist.";
	  $wd->cgi->delete_all();
	  print "</div>", myform("new");   
	}
      }elsif($p{'action'} eq "updatecommit" && $p{'id'} && $wd->user_can_modify($p{'id'}, $table)){
	my $notification = "";
	unless($inputdata{'latitude'} && $inputdata{'longitude'}){
	  $notification = 'You must choose a location';
	}elsif(! $inputdata{'species'}){
	  $notification =  'You must choose a species';
	}elsif(! ($inputdata{'date'}) ){
	  $notification =  'You must choose a date';
	}elsif(! $inputdata{'username'}){
	  $notification =  'You must enter your name';
	}else{
	  if($wd->cgi->param('uploaded_file')){
	    if(my $f = $wd->photo_upload()){
	      $inputdata{'image'} = $f->{'filename'};
	      $inputdata{'image_height'} = $f->{'height'};
	      $inputdata{'image_width'} = $f->{'width'};
	      $notification .= "<br />" if $notification;
	      $notification .= "Image added, ";
	    }
	  }
	  if($wd->update_record($table, \%inputdata)){
	    $notification .= "<br />" if $notification;
	    $notification .=  "Sighting updated.";
	    print $notification ;
	    $wd->cgi->delete_all();
	    print "</div>", myform("new");
	  }else{
	    $notification .= 'Error: Could not update sighting.';
	    print $notification;
	    print "</div>", myform("updatecommit");
	  }
	}
      }elsif($p{'action'} eq "new"){
	my $notification;
	unless($inputdata{'latitude'} && $inputdata{'longitude'}){
	  $notification = 'You must choose a location';
	}elsif(! $inputdata{'species'}){
	  $notification = 'You must choose a species';
	}elsif(! ($inputdata{'date'}) ){
	  $notification = 'You must  choose a date';
	}elsif(! $inputdata{'username'}){
	  $notification = 'You must enter your name';
	}else{
	  if($wd->cgi->param('uploaded_file')){
	    if(my $f = $wd->photo_upload()){
	      $inputdata{'image'} = $f->{'filename'};
	      $inputdata{'image_height'} = $f->{'height'};
	      $inputdata{'image_width'} = $f->{'width'};
	      $notification .= "<br />" if $notification;
	      $notification .= "Image added, ";
	    }
	  }
	  if($wd->insert_record("sightings", \%inputdata)){
	    $notification .= "<br />" if $notification;
	    $notification .= "Sighting added.";
	    $wd->cgi->delete_all();
	  }else{
	    $notification .= "<br />" if $notification;
	    $notification .= "Error: Could not add sighting.";
	  }
	}
	print $notification;
	print "</div>", myform("new");
      }elsif($p{'action'} eq "delete" && $p{'id'}){
	if($wd->user_can_modify($p{'id'}, $table)){
	  $wd->delete_record($table, $p{'id'});
	  print "Sighting deleted.";
	}else{
	  print "Error: you are not allowed to delete that sighting.";
	}
	print "</div>", myform("new");
      }else{
	print "</div>", myform("new");
      }
    }else{
      #no action specified
      print "</div>", myform("new");
    }
  }else{
  #not allowed to post
  print $wd->cgi->header(),
    $wd->cgi->start_html(-title=>'add wildlife sighting',
			 -style=>{'src'=>'css/input.css'},
			 -onload=>"parent.set_logged_in();set_no_report_sightings();parent.closeFrame()"); 
}
}else{
  #not logged in
  print $wd->cgi->header(),
    $wd->cgi->start_html(-title=>'add wildlife sighting',
			 -style=>{'src'=>'css/input.css'},
			 -onload=>"parent.set_logged_out();parent.closeFrame()"); 
}

print "    <div id='close'><a href='javascript:parent.closeFrame()'>X</a></div>
", $wd->cgi->end_html;
##############################################
sub parse_params{
#take a hash of args from cgi
#return a hash of data that has been sanitized and had unecesary fields removed
#also, convert date and minutes and seconds to datetime format
  my %params = %{shift @_};
  my %o;
  foreach my $p (@fields){
    $o{$p} = $params{$p} if $params{$p};
  }
  if($params{'day'} && $params{'month'} && $params{'year'}){
    my $month = $params{'month'};
    my $day = $params{'day'};
    my $hour = $params{'hour'};
    my $minute = $params{'minute'};
    my $hour_end = $params{'hour_end'};
    my $minute_end = $params{'minute_end'};
    if($month =~ /^\d$/){
      $month = "0$month";
    }
    if($day =~ /^\d$/){
      $day = "0$day";
    }
    if(defined($hour) && $hour =~ /^\d$/){
      $hour = "0$hour";
    }
    if(defined($minute) && $minute =~ /^\d$/){
      $minute = "0$minute";
    }
    if(defined($hour_end) && $hour_end =~ /^\d$/){
      $hour_end = "0$hour_end";
    }
    if(defined($minute_end) && $minute_end =~ /^\d$/){
      $minute_end = "0$minute_end";
    }
    $o{'date'} =  "$params{'year'}-$month-$day";
    if($hour && $params{'minute'}){
      $o{'date'} .= " $hour:$minute";
    }else{
      print "Warning: You did not enter a time.  If you meant to enter the time, you need to edit the sighting. See the help page for more info.<br />";
    }
    if($wd->conf("time warning") && $params{'hour'} && $params{'hour'} < $wd->conf("time warning")){
      print "Warning: The hour of your sighting was very early, did you forget about 24 hour time?<br />"
    }
    if($o{'latitude_end'} && $o{'longitude_end'} && defined($hour_end) && defined($minute_end)){
      $o{'date_end'} =  "$params{'year'}-$month-$day $hour_end:$minute_end";     
    }
  }else{
  } 
  return \%o;
}

sub myform{
    my $action = shift @_;
    my %labels = ('01'=>"Jan",
		  '02'=>"Feb",
		  '03'=>"Mar",
		  '04'=>"Apr",
		  '05'=>"May",
		  '06'=>"Jun",
		  '07'=>"Jul",
		  '08'=>"Aug",
		  '09'=>"Sep",
		  '10'=>"Oct",
		  '11'=>"Nov",
		  '12'=>"Dec");

    my $button_text = ($action eq "updatecommit")?"Update Sighting":"Add Sighting";
    my $out =  "<div id='form'>" .
	$wd->cgi->start_multipart_form(-action=>"sighting.pl",
				 -id=>"inputform",
				 -name=>'inputform') .
				 $wd->cgi->hidden(-name=>"action", -value=>$action);
    if($formdefaults{'id'}){
      $out .= $wd->cgi->hidden(-name=>"id", -value=>$formdefaults{'id'});
    }
    
    $out .= "<span class='required'>Name</span>: " .
	$wd->cgi->textfield(-name=>"username",
		      -value=>$formdefaults{'username'},
		      -size=>15,
		      -maxlength=>100,
			   -tabindex=>1) .

	"<span class='required'>Date</span>: " .
	$wd->cgi->popup_menu({-name=>"month", 
			-values=>['01','02','03','04','05','06','07','08','09','10','11','12'],
			-labels=>\%labels,
			-default=>$formdefaults{'month'},
			      -tabindex=>2
			})
	. "/" . 
	$wd->cgi->popup_menu({-name=>"day", 
			-value=>[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31],
			-default=>$formdefaults{'day'},
			     -tabindex=>3})
	. "/" .
	$wd->cgi->popup_menu({-name=>"year", 
			-values=>$wd->get_year_list(),
			-default=>$formdefaults{'year'},
			     -tabindex=>4}) .
	$wd->cgi->br .
	$wd->cgi->img({-src=>$wd->conf('icon uri') . "/mm_20_green.png"}) .
	" <span class='required'>Starting Location</span>:" .
	$wd->cgi->textfield(-name=>'latitude',
			    -value=>$formdefaults{'latitude'},
			    -size=>11,
			    -maxlength=>11) .
		      "," .
      $wd->cgi->textfield(-name=>'longitude',
		    -value=>$formdefaults{'longitude'},
		    -size=>11,
		    -maxlength=>11) .
    '<a href="javascript:clear_start_marker()" ><img src="images/x.png" /></a>  <span class="required">Time</span>: ' . 
    $wd->cgi->textfield({-name=>'hour', 
			 -size=>2,
			 -maxlength=>2,
			 -onKeyUp=>"check_length(this)",
			 -default=>$formdefaults{'hour'},
			-tabindex=>5})  . ":" . 
       $wd->cgi->textfield({-name=>'minute', 
		      -size=>2,
		      -default=>$formdefaults{'minute'},
		      -maxlength=>2,
		      -onKeyUp=>"check_length(this)",
		      -tabindex=>6}) . "(24 hr)" . $wd->cgi->br .
	$wd->cgi->img({-src=>$wd->conf('icon uri') . "/mm_20_red.png"}) .
	" Ending Location(optional):" .
	$wd->cgi->textfield(-name=>'latitude_end',
		      -value=>$formdefaults{'latitude_end'},
		      -size=>11,
		      -maxlength=>11) . "," .
	$wd->cgi->textfield(-name=>'longitude_end',
		      -value=>$formdefaults{'longitude_end'},
		      -size=>11,
		      -maxlength=>11) .
	
       	 '<a href="javascript:clear_end_marker()" ><img src="images/x.png" /></a> Time: ' .
	 $wd->cgi->textfield({-name=>'hour_end',
			      -size=>2,
			      -maxlength=>2,
			      -onKeyUp=>"check_length(this)",
			      -default=>$formdefaults{'hour_end'},
			      -tabindex=>7})  . ":" . 
	$wd->cgi->textfield({-name=>'minute_end', 
			     -size=>2,
			     -maxlength=>2,
			     -onKeyUp=>"check_length(this)",
			     -default=>$formdefaults{'minute_end'},
			     -tabindex=>8}) .
	"(24 hr)" . $wd->cgi->br .
	"<span class='required'>Species</span>: " . "<span id='species_span'>" . 
	$wd->cgi->popup_menu(-name=>'species',
			     -id=>'species',
			     -values=>$wd->get_species_list(),
			     -onchange=>"check_species_other()",
			     -default=>$formdefaults{'species'},
			     -tabindex=>9
		       ) . "</span>" .
			   " Activity: " . "<span id='activity_span'>" .
    $wd->cgi->popup_menu(-name=>"activity",
			 -id=>'activity',
			 -values=>$wd->get_activity_list(),
			 -onchange=>"check_activity_other()",
			 -default=>$formdefaults{'activity'},
			 -tabindex=>10
		   ) . "</span>" .
    $wd->cgi->br;
    my $tabindex = 10;
    foreach my $c(@{$wd->count_fields()}){
	my $label = "";
	if($c =~ /^(\w)(\w+)$/){
	    $label = uc($1) . $2;
	}
	$out .= "$label:" .
	    $wd->cgi->textfield(-name=>$c, 
				-size=>3, 
				-maxlength=>4,
				-value=>$formdefaults{$c},
				-onchange=>"update_total()",
				-class=>"count_field",
				-tabindex=>$tabindex++);
    }
    $out .= "Total:" .
	    $wd->cgi->textfield(-name=>"total", 
				-size=>3, 
				-maxlength=>4,
				-value=>"",
				-readonly=>"readonly");
    $out .= $wd->cgi->br .
    "Notes:" . 
    $wd->cgi->textfield(-size=>60,
			-name=>"notes",
			-value=>$formdefaults{'notes'},
			-tabindex=>$tabindex++) .
   		  $wd->cgi->br .
		  "Photo:" .
		  $wd->cgi->filefield(-name=>'uploaded_file',
				-default=>'',
				-size=>50,
				-maxlength=>80) .
		       $wd->cgi->br .
		       "<input type=\"submit\" name=\"$button_text\" value=\"$button_text\" tabindex=\"$tabindex++\" />" .
		        '<input type="reset" onclick="clear_start_marker();clear_end_marker()" name=".reset" />' . 
		       $wd->cgi->end_form . "<span class='required'>required field</span></div>";
    return $out;
}


sub set_form_defaults {
    my($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst) = localtime;
    $mon++;
    if($wd->cgi->param('month')){
      $formdefaults{'month'} = $wd->cgi->param('month');
    }elsif($mon =~ /^\d$/){
	$formdefaults{'month'} = "0$mon";
    }else{
	$formdefaults{'month'} = $mon;	
    }  

    $formdefaults{'year'} = $wd->cgi->param('year') || $year + 1900;
    $formdefaults{'day'} = $wd->cgi->param('day') || $day;
    $formdefaults{'hour'} = "";
    $formdefaults{'minute'} = "";
    $formdefaults{'username'} = $wd->cgi->param('username') || "";
    $formdefaults{'latitude'} = "";
    $formdefaults{'longitude'} = "";
    $formdefaults{'species'} = $wd->conf('default species');
    $formdefaults{'activity'} = "";
    foreach my $c(@{$wd->count_fields()}){    
	$formdefaults{$c} = "";
    }
    $formdefaults{'notes'} = "";
    $formdefaults{'name'} = "";
}
sub set_defaults_from_id{
    my $id = shift @_;
    my $sth = $wd->dbh->prepare("SELECT * FROM sightings WHERE id=?");
    if($sth->execute($id)){
	my %data = %{$sth->fetchrow_hashref()};
	if($data{'id'}){
	    foreach(keys(%data)){
		if($_ eq "date"){
		    if($data{'date'} =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d)/){
			$formdefaults{'year'} = $1;
			$formdefaults{'month'} = $2;
			$formdefaults{'day'} = $3;
			$formdefaults{'hour'} = $4;
			$formdefaults{'minute'} = $5;
			if($3 =~ /^0(\d)/){
			    $formdefaults{'day'} = $1;
			}
		    }
		}elsif($_ eq "date_end"){
		    if($data{'date_end'} =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/){
			$formdefaults{'hour_end'} = $4;
			$formdefaults{'minute_end'} = $5;
		    }
		}else{
		    $formdefaults{$_} = $data{$_};
		}
	    }
	    return 1;
	}else{
	    return 0;
	}
    }else{
	print "failed to retrive sighting from db: $wd->dbh->errstr";
	return 0;
    }
}
