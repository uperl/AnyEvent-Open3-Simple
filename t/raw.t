use strict;
use warnings;
BEGIN { $^O eq 'MSWin32' ? eval q{ use Event; 1 } || q{ use EV } : eval q{ use EV } }
use Test::More tests => 3;
use File::Temp qw( tempdir );
use AnyEvent;
use AnyEvent::Open3::Simple;
use File::Spec;

my $dir = tempdir( CLEANUP => 1);
#note "dir = $dir";
open(my $fh, '>', File::Spec->catfile($dir, 'child.pl'));
print $fh join "\n", "#!$^X",
                     '$| = 1;',
                     'print "message1\n";',
                     'print STDERR "message3\n";',
                     'print STDERR "message4\n";',
                     'print "message2\n";';
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

TODO: {
  # https://github.com/plicease/AnyEvent-Open3-Simple/issues/6
  todo_skip "experimental", 2;
  like $out, qr{^message1(\015?\012|\015)message2(\015?\012|\015)$}, "out";
  like $err, qr{^message3(\015?\012|\015)message4(\015?\012|\015)$}, "err";
}

diag '';
diag "===out===";
diag $out;
diag "===err===";
diag $err;

