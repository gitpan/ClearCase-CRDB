package ClearCase::CRDB::Dumper;

require ClearCase::CRDB;
require Data::Dumper;

@ISA = qw(ClearCase::CRDB);

use strict;

1;

__END__

=head1 NAME

ClearCase::CRDB::Dumper - text-format subclass of ClearCase::CRDB

=head1 SYNOPSIS

=head1 DESCRIPTION

This is an empty subclass of ClearCase::CRDB provided for consistency.
The native storage format of ClearCase::CRDB is that of Data::Dumper,
so ClearCase::CRDB::Dumper need not override the -E<gt>load and
-E<gt>store methods. However, other storage formats have their own
subclasses (cf ClearCase::CRDB::Storable) so ClearCase::CRDB::Dumper is
provided too. It has the same semantics as its base class.

=head1 AUTHOR

David Boyce <dsb@boyski.com>

=head1 COPYRIGHT

Copyright (c) 2001 David Boyce. All rights reserved.  This Perl
program is free software; you may redistribute and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

ClearCase::CRDB(3)
