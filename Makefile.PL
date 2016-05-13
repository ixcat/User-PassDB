
# User::PassDB Makefile.PL
# $Id$

use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => 'User::PassDB',
	VERSION_FROM => 'lib/User/PassDB.pm',
	EXE_FILES => [
		"bin/passdb",
		"bin/passdb2sql"
	],
	PREREQ_PM => {
		'MLDBM' => 0, # tested against 2.05
		'YAML' => 0, # tested against 0.84
	}
);

