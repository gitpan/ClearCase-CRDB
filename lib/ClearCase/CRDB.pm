package ClearCase::CRDB;

$VERSION = '0.01';

require 5.6.0;

use File::Spec 0.82;

# For convenience, load up known subclasses. We 'eval' these to ignore
# the error msg if the underlying serialization modules
# Data::Dumper/Storable/etc aren't installed.
eval { require ClearCase::CRDB::Dumper; };
eval { require ClearCase::CRDB::Denter; };
eval { require ClearCase::CRDB::Storable; };

use strict;

use constant MSWIN => $^O =~ /MSWin32|Windows_NT/i;

sub new {
    my $proto = shift;
    my($class, $self);
    if ($class = ref($proto)) {
	# Make a (deep) clone of the original
	require Clone;
	Clone->VERSION(0.11);	# there's a known bug in 0.10
	return Clone::clone($proto);
    }
    $class = $proto;
    $self = {};
    bless $self, $class;
    $self->catcr(@_) if @_;
    return $self;
}

sub crdo {
    my $self = shift;
    push(@{$self->{CRDB_CRDO}}, map {File::Spec::Unix->rel2abs($_)} @_) if @_;
    return @{$self->{CRDB_CRDO}};
}

sub check {
    my $self = shift;
    $self->crdo(@_) if @_;
    my @objects = $self->crdo;
    die "Error: no derived objects specified to check" unless @objects;
    return system(qw(cleartool catcr -check -union), @objects);
}

sub catcr {
    my $self = shift;
    $self->crdo(@_) if @_;
    my($tgt, $state, @notes);
    my($Notes, $Objects, $Vars, $Script) = 1..4;
    open (CR, "cleartool catcr -r @{[$self->crdo]} |") || exit 2;
    for (<CR>) {
	chomp;
	next if /^-{28}/;

	# State machine - set $state according to the CR section.
        if (m%^Target\s+(\S*)\s+built\s%) {
	    $tgt = $1;
	    $state = $Notes;
	    next;
	} elsif (($state == $Notes || $state == $Objects) && m%MVFS objects:%) {
	    @{$self->{CRDB_FILES}->{$tgt}->{CR_DO}->{CR_NOTES}} = @notes;
	    @notes = ();
	    $state = $Objects;
	    next;
	} elsif ($state == $Objects && m%^Variables and Options:%) {
	    $state = $Vars;
	    next;
	} elsif ($state == $Vars && m%^Build Script:%) {
	    $state = $Script;
	    next;
	}

	# Accumulate data from section according to $state.
	if ($state == $Notes) {
	    push(@notes, $_);
	    if (my($base) = m%^Initial working directory was (\S+)%) {
		$self->iwd($base) unless $self->iwd;
		my $full = File::Spec::Unix->rel2abs($tgt, $base);
		if (-e $full) {
		    $tgt = $full;
		} else {
		    $self->{CRDB_FILES}->{$tgt}->{CR_PHONY} = 1;
		}
	    }
	} elsif ($state == $Objects) {
	    my($path, $vers, $date);
	    if (($path, $vers, $date) = m%^([/\\].+)@@(\S+)\s+<(\S+)>$%) {
		for ($path, $vers) { s%\\%/%g };
		$self->{CRDB_FILES}->{$path}->{CR_TYPE} = 'ELEM';
		$self->{CRDB_FILES}->{$path}->{CR_VERS} = $vers;
		$self->{CRDB_FILES}->{$path}->{CR_DATE} = $date;
	    } elsif (($path, $date) = m%^([/\\].+)@@(\S+)$%) {
		$path =~ s%\\%/%g;
		$self->{CRDB_FILES}->{$path}->{CR_TYPE} = 'DO';
		$self->{CRDB_FILES}->{$path}->{CR_DATE} = $date;
	    } elsif (($path, $date) = m%^([/\\].+\S)\s+<(\S+)>$%) {
		$path =~ s%\\%/%g;
		$self->{CRDB_FILES}->{$path}->{CR_TYPE} = 'NON';
		$self->{CRDB_FILES}->{$path}->{CR_DATE} = $date;
	    } else {
		warn "Warning: unrecognized CR line: '$_'";
		next;
	    }
	    next if $path eq $tgt;
	    $self->{CRDB_FILES}->{$tgt}->{CR_DO}->{CR_NEEDS}->{$path} = 1;
	    next if exists $self->{CRDB_FILES}->{$tgt}->{CR_PHONY};
	    $self->{CRDB_FILES}->{$path}->{CR_MAKES}->{$tgt} = 1;
	} elsif ($state == $Vars && (my($var, $val) = m%^(.+?)=(.*)%)) {
	    $self->{CRDB_FILES}->{$tgt}->{CR_DO}->{CR_VARS}->{$var} = $val;
	} elsif ($state == $Script) {
	    push(@{$self->{CRDB_FILES}->{$tgt}->{CR_DO}->{CR_SCRIPT}},
								substr($_, 1));
	} else {
	    warn "Warning: unrecognized CR line: '$_'";
        }
    }
    close (CR);
    return $self;
}

