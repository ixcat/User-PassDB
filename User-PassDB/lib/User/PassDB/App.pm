
#
# User::PassDB::App: application class for 'passdb' User::PassDB tool
#
# $Id$
#

package User::PassDB::App;

#
# imports
#

use strict;
use warnings;

use Carp;
use Fcntl;
use Errno qw(:POSIX);
use Getopt::Std;
use YAML;

use User::PassDB;

#
# method predecls
#

sub new;
sub run;

sub _process;

sub _create;
sub _read;
sub _update;

sub __getdb;
sub __build;

sub _parse_opts;
sub _usage_exit;


#
# actual methods
#

sub _process {
	my $self = shift;
	my $opts = $self->{opts};
	my $act;

	($act = $opts->{action}) =~ s:^:_:;
	my $fn = \&$act;

	if ($act =~ m:^_(create|read|update)$:) {
		return &$fn($self);
	}
	else {
		confess "unknown action: $act\n";
		return -1;
	}
	return 0;
}

sub __getdb {
	my $self = shift;
	my $flags = shift;
	my ($dbfile,$dbobj);

	$flags = 0 unless $flags;
	$dbfile = $self->{opts}->{dbfile};

	# print "creating db in " . $self->{opts}->{dbfile} . "\n";

	$dbobj = User::PassDB->new($dbfile, $flags);
	if(!$dbobj) {
		croak "couldn't connect database in $dbfile: $!\n"; 
	}
	$self->{dbobj} = $dbobj;
}

sub __build {
	my $self = shift;
	return $self->{dbobj}->build();
}

sub _create {
	my $self = shift;
	$self->__getdb(O_CREAT|O_EXCL);
	return $self->__build();
}

# XXX: subtle conflicts possible w/r/t duplicate uids in PassDB::build()
sub _update { 
	my $self = shift;
	$self->__getdb();
	return $self->__build();
}

sub _read {
	my $self = shift;
	$self->__getdb();
	my $users = $self->{opts}->{users};

	my $rx = '.*';
	if (scalar @{$users} > 0 ){
		$rx = '(';
		foreach my $u (@{$users}) {
			$rx .= "$u|";
		}
		chop $rx;
		$rx .= ')';
	}

	$self->{dbobj}->eachcb(sub {
		my ($k,$v) = @_;
		print YAML::Dump({ scalar $k => $v}) if $k =~ m:$rx:;
	});

}

sub _parse_opts { # XXX: not threadsafe - ARGV modified

	my $self = shift;
	my $opts = $self->{opts};
	$opts->{action} = '';

	my $OLDV = [ @ARGV ];

	getopts( 'C:R:U:', $self->{opts} ); #  -(C)reate -(R)ead -(U)pdate

	my $crucnt = 0;
	foreach my $opt (('C','R','U')) {
		my $optarg = $opts->{$opt};
		if (defined $optarg) {
			$opts->{'dbfile'} = $optarg;
			$opts->{action} = {
				'C' => 'create',
				'R' => 'read',
				'U' => 'update'
			}->{$opt};
			$crucnt++;
		}
	}

	if($crucnt > 1) {
		print "only 1 of -C -R -U may be specified at a time\n";
		return _usage_exit; 
	}

	if($opts->{action} eq 'read') {
		$opts->{users} = [];
		foreach (@ARGV) {
			push @{$opts->{users}}, $_;
		}
	}

	@ARGV = $OLDV;

}

sub _usage_exit {
	my $app;
	( $app = $0 ) =~ s:.*/::;
	print "usage: $app -C db\n";
	print "       $app -R db [{username|uid} ...]\n";
	print "       $app -U db\n";
	return 0;
}

sub new {
	my $class = shift;
	my $self = {};
	$self->{opts} = {};
	bless $self, $class;
	return $self;
}

sub run {
	my $self = shift;
	return $self->_usage_exit if scalar @ARGV < 2;
	$self->_parse_opts or return 0;
	return $self->_process;
}

1;

