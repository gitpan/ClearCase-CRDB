package ClearCase::CRDB::Storable;

require ClearCase::CRDB;
require Storable;

@ISA = qw(ClearCase::CRDB);

use strict;

sub store {
    my $self = shift;
    my $file = shift;
    Storable::store($self, $file);
    return $self;
}

sub load {
    my $self = shift;
    for my $db (@_) {
	my $hashref;
	die "Error: $db: incorrect format" if -e $db && ! -B $db;
	# Binary: must have been created by Storable::store
	$hashref = Storable::retrieve($db);
	if (!defined($hashref)) {
	    warn "Error: $db: " . (-r $db ? $@ : $!);
	    return undef;
	}
	$self->hash_merge($hashref, @{$hashref->{CRDB_CRDO}});
    }
    return $self;
}

1;

__END__
=head1 NAME

ClearCase::CRDB::Storable - binary-format subclass of ClearCase::CRDB

=head1 SYNOPSIS

Same as base class.

=head1 DESCRIPTION

This subclass of ClearCase::CRDB overrides the
I<ClearCase::CRDB-E<gt>load> and I<ClearCase::CRDB-E<gt>store> methods
to use the Storable format rather than the Data::Dumper format.
Storable is believed to be faster, both to write and read, but the
storage format is binary and thus not (easily) human readable.

=head1 AUTHOR

David Boyce <dsb@boyski.com>

=head1 COPYRIGHT

Copyright (c) 2001 David Boyce. All rights reserved.  This Perl
program is free software; you may redistribute and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

ClearCase::CRDB(3)
