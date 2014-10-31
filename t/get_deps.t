
use Test::More;
use strict;
use warnings;
use Test::RequiresInternet qw( api.metacpan.org 80 );
use Gentoo::Util::MetaCPAN qw( mcpan );

#my $auth = mcpan->client->author('KENTNL');

my (@tests) = (
  [ 'DOY',    'Moose-2.0301-TRIAL' ],         #
  [ 'LEONT',  'Module-Build-Tiny-0.038' ],    #
  [ 'KENTNL', 'Gentoo-Overlay-2.001001' ],    #
  [ 'ETHER',  'Task-Kensho-0.38' ],           #
);

sub pretty {
  return join qq[\n\t], map { $_->_pretty } @{ $_[0] };
}

my $relations = ['requires'];

for my $test (@tests) {
  subtest $test->[0] . '/' . $test->[1] => sub {
    my ( $release, ) = mcpan->find_release( @{$test} );
    note 'dev-perl/' . $release->distribution . '-' . $release->gentoo_version;

    #note explain $release->metadata;
    note "\e[31mDYNAMIC\e[0m" if $release->metadata->{dynamic_config};

    note "RDEPEND='\n\t" . pretty( $release->get_dependencies( ['runtime'], $relations ) ) . "'\n";
    my $TDEPEND = $release->get_dependencies( ['test'], $relations );
    my $ddtdeps = pretty( $release->get_dependencies( [ 'configure', 'build' ], $relations ) );
    if (@$TDEPEND) {
      $ddtdeps .= "\n\ttest? (\n\t" . ( pretty($TDEPEND) =~ s/^/\t/msxrg ) . "\n\t)\n";
    }
    note "DEPEND='\n\tRDEPEND\n\t" . $ddtdeps . "'\n";
    pass("Run/Load ok");
  };
}

#  author => 'DOY'
#  name   => 'Moose-2.0301-TRIAL',
#);

#delete $auth->{client};
#delete $release->{client};

#note explain $auth;
#note explain $release;

done_testing;

