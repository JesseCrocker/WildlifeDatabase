package WildlifeDB;
#use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
#Copyright 2011 Jesse Crocker
use strict;
use HTML::Entities;
use CGI;
use DBI;
use CGI::Session;
use CGI::Session::Auth::DBI;
#use DBIx::Admin::TableInfo;
use Date::EzDate;
use CGI::Carp;
use Digest::MD5 qw(md5_hex);
use Cwd;

my $dir = getcwd;
my $conffile = $dir . "/../conf";
my @count_fields;

sub new {
  my $self = {};
  bless($self);
  $self->{conf_file} = read_conf_file();
  $self->{cgi} = new CGI;  
  $self->{dbh} = DBI->connect("DBI:mysql:$self->{'conf_file'}->{'db'}:$self->{'conf_file'}->{'dbserver'}", 
		       $self->{'conf_file'}->{'dbuser'}, $self->{'conf_file'}->{'dbpassword'}) || 
			 (croak 'failed to connect to database');
  #after this it should be ok to read conf from db
  $self->{session} = new CGI::Session(undef, $self->cgi, {Directory=>$self->conf('tempdir')});
  $self->{auth} = new CGI::Session::Auth::DBI({
					       CGI => $self->cgi,
					       Session => $self->{session},
					       DBHandle => $self->dbh
					      });
  $self->auth->authenticate();
  $self->dbh->do("SET time_zone = '" . $self->conf('timezone') . "'");
  return $self;
}

sub dbh {
  my $self = shift;
  return $self->{dbh};
}
sub auth {
  my $self = shift;
  return $self->{auth};
}
sub cgi {
  my $self = shift;
  return $self->{cgi};
}

sub conf_file {
  my $self = shift;
  my $key = shift;
  return $self->{conf_file}->{$key};
}

####   Functions for putting items in db
sub check_dup($$$){
#check if the specified data is already in the db
    my $self =  shift @_;
    my $table = shift @_;
    my %data = %{shift @_};
#    print "checking for duplcate";
    my $s = "SELECT id FROM $table WHERE " . 
	join(" = ? AND ", keys(%data)) . " = ?";
    my $sth = $self->dbh->prepare($s);
    $sth->execute(values(%data));
    return $sth->fetchrow_arrayref;
}
sub check_future($$$){
    #returns 1 if sighting is in future
    my $self = shift;
    my $date = shift @_;
    my $sth = $self->dbh->prepare("SELECT ? > now()");
    $sth->execute($date) || croak "failed to execute sql call" . $self->dbh->errstr;
    my ($ret) = $sth->fetchrow_array;
    return $ret;
}
sub insert_record{
  my $self = shift;
  my $table = shift @_;
  my %data = %{shift @_};
  #insert data into database
  foreach(keys(%data)){
    if(defined($data{$_})){
      $data{$_} = $self->scrub($data{$_});
  
    }else{
      $data{$_} = "";
    }
  }
  if($self->check_dup($table, \%data)){
    print("im sorry, that was already in the database\n");
    return 0;
  }elsif(exists($data{'date'}) && $self->check_future($data{'date'})){
    print("im sorry, your date is in the future\n");
    return 0;
  }else{
    my $sth = $self->dbh->prepare("INSERT INTO $table (" . 
				  join(", ", keys(%data)) . ') VALUES (' . 
				  join(", ", map($self->dbh->quote($_), values(%data))) . ')');
    if($sth->execute){
      my $id = $self->dbh->{'mysql_insertid'};
      $self->update_modify_table($id, $table);
      return $id;
    }else{
      return 0;
    }
  }
}

sub update_record {
  my $self = shift;
  my $table = shift @_;
  my %data = %{shift @_};
  my $id_field = shift @_;
  if(!$id_field){
    $id_field = "id";
  }
  foreach(keys(%data)){
    if(defined($data{$_})){
      $data{$_} =~ $self->scrub($data{$_});
    }else{
      $data{$_} = "";
    }
  }
  my $id = $data{$id_field};
  delete($data{$id_field});
  my $sql = "UPDATE $table set ";
  my $count = 0;
  foreach(keys(%data)){
    $sql .= "," if $count > 0;
    $sql .= " $_=" . $self->dbh->quote($data{$_});
    $count++;
  }
  $sql .= " WHERE $id_field LIKE ?";
  my $sth = $self->dbh->prepare($sql);
  return $sth->execute($id);
}

