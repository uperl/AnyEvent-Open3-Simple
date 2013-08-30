use strict;
use warnings;
use v5.10;
BEGIN { eval q{ use EV } }
use Test::More tests => 3;
use File::Temp qw( tempdir );
use AnyEvent;
use AnyEvent::Open3::Simple;
use File::Spec;

my $dir = tempdir( CLEANUP => 1);
#note "dir = $dir";
open(my $fh, '>', File::Spec->catfile($dir, 'child.pl'));
say $fh "#!$^X";
say $fh '$| = 1;';
say $fh 'print "message1\n";';
say $fh 'print STDERR "message3\n";';
say $fh 'print STDERR "message4\n";';
say $fh 'print "message2\n";';
close $fh;

my $done = AnyEvent->condvar;

my $out = '';
my $err = '';

my $ipc = AnyEvent::Open3::Simple->new(
  raw       => 1,
  on_stdout => sub { $out .= pop },
  on_stderr => sub { $err .= pop },
  on_exit   => sub {
    $done->send;
  },
);

my $timeout = AnyEvent->timer (
  after => 5,
  cb    => sub { diag 'timeout!'; exit 2; },
);

my $ret = $ipc->run($^X, File::Spec->catfile($dir, 'child.pl'));
diag $@ if $@;
isa_ok $ret, 'AnyEvent::Open3::Simple';

$done->recv;

like $out, qr{^message1(\015?\012|\015)message2(\015?\012|\015)$}, "out";
like $err, qr{^message3(\015?\012|\015)message4(\015?\012|\015)$}, "err";

#note "===out===";
#note $out;
#note "===err===";
#note $err;