# Internal func to recursively merge two hash refs
sub hash_merge {
    my($to, $from, @source) = @_;
    for (keys %{$from}) {
	if (! $to->{$_}) {
	    $to->{$_} = $from->{$_};
	    next;
	}
	my($ttype, $ftype) = (ref $to->{$_}, ref $from->{$_});
	if ($ttype ne $ftype) {
	    warn "Warning: key type conflict: @source: $_ $ttype/$ftype"
	} elsif (! $ttype) {
	    warn "Warning: @source: $_: can't merge non-references";
	} elsif ($ttype eq 'ARRAY') {
	    push(@{$to->{$_}}, @{$from->{$_}});
	} elsif ($ttype eq 'HASH') {
	    hash_merge($to->{$_}, $from->{$_}, @source);
	} else {
	    warn "Warning: @source: $_: can't merge type: $ttype";
	}
    }
}

sub store {
    my $self = shift;
    my $file = shift;
    my $d = Data::Dumper->new([$self], ['_DO']);
    $d->Indent(1);
    open(DUMP, ">$file") || die "$file: $!\n";
    printf DUMP "# Produced by Perl module %s using %s format.\n",
							    ref $self, ref $d;
    print DUMP "# It is valid Perl syntax and may be read into memory via\n";
    print DUMP "# 'do <file>' or by eval-ing its contents.\n\n";
    print DUMP $d->Dumpxs;
    close(DUMP);
    return $self;
}

sub load {
    my $self = shift;
    for my $db (@_) {
	my $hashref;
	die "Error: $db: incorrect format" if -e $db && -B $db;
	$hashref = do $db;	# eval's $db and returns the obj ref
	if (!defined($hashref)) {
	    warn "Error: $db: " . (-r $db ? $@ : $!);
	    return undef;
	}
	$self->hash_merge($hashref, @{$hashref->{CRDB_CRDO}});
    }
    return $self;
}

sub iwd {
    my $self = shift;
    $self->{CRDB_IWD} = shift if @_;
    return $self->{CRDB_IWD};
}

sub files {
    my $self = shift;
    return keys %{$self->{CRDB_FILES}};
}

sub targets {
    my $self = shift;
    return grep {exists $self->{CRDB_FILES}->{$_}->{CR_DO}}
						    keys %{$self->{CRDB_FILES}};
}

sub vars {
    my $self = shift;
    my $do = shift;
    return keys %{$self->{CRDB_FILES}->{$do}->{CR_DO}->{CR_VARS}};
}

sub val {
    my $self = shift;
    my($do, $var) = @_;
    return undef unless exists $self->{CRDB_FILES}->{$do}->{CR_DO}->{CR_VARS};
    return $self->{CRDB_FILES}->{$do}->{CR_DO}->{CR_VARS}->{$var};
}

sub phony {
    my $self = shift;
    if (@_) {
	return exists $self->{CRDB_FILES}->{$_[0]}->{CR_PHONY};
    } else {
	return grep {exists $self->{CRDB_FILES}->{$_}->{CR_PHONY}}
						    keys %{$self->{CRDB_FILES}};
    }
}

sub macroize {
    my $self = shift;
    my @dos = @_ ? @_ : keys %{$self->{CRDB_FILES}};
    my %used;
    for my $do (@dos) {
	next unless exists $self->{CRDB_FILES}->{$do}->{CR_DO} &&
		    exists $self->{CRDB_FILES}->{$do}->{CR_DO}->{CR_SCRIPT} &&
		    exists $self->{CRDB_FILES}->{$do}->{CR_DO}->{CR_VARS};
	my %macros = %{$self->{CRDB_FILES}->{$do}->{CR_DO}->{CR_VARS}};
	for (@{$self->{CRDB_FILES}->{$do}->{CR_DO}->{CR_SCRIPT}}) {
	    for my $var (keys %macros) {
		next unless $macros{$var};
		if (length($var) == 1) {
		    $used{$var} = $macros{$var} if s%\Q$macros{$var}%\$$var%g;
		} else {
		    $used{$var} = $macros{$var} if s%\Q$macros{$var}%\$($var)%g;
		}
	    }
	}
    }
    return %used;
}

sub notes {
    my $self = shift;
    my $do = shift;
    return undef unless exists $self->{CRDB_FILES}->{$do}->{CR_DO}->{CR_NOTES};
    return @{$self->{CRDB_FILES}->{$do}->{CR_DO}->{CR_NOTES}};
}

sub script {
    my $self = shift;
    my $do = shift;
    return undef
	    if !exists $self->{CRDB_FILES}->{$do}->{CR_DO}->{CR_SCRIPT};
    return @{$self->{CRDB_FILES}->{$do}->{CR_DO}->{CR_SCRIPT}};
}

sub matches_do {
    my $self = shift;
    my @matched;
    for my $re (@_) {
	push(@matched, grep m%$re%, keys %{$self->{CRDB_FILES}});
    }
    return @matched;
}

