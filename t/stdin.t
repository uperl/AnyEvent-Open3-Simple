use strict;
use warnings;
no warnings 'deprecated';
BEGIN { $^O eq 'MSWin32' ? eval q{ use Event; 1 } || q{ use EV } : eval q{ use EV } }
use Test::More tests => 4;
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

foreach my $stdin ([ qw( message1 message2 ) ], join("\n", qw( message1 message2 )))
{
  foreach my $phase (qw( constructor run ))
  {
    subtest "phase[$phase] stdin[$stdin]" => sub {
      plan tests => 4;
  
      my $done = AnyEvent->condvar;

      my $ipc = AnyEvent::Open3::Simple->new(
        on_exit => sub {
          $done->send(1);
        },
        $phase eq 'constructor' ? (stdin => $stdin) : (),
      );

      my $timeout = AnyEvent->timer(
        after => 5,
        cb    => sub { diag 'timeout!'; $done->send(0) },
      );

      my $proc = $ipc->run($^X, File::Spec->catfile($dir, 'child.pl'), $phase eq 'run' ? (ref $stdin ? $stdin : \$stdin) : ());
      isa_ok $proc, 'AnyEvent::Open3::Simple';

      is $done->recv, 1, 'no timeout';

      open($fh, '<', File::Spec->catfile($dir, 'child.out'));
      my @list = <$fh>;
      close $fh;

      chomp $_ for @list;

      is $list[0], 'message1', 'list[0] = message1';
      is $list[1], 'message2', 'list[1] = message2';
    };
  }
}
