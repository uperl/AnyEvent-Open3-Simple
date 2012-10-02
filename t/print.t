use strict;
use warnings;
use Test::More tests => 3;

use v5.10;
use AnyEvent;
use AnyEvent::Open3::Simple;
use File::Temp qw( tempdir );
use File::Spec;

my $dir = tempdir( CLEANUP => 1 );
my $fh;
open($fh, '>', File::Spec->catfile($dir, 'child.pl'));
say $fh "#!$^X";
say $fh 'use File::Spec';
say $fh "open(\$out, '>', File::Spec->catfile('$dir', 'child.out'));";
say $fh 'while(<STDIN>) {';
say $fh '  print $out $_';
say $fh '}';
close $fh;

my $done = AnyEvent->condvar;

my $ipc = AnyEvent::Open3::Simple->new(
  on_exit => sub {
    $done->send;
  },
  on_start => sub {
    my($proc) = @_;
    eval { $proc->say('message1') };
    diag $@ if $@;
    eval { $proc->say('message2') };
    diag $@ if $@;
    eval { $proc->close };
    diag $@ if $@;
  },
);

my $timeout = AnyEvent->timer(
  after => 5,
  cb    => sub { diag 'timeout!'; $done->send },
);

my $proc = $ipc->run($^X, File::Spec->catfile($dir, 'child.pl'));
isa_ok $proc, 'AnyEvent::Open3::Simple';

$done->recv;

open($fh, '<', File::Spec->catfile($dir, 'child.out'));
my @list = <$fh>;
close $fh;

chomp $_ for @list;

is $list[0], 'message1', 'list[0] = message1';
is $list[1], 'message2', 'list[1] = message2';