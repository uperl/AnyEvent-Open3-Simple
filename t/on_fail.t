use strict;
use warnings;
use Test::More tests => 6;
use AnyEvent::Open3::Simple;

use File::Temp qw( tempdir );
use v5.10;
use AnyEvent;
use AnyEvent::Open3::Simple;
use File::Spec;

my $dir = tempdir( CLEANUP => 1);
do {
  my $fh;
  open($fh, '>', File::Spec->catfile($dir, 'child_exit3.pl'));
  say $fh "#!$^X";
  say $fh "exit 3";
  close $fh;
  
  open($fh, '>', File::Spec->catfile($dir, 'child_normal.pl'));
  say $fh "#!$^X";
  close $fh;
};

my $done = AnyEvent->condvar;

my($proc, $signal, $exit_value1, $exit_value2);

my $ipc = AnyEvent::Open3::Simple->new(
  on_fail => sub {
    ($proc, $exit_value1) = @_;
  },
  on_exit   => sub {
    ($proc, $exit_value2, $signal) = @_;
    $done->send;
  },
);

my $timeout = AnyEvent->timer (
  after => 5,
  cb    => sub { diag 'timeout!'; $done->send },
);

do {
  my $ret = eval { $ipc->run($^X, File::Spec->catfile($dir, 'child_normal.pl')) };
  diag $@ if $@;
  isa_ok $ret, 'AnyEvent::Open3::Simple::Process';
  
  $done = AnyEvent->condvar;
  $done->recv;
  
  is $exit_value1, undef, 'exit_value1 = undef';
  is $exit_value2, 0, 'exit_value2 = 0';
};

do {
  my $ret = eval { $ipc->run($^X, File::Spec->catfile($dir, 'child_exit3.pl')) };
  diag $@ if $@;
  isa_ok $ret, 'AnyEvent::Open3::Simple::Process';

  $done = AnyEvent->condvar;
  $done->recv;
  
  is $exit_value1, 3, 'exit_value1 = 3';
  is $exit_value2, 3, 'exit_value2 = 3';
};