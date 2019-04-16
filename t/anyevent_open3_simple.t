use strict;
use warnings;
use Test::More;
use AnyEvent::Open3::Simple;

my $ipc = eval { AnyEvent::Open3::Simple->new };
diag $@ if $@;
isa_ok $ipc, 'AnyEvent::Open3::Simple';

done_testing;
