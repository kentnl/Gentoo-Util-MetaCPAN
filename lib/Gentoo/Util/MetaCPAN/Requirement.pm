use 5.006;
use strict;
use warnings;

package Gentoo::Util::MetaCPAN::Requirement;

our $VERSION = '0.001001'; # TRIAL

# ABSTRACT: A Single dependency requirement specialized for Gentoo

# AUTHORITY

use Moo qw( has );
use Gentoo::PerlMod::Version qw( gentooize_version );

has 'module'         => ( is => ro =>, required => 1, );
has 'range'          => ( is => ro =>, required => 1, );
has 'version'        => ( is => ro =>, lazy     => 1, builder => '_build_version' );
has 'gentoo_version' => ( is => ro =>, lazy     => 1, builder => '_build_gentoo_version' );

sub BUILD {
  my ($self) = @_;
  $self->gentoo_version;
  return;
}

sub _has_min_version {
  my ($self) = @_;
  ## no critic (Subroutines::ProtectPrivateSubs)
  return !( $self->range->_accepts(0) );
}

sub _build_version {
  my ($self) = @_;
  return $self->range->as_string;
}

sub _build_gentoo_version {
  my ($self) = @_;
  my $ver;
  ## no critic (ErrorHandling::RequireCheckingReturnValueOfEval)
  eval { $ver = gentooize_version( $self->version, { lax => 1 } ); };
  return $ver;
}

sub _pretty_version {
  my ($version) = @_;
  return eval { gentooize_version( $version, { lax => 1 } ) } || q<?>;
}

sub _pretty {
  my ($self) = @_;
  my $module = $self->module;
  my $range  = $self->range;
  if ( $range->isa('CPAN::Meta::Requirements::_Range::Exact') ) {
    return sprintf '= %s @ %s', $module, _pretty_version( $range->{version} );
  }
  my @out;
  if ( exists $range->{minimum} ) {
    if ( $range->{minimum} != 0 ) {
      push @out, sprintf '>= %s @ %s', $module, _pretty_version( $range->{minimum} );
    }
    else {
      push @out, sprintf '%s', $module;
    }
  }
  if ( exists $range->{maximum} ) {
    push @out, sprintf '<= %s @ %s', $module, _pretty_version( $range->{maximum} );
  }
  if ( exists $range->{exclusions} ) {
    for my $exclusion ( @{ $range->{exclusions} } ) {
      push @out, sprintf '! %s @ %s', $module, _pretty_version( $exclusion, { lax => 1 } );
    }
  }
  return join q[ ], @out;
}

no Moo;

1;

=method BUILD

=method module

=method range
