package AnyEvent::Open3::Simple;

use strict;
use warnings;
use v5.10;
use AnyEvent;
use IPC::Open3 qw( open3 );
use Symbol qw( gensym );
use AnyEvent::Open3::Simple::Process;

# ABSTRACT: simple interface to open3 under AnyEvent
# VERSION

=head1 SYNOPSIS

 use v5.10;
 use AnyEvent;
 use AnyEvent::Open3::Simple;
 
 my $done = AnyEvent->condvar;
 
 my $ipc = AnyEvent::Open3::Simple(
   on_stdout => sub { say 'out: ', pop },
   on_stderr => sub { say 'err: ', pop },
   on_exit   => sub {
     my($proc, $exit_value, $signal) = @_;
     say 'exit value: ', $exit_value;
     say 'signal:     ', $signal;
     $done->send;
   },
 );
 
 $ipc->run('echo', 'hello there');
 
 $done->recv;

=head1 DESCRIPTION

This module provides an interface to open3 while running under AnyEvent
that delivers data from stdout and stderr as lines are written by the
subprocess.  The interface is reminiscent of L<AnyEvent::Open3::Simple>.

=head1 CONSTRUCTOR

Constructor takes a hash or hashref of event callbacks.  These events
will be triggered by the subprocess when the run method is called.
Each even callback (except on_error) gets passed in an instance of 
L<AnyEvent::Open3::Simple::Process> as its first argument which can be
used to get the PID of the subprocess, or to write to it.  on_error
does not get a process object because it indicates an error in the 
creation of the process.

=head2 EVENTS

=over 4

=item * on_stdout ($proc, $line)

=item * on_stderr ($proc, $line)

=item * on_exit ($proc, $exit_value, $signal)

Fired when the processes completes, either because it called exit,
or if it was killed by a signal.

=item * on_signal ($proc, $signal)

=item * on_fail ($proc, $exit_value)

=item * on_error ($error)

=back

=cut

sub new
{
  state $default_handler = sub { };
  my $class = shift;
  my $args = ref $_[0] eq 'HSAH' ? shift : { @_ };
  my %self;
  $self{$_} = $args->{$_} // $default_handler for qw( on_stdout on_stderr on_exit on_signal on_fail on_error );
  bless \%self, $class;
}

=head1 METHODS

=head2 $ipc-E<gt>run($program, @arguments)

Start the given program with the given arguments.
Returns an instance of L<AnyEvent::Open3::Simple::Process> immediately.

=cut

sub run
{
  my($self, $program, @arguments) = @_;
  
  my($child_stdin, $child_stdout, $child_stderr);
  $child_stderr = gensym;
  
  my $pid = eval { open3 $child_stdin, $child_stdout, $child_stderr, $program, @arguments };
  
  if(my $error = $@)
  {
    $self->{on_error}->($error);
    return;
  }
  
  my $proc = AnyEvent::Open3::Simple::Process->new($pid, $child_stdin);
  
  my $watcher_stdout = AnyEvent->io(
    fh   => $child_stdout,
    poll => 'r',
    cb   => sub {
      my $input = <$child_stdout>;
      return unless defined $input;
      chomp $input;
      $self->{on_stdout}->($proc, $input);
    },
  );
  
  my $watcher_stderr = AnyEvent->io(
    fh   => $child_stderr,
    poll => 'r',
    cb   => sub {
      my $input = <$child_stderr>;
      return unless defined $input;
      chomp $input;
      $self->{on_stderr}->($proc, $input);
    },
  );
  
  my $watcher_child;
  $watcher_child = AnyEvent->child(
    pid => $pid,
    cb  => sub {
      my($pid, $status) = @_;
      my($exit_value, $signal) = ($status >> 8, $status & 127);
      $self->{on_exit}->($proc, $exit_value, $signal);
      $self->{on_signal}->($proc, $signal) if $signal > 0;
      $self->{on_fail}->($proc, $exit_value) if $exit_value > 0;
      undef $watcher_stdout;
      undef $watcher_stderr;
      undef $watcher_child;
      undef $proc;
    },
  );
  
  $proc;
}

1;

=head1 CAVEATS

Some AnyEvent implementations may not work properly with the method
used by AnyEvent::Open3::Simple to wait for the child process to 
terminate.  See L<AnyEvent#CHILD-PROCESS-WATCHERS> for details.

=cut