sub scrub{
  my $self = shift;
  my $val = shift;
  if($val){
    $val =~ s/[^\w\ \.\-\?\/\#\:,]//g;
    $val =~ s/\s+/ /g;
    $val = HTML::Entities::encode($val);
  }
  return $val;
}

sub scrub_sql{
  my $self = shift;
  my $val = shift;
  if($val){
    $val =~ s/[^\w\ \.\-\?\/\#\:,]//g;
  }
  return $val;
}

sub delete_record{
  my $self = shift;
  my $table = shift @_;
  my $id = shift @_;
  my $id_field = shift @_;
  if(!$id_field){
    $id_field = "id";
  }
  my $sth = $self->dbh->prepare("DELETE FROM $table where $id_field=?");
  return $sth->execute($id);
}


sub photo_upload{
  my $self = shift;
  my %out;
  if($self->cgi->param('uploaded_file')){
    $out{'filename'} = md5_hex(localtime, $self->cgi->param('latitude')) . ".jpg";
  }
  my $file = $self->cgi->param('uploaded_file');
  if($self->cgi->uploadInfo($file)->{'Content-Type'} eq 'image/jpeg'){
    my $image = Image::Magick->new;
    my $mes;
    $mes = $image->Read(file=>$file);
    if($mes){
      carp $mes;
      print "Error: could not read image";
      return 0;
    }
    $mes = $image->Mogrify("resize", $self->conf('max image size'));
    if($mes){
      carp $mes;
      print "Error: could not resize image";
      return 0;
    }
    $mes = $image->Write($self->conf('base dir') . $self->conf('image dir') . $out{'filename'});
    if($mes){
      carp $mes;
      print "Error: could not save image";
      return 0;
    }
    $out{'width'} = $image->Get("columns");
    $out{'height'} = $image->Get("rows");
  }else{
    print "Error: All images must be in jpeg format.";
  }
  return \%out;
}


sub mynews{
  my $self = shift;
  my $sql;
  if($self->auth->loggedIn){
    $sql ="SELECT date,html,author FROM news ORDER BY date DESC LIMIT 1";
  }else{
    $sql ="SELECT date,html,author FROM news WHERE public=1 ORDER BY date DESC LIMIT 1";
  }
  my $out = '<div id="news">';
  my $sth = $self->dbh->prepare($sql);
  if($sth->execute){
    while(my @l = $sth->fetchrow_array){
      $out .= $self->cgi->p($l[1]);
    }
  }
  $out .= "</div>";
  return $out;
}

sub user_can_modify{
    #return 1 if user is allowed to modify or delete sighting id
  my $self = shift;
  my $id = shift;
  my $table = shift;
  my $userid =  $self->auth->_session->param('~userid');
  my ($admin, $moderator);
  if($self->auth->loggedIn()){
    if($userid){
      my $sth = $self->dbh->prepare("SELECT admin, moderator FROM auth_user WHERE userid=?");
      $sth->execute($userid) || 
	croak "failed to exec sql statement" . $self->dbh->errstr;
      ($admin, $moderator) = $sth->fetchrow_array();
      $sth->finish;
    }
    if($admin || $moderator){
      return 1;
    }else{
      my $sessionid = $self->auth->_session->id();
      my $sth = $self->dbh->prepare("SELECT sessionid FROM sighting_creator WHERE sightingid=? AND t LIKE ?");
      if($sth->execute($id, $table)){
	my ($res) = $sth->fetchrow_array();
	if($res && $res eq $sessionid){
	  return 1;
	}
      }
    }
  }
  return 0;
}

sub update_modify_table{
  my $self = shift;
  my $id = shift;
  my $table = shift;
  my $sessionid = $self->auth->_session->id();
  my $sth = $self->dbh->prepare("INSERT into sighting_creator (sightingid, sessionid, t) values (?, ?, ?)");
  return $sth->execute($id, $sessionid, $table);
}

#functioms for getting values for forms
sub get_species_list{
  my $self = shift;
  my $sth = $self->dbh->prepare("SELECT DISTINCT species FROM sightings ORDER BY species");
  $sth->execute;
  my @out;
  my $ar = $sth->fetchall_arrayref([0]);
  foreach my $ref(@$ar){
    push(@out, $$ref[0]);
  }
  return \@out;
}

sub get_activity_list{
  my $self = shift;
  my $sth = $self->dbh->prepare("SELECT DISTINCT activity FROM sightings ORDER BY activity");
  $sth->execute;
  my $ar = $sth->fetchall_arrayref([0]);
  my @out;
  foreach my $ref(@$ar){
    push(@out, $$ref[0]);
  }
  return \@out;
}

sub get_sighting_username_list{
  my $self = shift;
  my $sth = $self->dbh->prepare("SELECT DISTINCT username FROM sightings ORDER BY username");
  $sth->execute;
  my $ar = $sth->fetchall_arrayref([0]);
  my @out;
  foreach my $ref(@$ar){
    push(@out, $$ref[0]);
  }
  return \@out;
}

sub get_layers{
  my $self = shift;
  my $sth = $self->dbh->prepare("SELECT * FROM layer ORDER BY name");
  my @layers;
  if($sth->execute()){
    while(my $res = $sth->fetchrow_hashref()){
      push(@layers, $res);
    }
  }
  return \@layers;
}

sub get_users{
  my $self = shift;
  my $sth = $self->dbh->prepare("SELECT * FROM auth_user ORDER BY username");
  my @users;
  if($sth->execute()){
    while(my $res = $sth->fetchrow_hashref()){
      push(@users, $res);
    }
  }
  return \@users;
}

sub get_landmarks{
  my $self = shift;
  my $sth = $self->dbh->prepare("SELECT * FROM landmarks ORDER BY name");
  my @landmarks;
  if($sth->execute()){
    while(my $res = $sth->fetchrow_hashref()){
      push(@landmarks, $res);
    }
  }
  return \@landmarks;
}

sub get_landmark{
#get a single landmark by id
  my $self = shift;
  my $id = shift;
  my $sth = $self->dbh->prepare("SELECT * FROM landmarks WHERE id=?");
  my $res;
  if($sth->execute($id)){
    $res = $sth->fetchrow_hashref();
  }
  return $res;
}

sub get_parcel{
#get a single landmark by id
  my $self = shift;
  my $id = shift;
  my $sth = $self->dbh->prepare("SELECT * FROM parcels WHERE ParcelID=?");
  my $res;
  if($sth->execute($id)){
    $res = $sth->fetchrow_hashref();
  }
  return $res;
}

sub count_fields{
#gets a list of count fields from the db, and caches the data
  my $self = shift;
  #my @base_cols = qw(name id species date date_end activity notes username latitude longitude latitude_end longitude_end image image_height image_width);
  unless(@count_fields){
    my $field_string = $self->conf("count_fields");
    @count_fields = split(/,/, $field_string);
  #  my($dbadmin) = DBIx::Admin::TableInfo->new(dbh => $self->dbh);
  #  my @cols = @{$dbadmin->columns("sightings", 1)};
  #  foreach my $col(@cols){
  #    push(@count_fields, $col) unless grep(/^$col$/, @base_cols);
  #  }
  }
  return \@count_fields;
}

sub get_year_list{
  my $self = shift;
  my $fy = $self->conf("first year");
  my $mydate = Date::EzDate->new();
  my $ey = $mydate->{'year'};
  my @out;
  for(;$fy <= $ey; $fy++){
    push(@out, $fy);
  }
  return \@out;
}

#stats
sub get_report{
    my ($self, $field, $start_date, $interval, $name, $sort ) = @_;
    my %r;
    my $data = $self->get_report_data($field, $start_date , $interval);
    if($sort){
        my @d = sort { $b->{'count'} <=> $a->{'count'} } @{$data};
        my $total = shift @d;
        push(@d, $total);
        $data = \@d;
    }
    $r{'data'} = $data;
    $r{'name'} = $name;
    return \%r;
}
sub get_report_data{
    my ($self, $field, $start_date, $interval ) = @_;
    my $sql = "select count($field),$field from sightings WHERE date between '$start_date' and DATE_ADD('$start_date', INTERVAL $interval) group by $field";
    #carp $sql;
    my $sth = $self->dbh->prepare($sql) 
	|| carp "failed to prepare sql statement: " . $self->dbh->errstr;
    my @out;
    my $count = 0;
    if($sth->execute()){	
	while(my $r = $sth->fetchrow_hashref){
            $r->{"count"} = $r->{"count($field)"};
            $count += $r->{"count"};
            push(@out, $r);
        }
        if($count > 0){
            my %total;
            $total{$field} = "Total";
            $total{'count'} = $count;
            push(@out, \%total);
        }
    }else{
        carp "failed to execute sql: $sql";
    }
    return \@out;
}

#config funcs
sub read_conf_file{
  my $self = shift;
  open(CF, $conffile) || die "can't open conf $conffile: $!";
  my $line;
  my %conf;
  while($line = <CF>){
    chomp $line;
    my @vals = split(/,\s+/, $line);
    my $key = shift @vals;
    if($#vals == 0){
      $conf{$key} = shift(@vals);
    }else{
      $conf{$key} = \@vals;
    }
  }
  close(CF);
  return \%conf;
}

sub conf{
  my $self = shift;
  my $key = shift;
  my $val = shift;
  if($key && $val){
    my $sth = $self->dbh->prepare("DELETE from config where name like ?");
    $sth->execute($key);
    $sth = $self->dbh->prepare("INSERT into config (name, value) values (?, ?)");
    $sth->execute($key, $val);
  }
  my $sth = $self->dbh->prepare("SELECT value from config where name like ?");
  $sth->execute($key);
  my $ar = $sth->fetchrow_arrayref();
  return $ar->[0];
}

1;
