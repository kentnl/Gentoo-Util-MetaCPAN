
use Test::More;
use strict;
use warnings;
use Test::RequiresInternet qw( api.metacpan.org 80 );
use Gentoo::Util::MetaCPAN qw( mcpan );
use List::UtilsBy qw( nsort_by );

#my $auth = mcpan->client->author('KENTNL');

my (@tests) = (
  [ 'Moose',                           'Moose' ],
  [ 'Module::Build',                   'Module-Build' ],
  [ 'Class::MOP',                      'Moose' ],
  [ 'MooX::Types::MooseLike::Numeric', 'MooX-Types-MooseLike-Numeric' ],
  [ 'LWP::UserAgent',                  'libwww-perl' ], ['if'],
);

sub pretty {
  return join qq[\n\t], map { $_->_pretty } @{ $_[0] };
}

my $relations = ['requires'];

for my $test (@tests) {
  subtest $test->[0] => sub {
    my (@files) = mcpan->find_latest_files_providing( @{$test} );
    for my $file (@files) {
      note explain $file->distribution;
    }
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

