use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		=> 'ClearCase::CRDB',
    'VERSION_FROM'	=> 'lib/ClearCase/CRDB.pm',
    'EXE_FILES'		=> [ 'whouses' ],
    'PREREQ_PM'		=> {
	Data::Dumper	=> 2.101,
	File::Spec	=> 0.82,
    },
    'dist'		=> {
	COMPRESS	=>   'gzip --force --best',
	TAR		=>   'gtar',
	TARFLAGS	=>   '--mode=u+w -cvf',
	PREOP		=>   "pod2html --title='WHOUSES' whouses >README",
	POSTOP	 	=>   'rm -f pod2html-*cache',
    },
);
