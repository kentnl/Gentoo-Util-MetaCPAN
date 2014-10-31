use 5.006;
use strict;
use warnings;

package Gentoo::Util::MetaCPAN;

our $VERSION = '0.001000'; # TRIAL

# ABSTRACT: Gentoo Specific MetaCPAN Utilities.

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moo;
use MooX::Lsub qw( lsub );
use File::Spec;
use Sub::Exporter::Progressive -setup => { exports => ['mcpan'] };
use Path::Tiny qw( path );

sub _mk_cache {
  my ( $name, %opts ) = @_;
  my $root  = path( File::Spec->tmpdir );
  my $child = $root->child('gentoo-metacpan-cache');
  $child->mkpath;
  my $db = $child->child($name);
  require Data::Serializer::Sereal;
  require Sereal;
  my $serial = Data::Serializer::Sereal->new( encoder => Sereal::Encoder->new( { compress => 1, canonincal => 1 } ) );
  $db->mkpath;
  require CHI;
  require CHI::Driver::LMDB;
  return CHI->new(
    driver           => 'LMDB',
    root_dir         => "$db",
    expires_in       => '6 hour',
    expires_variance => '0.2',
    namespace        => $name,
    cache_size       => '30m',
    key_serializer   => $serial,
    serializer       => $serial,
    %opts,
  );
}

lsub 'www_cache'    => sub { _mk_cache('web') };
lsub 'object_cache' => sub { _mk_cache('objects') };

lsub 'debug' => sub {
  return unless defined $ENV{WWW_MECH_DEBUG};
  return $ENV{WWW_MECH_DEBUG};
};
lsub 'nocache' => sub {
  return unless defined $ENV{WWW_MECH_NOCACHE};
  return $ENV{WWW_MECH_NOCACHE};
};
lsub 'mechua' => sub {
  my ($self) = @_;
  my $mech;
  if ( $self->nocache ) {
    require LWP::UserAgent;
    $mech = LWP::UserAgent->new();
  }
  else {
    require WWW::Mechanize::Cached;
    $mech = WWW::Mechanize::Cached->new(
      cache     => $self->www_cache,
      timeout   => 20_000,
      autocheck => 1,
    );
  }
  if ( ( $self->debug || 0 ) > 1 ) {
    $mech->add_handler(
      'request_send' => sub {
        *STDERR->printf( "%s\n", $_[0]->as_string );
        return;
      },
    );
    $mech->add_handler(
      'response_done' => sub {
        *STDERR->printf( "%s\n", $_[0]->content );
        return;
      },
    );
  }
  elsif ( $self->debug ) {
    $mech->add_handler(
      'request_send' => sub {
        *STDERR->printf( "%s\n", $_[0]->dump );
        return;
      },
    );
    $mech->add_handler(
      'response_done' => sub {
        *STDERR->printf( "%s\n", $_[0]->dump );
        return;
      },
    );
  }
  return $mech;
};
lsub 'tinymech' => sub {
  my ($self) = @_;
  require HTTP::Tiny::Mech;
  HTTP::Tiny::Mech->new( mechua => $self->mechua );
};
lsub 'client' => sub {
  my ($self) = @_;
  require MetaCPAN::Client;
  MetaCPAN::Client->new( ua => $self->tinymech );
};

sub _cache_object {
  my ( $self, $key, $time, $code ) = @_;
  if ( $self->nocache ) {
    return $code->();
  }
  return $self->object_cache->compute( $key, $time, $code );
}
{
## HACK: This exists because its not supported natively yet.
  ## no critic (TestingAndDebugging::ProhibitNoWarnings,Subroutines::ProhibitQualifiedSubDeclarations)
  no warnings 'redefine';

  use MetaCPAN::Client::ResultSet;

  sub MetaCPAN::Client::ResultSet::next {
    my $self = shift;
    my $result =
        $self->has_scroller
      ? $self->scroller->next
      : shift @{ $self->items };

    defined $result or return;

    my $class = exists $self->{'class'} ? $self->{class} : 'MetaCPAN::Client::' . ucfirst $self->type;
    return $class->new_from_request( $result->{'_source'} || $result->{'fields'} );
  }
}

# More hacks because the native MetaCPAN client is a bit broken
sub _raw_scroll_query {
  my ( $self, $config ) = @_;

  my $creq = $self->client->request;

  my $class = delete $config->{'class'};
  my $type  = delete $config->{type};

  my $scroller = $creq->ssearch( $type, { bogus => 1 }, $config );

  if ( not $class ) {
    $class = 'MetaCPAN::Client::' . ucfirst( $config->{type} );
  }
  my $rs = MetaCPAN::Client::ResultSet->new(
    type     => $type,
    scroller => $scroller,
  );
  $rs->{class} = $class;
  return $rs;
}

