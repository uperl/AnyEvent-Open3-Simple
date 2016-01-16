use strict;
use warnings;
use Test::More tests => 1;
use AnyEvent::Open3::Simple;

my $ipc = AnyEvent::Open3::Simple->new(
  implementation => undef,
);

isnt $ipc->{impl}, undef, "impl = @{[ $ipc->{impl} ]}";
