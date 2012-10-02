package AnyEvent::Open3::Simple;

use strict;
use warnings;
use v5.10;
use AnyEvent;
use IPC::Open3 qw( open3 );
use Scalar::Util qw( reftype );
use Symbol qw( gensym );
use AnyEvent::Open3::Simple::Process;

# ABSTRACT: interface to open3 under AnyEvent
# VERSION

=head1 SYNOPSIS

 use v5.10;
 use AnyEvent;
 use AnyEvent::Open3::Simple;
 
 my $done = AnyEvent->condvar;
 
 my $ipc = AnyEvent::Open3::Simple->new(
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
subprocess.  The interface is reminiscent of L<IPC::Open3::Simple>, 
although this module does provides a somewhat different API, so it
cannot be used a drop in replacement for that module.

There are already a number of interfaces for interacting with subprocesses
in the context of L<AnyEvent>, but this one is the most convenient for my
usage.  Note the modules listed in the SEE ALSO section below for other 
interfaces that may be more or less appropriate.

=head1 CONSTRUCTOR

Constructor takes a hash or hashref of event callbacks.

=head2 EVENTS

These events will be triggered by the subprocess when the run method is 
called. Each event callback (except on_error) gets passed in an 
instance of L<AnyEvent::Open3::Simple::Process> as its first argument 
which can be used to get the PID of the subprocess, or to write to it.  
on_error does not get a process object because it indicates an error in 
the creation of the process.

Not all of these events will fire depending on the execution of the 
child process.  In the very least exactly one of on_start or on_error
will be called.

=over 4

=item * on_start ($proc)

Called after the process is created, but before the run method returns
(that is, it does not wait to re-enter the event loop first).

=item * on_error ($error)

Called when there is an execution error, for example, if you ask
to run a program that does not exist.  No process is passed in
because the process failed to create.  The error passed in is 
the error thrown by L<IPC::Open3> (typically a string which begins
with "open3: ...").

In some environments open3 is unable to detect exec errors in the
child, so you may not be able to rely on this event.  It does 
seem to work consistently on Perl 5.14 or better though.

=item * on_stdout ($proc, $line)

Called on every line printed to stdout by the child process.

=item * on_stderr ($proc, $line)

Called on every line printed to stderr by the child process.

=item * on_exit ($proc, $exit_value, $signal)

Called when the processes completes, either because it called exit,
or if it was killed by a signal.  

=item * on_signal ($proc, $signal)

Called when the processes is terminated by a signal.

=item * on_fail ($proc, $exit_value)

Called when the process returns a non-zero exit value.

=back

=cut

sub new
{
  state $default_handler = sub { };
  my $class = shift;
  my $args = (reftype($_[0]) // '') eq 'HASH' ? shift : { @_ };
  my %self;
  $self{$_} = $args->{$_} // $default_handler for qw( on_stdout on_stderr on_start on_exit on_signal on_fail on_error );
  bless \%self, $class;
}

=head1 METHODS

=head2 $ipc-E<gt>run($program, @arguments)

Start the given program with the given arguments.  Returns
immediately.  Any events that have been specified in the
constructor (except for on_start) will not be called until
the process re-enters the event loop.

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
  
  $self->{on_start}->($proc);
  
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
      
      $child_stdin->close;
      
      # make sure we consume any stdout and stderr which hasn't
      # been consumed yet.  This seems to make on_out.t work on
      # cygwin
      while(!eof $child_stdout)
      {
        my $input = <$child_stdout>;
        last unless defined $input;
        chomp $input;
        $self->{on_stdout}->($proc,$input);
      }
      
      while(!eof $child_stderr)
      {
        my $input = <$child_stderr>;
        last unless defined $input;
        chomp $input;
        $self->{on_stderr}->($proc,$input);
      }
      
      $self->{on_exit}->($proc, $exit_value, $signal);
      $self->{on_signal}->($proc, $signal) if $signal > 0;
      $self->{on_fail}->($proc, $exit_value) if $exit_value > 0;
      undef $watcher_stdout;
      undef $watcher_stderr;
      undef $watcher_child;
      undef $proc;
    },
  );
  
  $self;
}

1;

=head1 CAVEATS

Some AnyEvent implementations may not work properly with the method
used by AnyEvent::Open3::Simple to wait for the child process to 
terminate.  See L<AnyEvent/"CHILD-PROCESS-WATCHERS"> for details.

This module is not supported under Windows (MSWin32), but it does seem
to work under Cygwin (cygwin).  Patches are welcome for any platforms
that don't work.

There are some traps for the unwary relating to buffers and deadlocks,
L<IPC::Open3> is recommended reading.

=head1 SEE ALSO

L<AnyEvent::Subprocess>, L<AnyEvent::Util>, L<AnyEvent::Run>.

=cut