sub _scroll_to_list {
  my ( undef, $scroll ) = @_;
  my @out;
  while ( my $item = $scroll->next ) {
    push @out, $item;
  }
  return @out;
}

sub find_release {
  my ( $self, $author, $dist ) = @_;
  require Gentoo::Util::MetaCPAN::Release;
  my $query = {
    type  => 'release',
    class => 'Gentoo::Util::MetaCPAN::Release',
    body  => {
      query => {
        bool => {
          must => [
            { term => { name   => $dist } },      #
            { term => { author => $author } },    #
          ],
        },
      },
    },
  };
  my $result = $self->_cache_object(
    [ 'find_release', $author, $dist ] => undef,
    => sub {
      return [ $self->_scroll_to_list( $self->_raw_scroll_query($query) ), ];
    },
  );
  return @{$result};
}

sub find_files_providing {
  my ( $self, $module_name ) = @_;
  require Gentoo::Util::MetaCPAN::File;

  my @terms;
  push @terms, { term => { 'module.authorized' => 1 } };
  push @terms, { term => { 'module.indexed'    => 1 } };
  push @terms, { term => { 'module.name'       => $module_name } };

  my $nested_query = {
    constant_score => {
      filter => {
        and => \@terms,
      },
    },
  };
  my $query = {
    filtered => {
      query => {
        nested => {
          path  => 'module',
          query => $nested_query,
        },
      },
    },
  };
  my $config = {
    type  => 'file',
    class => 'Gentoo::Util::MetaCPAN::File',
    body  => {
      query => $query,
    },
  };
  my $result = $self->_cache_object(
    [ 'find_files_providing', $module_name ] => undef,
    => sub {
      return [ $self->_scroll_to_list( $self->_raw_scroll_query($config) ) ];
    },
  );
  return @{$result};
}

sub find_latest_files_providing {
  my ( $self, $module_name ) = @_;
  require Gentoo::Util::MetaCPAN::File;

  my @terms;
  push @terms, { term => { 'module.authorized' => 1 } };
  push @terms, { term => { 'module.indexed'    => 1 } };
  push @terms, { term => { 'module.name'       => $module_name } };

  my $nested_query = {
    constant_score => {
      filter => {
        and => \@terms,
      },
    },
  };
  my $query = {
    filtered => {
      query => {
        nested => {
          path  => 'module',
          query => $nested_query,
        },
      },
    },
  };
  my $config = {
    type  => 'file',
    class => 'Gentoo::Util::MetaCPAN::File',

    body => {
      fields        => q[*],
      script_fields => { latest => { 'metacpan_script' => 'status_is_latest' } },
      query         => $query,
    },
  };
  my $result = $self->_cache_object(
    [ 'find_latest_files_providing', $module_name ] => undef,
    => sub {
      return [ grep { $_->latest } $self->_scroll_to_list( $self->_raw_scroll_query($config) ) ];
    },
  );
  return @{$result};

}

sub find_releases_providing {
  my ( $self, $module_name ) = @_;
  require Gentoo::Util::MetaCPAN::Release;

  my $nested_query = {
    bool => {
      must => [
        { term => { 'authorized' => 1 } },               #
        { term => { 'indexed'    => 1 } },               #
        { term => { 'name'       => $module_name } },    #
      ],
    },
  };

  my $query = {
    nested => {
      path  => 'module',
      query => $nested_query,
    },
  };

  my $config = {
    type  => 'release',
    class => 'Gentoo::Util::MetaCPAN::Release',
    body  => {
      query => {    #     %{$query},
        constant_score => { query => $query },
      },
    },
  };
  my $result = $self->_cache_object(
    [ 'find_releases_providing', $module_name ] => undef,
    => sub {
      return [ $self->_scroll_to_list( $self->_raw_scroll_query($config) ) ];
    },
  );
  return @{$result};
}

sub mcpan { return __PACKAGE__->new() }

no Moo;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Gentoo::Util::MetaCPAN - Gentoo Specific MetaCPAN Utilities.

=head1 VERSION

version 0.001000

=head1 METHODS

=head2 find_files_providing

=head2 find_latest_files_providing

=head2 find_release

=head2 find_releases_providing

=head1 FUNCTIONS

=head2 C<mcpan>

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