sub needs_do {
    my $self = shift;
    my @results;
    for my $do (@_) {
	push(@results, keys %{$self->{CRDB_FILES}->{$do}->{CR_DO}->{CR_NEEDS}})
				    if exists $self->{CRDB_FILES}->{$do};
    }
    return @results;
}

sub makes_do {
    my $self = shift;
    my @results;
    for my $do (@_) {
	push(@results, keys %{$self->{CRDB_FILES}->{$do}->{CR_MAKES}})
					if exists $self->{CRDB_FILES}->{$do};
    }
    return @results;
}

1;

__END__

=head1 NAME

ClearCase::CRDB - base class for ClearCase config-record analysis

=head1 SYNOPSIS

    my $crdb = ClearCase::CRDB->new(@ARGV);	# @ARGV is a list of DO's

=head1 DESCRIPTION

A ClearCase::CRDB object represents the recursive I<configuration
record> (aka I<CR>) of a set of I<derived objects> (aka I<DO's>).  It
provides methods for easy extraction of parts of the CR such as the
build script, MVFS files used in the creation of a given DO, make
macros employed, etc. This is the same data available from ClearCase in
raw textual form from "cleartool catcr -recurse DO ..."; it's just
broken down for easier access and analysis.

An example of what can be done with ClearCase::CRDB is the provided
I<whouses> script which, given a particular DO, can show recursively
which files it depends on or which files depend on it.

Since recursively deriving a CR database can be a slow process for
large build systems, and can burden the VOB database, the methods
C<ClearCase::CRDB-E<gt>store> and C<ClearCase::CRDB-E<gt>load> are
provided. These allow the derived CR data to be stored in its processed
form to a persistent storage such as a flat file or database and
re-loaded from there. For example, this data might be derived once per
day as part of a nightly build process and would then be available for
use during the day without causing additional VOB load.

The native C<ClearCase::CRDB-E<gt>store> and
C<ClearCase::CRDB-E<gt>load> methods store to a flat file in
human-readable text format. Different formats may be used by
subclassing these two methods. An example subclass
C<ClearCase::CRDB::Storable> is provided; this uses the Perl module
I<Storable> which is a binary format.

=head2 CONSTRUCTOR

Use C<ClearCase::CRDB-E<gt>new> to construct a CRDB object. Any
parameters given will be taken as the set of derived objects to
analyze.

=head2 INSTANCE METHODS

Following is a brief description of each supported method. Examples
are given for all methods that take parameters; if no example is
given usage may be assumed to look like:

    $obj->method;

=over 4

=item * crdo

Sets or gets the list of derived objects under consideration, e.g.:

    $obj->crdo(qw(do_1, do_2);	# give the object a list of DO's
    my @dos = $obj->crdo;	# gets the list of DO's

This method is invoked automatically by the constructor (see) if
derived objects are specified.

=item * catcr

Invokes I<cleartool catcr -recurse> on the DO set and breaks the
resultant textual data apart into various fields which may then be
accessed by the methods below. This method is invoked automatically by
the constructor (see) if derived objects are specified.

=item * check

Checks the set of derived objects for consistency. For instance, it
checks for multiple versions of the same element, or multiple
references to the same element under different names, in the set of
config records.

=item * store

Writes the processed config record data to the specified file.

=item * load

Reads processed config record data from the specified files.

=item * iwd

Returns the directory marked as "Initial working directory" in the CR.

=item * files

Returns the complete set of files mentioned in the CR.

=item * targets

Returns the subset of files mentioned in the CR which are targets.

=item * vars

Returns the set of make macros used in the build script for the
specified DO, e.g.:

    my @list = $obj->vars("path-to-derived-object");

=item * val

Returns the value of the specified make macro as used in the build script
for the specified DO:

    my $value = $obj->val("path-to-derived-object", "CC");

=item * notes

Returns the set of "build notes" for the specified DO as a list. This
is the section of the CR which looks like:

    Target foo built by ...
    Host "host" running ...
    Reference Time ...
    View was ...
    Initial working directory was ...

E.g.

    my @notes = $obj->notes("path-to-derived-object");

=item * script

Returns the build script for the specified DO:

    my $script = $obj->script("path-to-derived-object");

=back

=head1 AUTHOR

David Boyce <dsb@boyski.com>

=head1 COPYRIGHT

Copyright (c) 2000,2001 David Boyce. All rights reserved.  This Perl
program is free software; you may redistribute and/or modify it under
the same terms as Perl itself.

=head1 STATUS

This is currently ALPHA code and thus I reserve the right to change the
API incompatibly. At some point I'll bump the version suitably and
remove this warning, which will constitute an (almost) ironclad promise
to leave the interface alone.

=head1 PORTING

This module has been at least slightly tested, at various points in its
lifecycle, on almost all CC platforms including Solaris 2.6-8, HP-UX 10
and 11, and Windows NT4 and Win2K SP2 using perl 5.004_04 and 5.6.0.
However, the code does a I<require 5.6.0> since I no longer test with
anything earlier.

=head1 BUGS

Please send bug reports or patches to the address above.

=head1 SEE ALSO

perl(1), ct+config_record(1), clearmake(1) et al
