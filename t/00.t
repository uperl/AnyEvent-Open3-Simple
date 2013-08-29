use strict;
use warnings;
use Test::More tests => 1;
use AnyEvent::Open3::Simple;

diag '';
diag '';
diag "OS = $^O perl $^V";
diag 'implementation = ' . AnyEvent::Open3::Simple->new->{impl};
diag '';
diag '';

pass 'okay';
