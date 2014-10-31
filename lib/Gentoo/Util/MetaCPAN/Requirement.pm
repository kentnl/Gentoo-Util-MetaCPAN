use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package Gentoo::Util::MetaCPAN::Requirement;

# ABSTRACT: A Single dependency requirement speciailised for Gentoo

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moo qw( has );
use Gentoo::PerlMod::Version qw( gentooize_version );

has 'module'         => ( is => ro =>, required => 1, );
has 'range'          => ( is => ro =>, required => 1, );
has 'version'        => ( is => ro =>, lazy     => 1, builder => '_build_version' );
has 'gentoo_version' => ( is => ro =>, lazy     => 1, builder => '_build_gentoo_version' );

sub BUILD { $_[0]->gentoo_version }

sub _has_min_version {
  return !( $_[0]->range->_accepts(0) );
}
sub _build_version { return $_[0]->range->as_string }

sub _build_gentoo_version {
  my ($self) = @_;
  my $ver;
  eval { $ver = gentooize_version( $self->version, { lax => 1 } ); };
  return $ver;
}

sub _pretty {
  if ( $_[0]->range->isa('CPAN::Meta::Requirements::_Range::Exact') ) {
    return sprintf '= %s @ %s', $_[0]->module, eval { gentooize_version( $_[0]->range->{version}, { lax => 1 } ) } || '?';
  }
  my @out;
  if ( exists $_[0]->range->{minimum} ) {
    if ( $_[0]->range->{minimum} != 0 ) {
      push @out, sprintf '>= %s @ %s', $_[0]->module, eval { gentooize_version( $_[0]->range->{minimum}, { lax => 1 } ) } || '?';
    }
    else {
      push @out, sprintf '%s', $_[0]->module;
    }
  }
  if ( exists $_[0]->range->{maximum} ) {
    push @out, sprintf '<= %s @ %s', $_[0]->module, eval { gentooize_version( $_[0]->range->{maximum}, { lax => 1 } ) } || '?';
  }
  if ( exists $_[0]->range->{exclusions} ) {
    for my $exclusion ( @{ $_[0]->range->{exclusions} } ) {
      push @out, sprintf '! %s @ %s', $_[0]->module, eval { gentooize_version( $exclusion, { lax => 1 } ) } || '?';
    }
  }
  return join q[ ], @out;
}

no Moo;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Gentoo::Util::MetaCPAN::Requirement - A Single dependency requirement speciailised for Gentoo

=head1 VERSION

version 0.001000

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
