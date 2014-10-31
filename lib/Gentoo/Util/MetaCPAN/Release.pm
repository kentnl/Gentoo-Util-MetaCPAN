use 5.006;
use strict;
use warnings;

package Gentoo::Util::MetaCPAN::Release;

our $VERSION = '0.001000'; # TRIAL

# ABSTRACT: Subclass of MetaCPAN::Client::Release with some utility functions

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moo qw( extends has around );
use Gentoo::PerlMod::Version qw( gentooize_version );
use Gentoo::Util::MetaCPAN::Requirement;
use CPAN::Meta::Prereqs;
use MetaCPAN::Client::Release 1.007001;
use MetaCPAN::Client::ResultSet;

extends 'MetaCPAN::Client::Release';

has 'prereqs' => ( is => ro =>, lazy => 1, builder => '_build_prereqs' );

sub _build_prereqs {
  my ($self) = @_;
  if ( exists $self->metadata->{prereqs} ) {
    return CPAN::Meta::Prereqs->new( $self->metadata->{prereqs} );
  }
  my $pre = CPAN::Meta::Prereqs->new();

  for my $dependency ( @{ $self->{data}->{dependency} } ) {
    my $stash = $pre->requirements_for( $dependency->{phase}, $dependency->{relationship} );
    $stash->add_string_requirement( $dependency->{module}, $dependency->{version} );
  }
  return $pre;
}

sub get_dependencies {
  my ( $self, $phases, $relationships ) = @_;
  my $req = $self->prereqs->merged_requirements( $phases, $relationships );
  my @out;
  for my $module ( sort $req->required_modules ) {
    push @out,
      Gentoo::Util::MetaCPAN::Requirement->new(
      module => $module,
      range  => $req->{requirements}->{$module},
      );
  }
  return \@out;
}

sub gentoo_version {
  my ($self) = @_;
  ## no critic (ErrorHandling::RequireCheckingReturnValueOfEval)
  return eval { gentooize_version( $self->version, { lax => 1 } ) };
}

no Moo;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Gentoo::Util::MetaCPAN::Release - Subclass of MetaCPAN::Client::Release with some utility functions

=head1 VERSION

version 0.001000

=head1 METHODS

=head2 gentoo_version

=head2 get_dependencies

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
