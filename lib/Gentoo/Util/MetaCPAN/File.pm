use 5.006;
use strict;
use warnings;

package Gentoo::Util::MetaCPAN::File;

our $VERSION = '0.001000'; # TRIAL

# ABSTRACT: Enhancements to MetaCPAN::File

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moo qw( extends has around );
use Scalar::Util qw( blessed );
extends 'MetaCPAN::Client::File';

has latest => ( is => ro =>, lazy => 1, default => sub { $_[0]->data->{latest} } );

around _known_fields => sub {
  my ( $orig, $self, @args ) = @_;
  return [ ( 'latest', @{ $self->$orig(@args) } ) ];
};

no Moo;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Gentoo::Util::MetaCPAN::File - Enhancements to MetaCPAN::File

=head1 VERSION

version 0.001000

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
