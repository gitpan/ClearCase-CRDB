package ClearCase::CRDB::Denter;

require ClearCase::CRDB;
require Data::Denter;

@ISA = qw(ClearCase::CRDB);

use strict;

sub store {
    my $self = shift;
    my $file = shift;
    my $d = Data::Denter->new;
    open(DUMP, ">$file") || die "$file: $!\n";
    printf DUMP "# Produced by Perl module %s using %s format.\n",
							    ref $self, ref $d;
    print DUMP "# This is a human-readable text format but not valid Perl\n";
    print DUMP $d->indent($self);
    close(DUMP);
    return $self;
}

sub load {
    my $self = shift;
    my $d = Data::Denter->new;
    for my $db (@_) {
	die "Error: $db: incorrect format" if -e $db && -B $db;
	open(DUMP, $db) || die "$db: $!\n";
	local $/ = undef;
	my $dented = <DUMP>;
	close(DUMP);
	my $hashref = $d->undent($dented);
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

ClearCase::CRDB::Denter - Data::Denter format subclass of ClearCase::CRDB

=head1 SYNOPSIS

Same as base class.

=head1 DESCRIPTION

This subclass of ClearCase::CRDB overrides the
I<ClearCase::CRDB-E<gt>load> and I<ClearCase::CRDB-E<gt>store> methods
to use the Data::Denter format rather than the Data::Dumper format.  I
know of no major advantage to Denter over Dumper in this application,
though that's not to say there aren't any ... I only added this
subclass to (a) test the extensibility of the base class and (b) learn
a bit more about Data::Denter.

=head1 AUTHOR

David Boyce <dsbperl@cleartool.com>

=head1 COPYRIGHT

Copyright (c) 2001 David Boyce. All rights reserved.  This Perl
program is free software; you may redistribute and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

ClearCase::CRDB(3)
