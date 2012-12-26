#!/usr/bin/perl -w
use lib qw(/home/wildlifedb/perlmods/lib/perl/5.10.0 /home/wildlifedb/perlmods/share/perl/5.10.0);
use CGI::Carp;
use Petal;
require '../WildlifeDB.pm';

my $wd = new WildlifeDB();
my @fields = qw(passwd);
my $table = "auth_user";

if ($wd->auth->loggedIn  && ($wd->auth->profile('landmarks') || $wd->auth->profile('password_change') ) ) {
    my %p = $wd->cgi->Vars;
    my $notification;
    if($p{'action'}){
	if($p{'action'} eq "change"){
            my $input = parse_params(\%p);
            $input->{'userid'} = $wd->auth->profile('userid');
	    $wd->update_record($table, $input, 'userid');
            $notification = "Password Changed";
        }
    }
    my $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			   file => "password.xhtml",
			   input => "XHTML",
			   output => "XHTML"
			  );
    print $wd->cgi->header,
     $template->process(landmarks=>$wd->get_landmarks(),
			     notification => $notification,
			     username => $wd->auth->profile('username')
			    );
}else{
  #not authorized
  my $template = new Petal(
			   base_dir => $wd->conf("base dir") . $wd->conf('template dir'),
			   file => "not_authorized.xhtml",
			   input => "XHTML",
			   output => "XHTML"
			  );
  print $wd->cgi->header,
    $template->process();
}

##############################################
sub parse_params{
#take a hash of args from cgi
#return a hash of data that has been sanitized and had unecesary fields removed
    my %params = %{shift @_};
    my %o;
    foreach my $p (@fields){
	$o{$p} = $params{$p} if $params{$p};
	#carp $p . " : " . $params{$p};
    }
    return \%o;
}
