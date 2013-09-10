use strict;
use warnings;
BEGIN { eval q{ use EV } }
use Test::More tests => 3;
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

my $child_pid;
my $proc;

my $ipc = AnyEvent::Open3::Simple->new(
  on_start => sub {
    ($proc) = @_;
  },
  on_exit => sub {
    my($proc) = @_;
    $done->send;
    $child_pid = eval { $proc->pid } || '';
    like $child_pid, qr/^\d+$/, "on_exit proc->pid = $child_pid";
    diag $@ if $@;
  },
);

my $ret = $ipc->run($^X, File::Spec->catfile($dir, 'child.pl'));
isa_ok $ret, 'AnyEvent::Open3::Simple';

my $timeout = AnyEvent->timer (
  after => 5,
  cb    => sub { diag 'timeout!'; exit 2; },
);

$done->recv;

is eval { $proc->pid }, $child_pid, "both procs have same pid";
diag $@ if $@;
