use strict;
use warnings;
BEGIN { eval q{ use EV } }
use Test::More tests => 4;
use AnyEvent::Open3::Simple;
use File::Temp qw( tempdir );
use AnyEvent;
use AnyEvent::Open3::Simple;
use File::Spec;

my $dir = tempdir( CLEANUP => 1 );
my $fh;
open($fh, '>', File::Spec->catfile($dir, 'child.pl'));
print $fh "#!$^X\n";
close $fh;

my $done = AnyEvent->condvar;
my $on_start = 0;
my $on_start_called = 0;
my $proc;
my $prog;
my @args;

my $ipc = AnyEvent::Open3::Simple->new(
  on_start => sub {
    ($proc, $prog, @args) = @_;
    $on_start_called = 1;
  },
  on_exit => sub {
    my($proc) = @_;
    $done->send;
  },
);

my $ret = $ipc->run($^X, File::Spec->catfile($dir, 'child.pl'), 'arg1', 'arg2');
isa_ok $ret, 'AnyEvent::Open3::Simple';

my $timeout = AnyEvent->timer (
  after => 5,
  cb    => sub { diag 'timeout!'; exit 2; },
);

$done->recv;

ok $on_start_called, 'on_start event fired';

is $prog, $^X, 'prog';
is_deeply \@args, [File::Spec->catfile($dir, 'child.pl'), 'arg1', 'arg2'], 'args';
