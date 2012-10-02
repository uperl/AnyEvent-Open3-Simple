use strict;
use warnings;
use Test::More tests => 3;
use AnyEvent::Open3::Simple;

use File::Temp qw( tempdir );
use v5.10;
use AnyEvent;
use AnyEvent::Open3::Simple;
use File::Spec;

my $dir = tempdir( CLEANUP => 1 );
my $fh;
open($fh, '>', File::Spec->catfile($dir, 'child.pl'));
say $fh "#!$^X";
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
    $child_pid = eval { $proc->pid } // '';
    like $child_pid, qr/^\d+$/, "on_exit proc->pid = $child_pid";
    diag $@ if $@;
  },
);

my $ret = $ipc->run($^X, File::Spec->catfile($dir, 'child.pl'));
isa_ok $ret, 'AnyEvent::Open3::Simple';

$done->recv;

is eval { $proc->pid }, $child_pid, "both procs have same pid";
diag $@ if $@;