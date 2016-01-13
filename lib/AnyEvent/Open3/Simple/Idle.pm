package AnyEvent::Open3::Simple::Idle;

use strict;
use warnings;
use POSIX ':sys_wait_h';

# ABSTRACT: Code for the AnyEvent::Open3::Simple idle implementation
# VERSION

sub _watcher
{
  my $pid = waitpid($_[0], WNOHANG);
  $_[1]->($_[0], $?) if $_[0] == $pid;
}

1;
