
#
# User::PassDB - getpwent() databases 
#
# $Id$
#
# Initially:
#
#   - allow building of DB's via local getpwent calls
#     (db: MLDBM/DB_File - double-keyed by 'uid_NN', 'name_USER')
#
# Ideally:
#
#   - use stashed DB if available, otherwise wrap getwpent calls
#     e.g. this can then be used as a portable API to native calls
#     or to 'canned' results of those calls.. 
#
# Note:
#
#   - DB's will contain password hashes when available - 
#     no provision is made for stripping these, setting db permissions, etc.
#     handle with care.
#

package User::PassDB;
$VERSION = 1.00;

#
# imports
#

use Carp;
use strict;
use warnings;

use User::pwent qw(); # we have our own 'getpwent', etc...
use Fcntl;
use Errno qw(:POSIX);

use MLDBM qw(DB_File Storable);

#
# public api:
#

sub new;
sub build; # build/rebuild index

sub eachcb;

# getpwent actually trickier than expected, since I have 
# to 'pause' keep track of iteration (e.g. this is a stream..)
# so.. not done for now..
#
# sub getpwent; 

sub getpwnam;
sub getpwuid;

#
# private api:
#

sub _tie;
sub _untie;
sub _stash;

#
# implementation
#

sub _tie {
	my $self = shift;
	tie %{$self->{dbhash}}, 'MLDBM', $self->{dbpath};
}

sub _untie {
	my $self = shift;
	untie %{$self->{dbhash}};
}

sub _stash {
	my $self = shift;
	my $replace = shift;
	my $u = shift;

	my $dbhash = $self->{dbhash};

	my $name = $u->name;
	my $uid = $u->uid;

	$name = 'name_' . $name;
	$uid = 'uid_' . $uid;

	# really, this is 'give first uid primacy in uid lookup'
	if(!$replace){
		$dbhash->{$uid} = $u unless $dbhash->{$uid};
		$dbhash->{$name} = $u;
	}
	else {
		$dbhash->{$name} = $u;
		$dbhash->{$uid} = $u;
	}
}

sub new { # new ([filname, <flags>])

	my $class = shift;
	my $dbpath = shift;
	my $flags = shift;
	$flags = 0 unless $flags;

	my $self = {};
	$self->{dbpath} = $dbpath;
	$self->{dbhash} = {};

	if(!$dbpath){
                carp "warning: " . $class . "->new(): no file given\n";
                $! = &Errno::ENOENT;
                return undef;
	}
        if (!($flags & O_CREAT) && (! -f $dbpath) ) {
                $! = &Errno::ENOENT;
                return undef;
        }
        if (($flags & O_EXCL) && (-f $dbpath) ) {
                $! = &Errno::EEXIST;
                return undef;
        }

	_tie($self);

	bless $self, $class;
	return $self;
}

sub build {
	my $self = shift;
	my $replace = 0; # hmm: duplicate UID's .. herm
	while( my $u = User::pwent::getpwent() ) {
		$self->_stash($replace, $u);
	}
	return 0;
}

sub eachcb { # call 'cb(k,v)' on 'each' of the dbhash key/value pairs
	my $self = shift;
	my $cb = shift;
	while( my ($k,$v) = each %{$self->{dbhash}} ) {
		$cb->($k,$v);
	}
}

sub getpwnam {
	my $self = shift;
	my $name = shift;
	$name = 'name_' . $name;
	return $self->{dbhash}->{$name};
}

sub getpwuid {
	my $self = shift;
	my $uid = shift;
	$uid = 'uid_' . $uid;
	return $self->{dbhash}->{$uid};
}

1;

