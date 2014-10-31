use 5.006;
use strict;
use warnings;

package Gentoo::Util::MetaCPAN::File;

our $VERSION = '0.001000';

# ABSTRACT: Enhancements to MetaCPAN::File

# AUTHORITY

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

