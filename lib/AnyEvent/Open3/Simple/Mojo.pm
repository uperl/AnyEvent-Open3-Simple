package AnyEvent::Open3::Simple::Mojo;

use strict;
use warnings;
use POSIX ':sys_wait_h';

# ABSTRACT: Code for the AnyEvent::Open3::Simple mojo implementation
# VERSION

if($^O eq 'MSWin32')
{
  *_watcher = sub
  {
    my $pid = waitpid($_[0], WNOHANG);
    $_[1]->($_[0], $?) if $_[0] == $pid;
  };
}
else
{
  my %proc;

  $SIG{CHLD} = sub {
    while((my $pid = waitpid -1, WNOHANG) > 0)
    {
      $proc{$pid} = $?;
    }
  };

  *_watcher = sub
  {
    my($pid, $cb) = @_;
    $cb->($pid, delete $proc{$pid}) if defined $proc{$pid};
  };
}

1;
