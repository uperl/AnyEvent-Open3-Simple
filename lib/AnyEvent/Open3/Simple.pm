package AnyEvent::Open3::Simple;

use strict;
use warnings;
use AnyEvent;
use IPC::Open3 qw( open3 );
use Scalar::Util qw( reftype );
use Symbol qw( gensym );
use AnyEvent::Open3::Simple::Process;
use Carp qw( croak );

# ABSTRACT: interface to open3 under AnyEvent
# VERSION

=head1 SYNOPSIS

 use v5.10;
 use AnyEvent;
 use AnyEvent::Open3::Simple;
 
 my $done = AnyEvent->condvar;
 
 my $ipc = AnyEvent::Open3::Simple->new(
   on_start => sub {
     my $proc = shift; # isa AnyEvent::Open3::Simple::Process
     say 'child PID: ', $proc->pid;
   },
   on_stdout => sub { 
     my $proc = shift; # isa AnyEvent::Open3::Simple::Process
     my $line = shift; # string
     say 'out: ', $string;
   },
   on_stderr => sub {
     my $proc = shift; # isa AnyEvent::Open3::Simple::Process
     my $line = shift; # string
     say 'err: ', $line;
   },
   on_exit   => sub {
     my $proc = shift;       # isa AnyEvent::Open3::Simple::Process
     my $exit_value = shift; # integer
     my $signal = shift;     # integer
     say 'exit value: ', $exit_value;
     say 'signal:     ', $signal;
     $done->send;
   },
   on_error => sub {
     my $error = shift;      # the exception thrown by IPC::Open3::open3
     warn "error: $error";
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

Constructor takes a hash or hashref of event callbacks and attributes.
Event callbacks have an C<on_> prefix, attributes do not.

=head2 ATTRIBUTES

=over 4

=item * implementation

The implementation to use for detecting process termination.  This should
be one of C<child> or C<idle>.  On all platforms except for Microsoft
Windows (but not Cygwin) the default is C<child>.

You can change the default by setting the C<ANYEVENT_OPEN3_SIMPLE>
environment variable, like this:

 % export ANYEVENT_OPEN3_SIMPLE=idle

=back

=head2 EVENTS

These events will be triggered by the subprocess when the run method is 
called. Each event callback (except C<on_error>) gets passed in an 
instance of L<AnyEvent::Open3::Simple::Process> as its first argument 
which can be used to get the PID of the subprocess, or to write to it.  
C<on_error> does not get a process object because it indicates an error in 
the creation of the process.

Not all of these events will fire depending on the execution of the 
child process.  In the very least exactly one of C<on_start> or C<on_error>
will be called.

=over 4

=item * C<on_start> ($proc)

Called after the process is created, but before the run method returns
(that is, it does not wait to re-enter the event loop first).

=item * C<on_error> ($error)

Called when there is an execution error, for example, if you ask
to run a program that does not exist.  No process is passed in
because the process failed to create.  The error passed in is 
the error thrown by L<IPC::Open3> (typically a string which begins
with "open3: ...").

In some environments open3 is unable to detect exec errors in the
child, so you may not be able to rely on this event.  It does 
seem to work consistently on Perl 5.14 or better though.

Different environments have different ways of handling it when
you ask to run a program that doesn't exist.  On Linux and Cygwin,
this will raise an C<on_error> event, on C<MSWin32> it will
not trigger a C<on_error> and instead cause a normal exit
with a exit value of 1.

=item * C<on_stdout> ($proc, $line)

Called on every line printed to stdout by the child process.

=item * C<on_stderr> ($proc, $line)

Called on every line printed to stderr by the child process.

=item * C<on_exit> ($proc, $exit_value, $signal)

Called when the processes completes, either because it called exit,
or if it was killed by a signal.  

=item * C<on_success> ($proc)

Called when the process returns zero exit value and is not terminated by a signal.

=item * C<on_signal> ($proc, $signal)

Called when the processes is terminated by a signal.

=item * C<on_fail> ($proc, $exit_value)

Called when the process returns a non-zero exit value.

=back

=cut

sub new
{
  my $default_handler = sub { };
  my $class = shift;
  my $args = (reftype($_[0]) || '') eq 'HASH' ? shift : { @_ };
  my %self;
  $self{$_} = $args->{$_} || $default_handler for qw( on_stdout on_stderr on_start on_exit on_signal on_fail on_error on_success );
  $self{impl} = $args->{implementation} 
             || $ENV{ANYEVENT_OPEN3_SIMPLE}
             || ($^O eq 'MSWin32' ? 'idle' : 'child');
  $self{raw} = $args->{raw} || 0;
  unless($self{impl} =~ /^(idle|child)$/)
  {
    croak "unknown implementation $self{impl}";
  }
  bless \%self, $class;
}

=head1 METHODS

=head2 $ipc-E<gt>run($program, @arguments)

Start the given program with the given arguments.  Returns
immediately.  Any events that have been specified in the
constructor (except for C<on_start>) will not be called until
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

  my $watcher_stdout;
  my $watcher_stderr;

  if($self->{raw})
  {

    require AnyEvent::Handle;
    $watcher_stdout = AnyEvent::Handle->new(
      fh => $child_stdout,
      on_error => sub {
        $self->{on_stdout}->($proc,$_[0]{rbuf});
      },
    );
    $watcher_stdout->on_read(sub {
      $watcher_stdout->push_read(sub {
        $DB::single = 1;
        $self->{on_stdout}->($proc,$_[0]{rbuf});
        $_[0]{rbuf} = '';
      });
    });
    $watcher_stderr = AnyEvent::Handle->new(
      fh => $child_stderr,
      on_error => sub {
        $self->{on_stderr}->($proc,$_[0]{rbuf});
      },
    );
    $watcher_stderr->on_read(sub {
      $watcher_stdout->push_read(sub {
        $self->{on_stderr}->($proc,$_[0]{rbuf});
        $_[0]{rbuf} = '';
      });
    });

  }
  else
  {

    $watcher_stdout = AnyEvent->io(
      fh   => $child_stdout,
      poll => 'r',
      cb   => sub {
        my $input = <$child_stdout>;
        return unless defined $input;
        $input =~ s/(\015?\012|\015)$//;
        my $ref = $self->{on_stdout};
        ref($ref) eq 'ARRAY' ? push @$ref, $input : $ref->($proc, $input);
      },
    );

    $watcher_stderr = AnyEvent->io(
      fh   => $child_stderr,
      poll => 'r',
      cb   => sub {
        my $input = <$child_stderr>;
        return unless defined $input;
        $input =~ s/(\015?\012|\015)$//;
        my $ref = $self->{on_stderr};
        ref($ref) eq 'ARRAY' ? push @$ref, $input : $ref->($proc, $input);
      },
    );
  }

  my $watcher_child;

  my $end_cb = sub {
    my($pid, $status) = @_;
    my($exit_value, $signal) = ($status >> 8, $status & 127);
      
    $proc->close;
      
    # make sure we consume any stdout and stderr which hasn't
    # been consumed yet.  This seems to make on_out.t work on
    # cygwin
    if($self->{raw})
    {
      local $/;
      $self->{on_stdout}->($proc, scalar <$child_stdout>);
      $self->{on_stderr}->($proc, scalar <$child_stderr>);
    }
    else
    {
      while(!eof $child_stdout)
      {
        my $input = <$child_stdout>;
        last unless defined $input;
        $input =~ s/(\015?\012|\015)$//;
        my $ref = $self->{on_stdout};
        ref($ref) eq 'ARRAY' ? push @$ref, $input : $ref->($proc, $input);
      }
      
      while(!eof $child_stderr)
      {
        my $input = <$child_stderr>;
        last unless defined $input;
        $input =~ s/(\015?\012|\015)$//;
        my $ref = $self->{on_stderr};
        ref($ref) eq 'ARRAY' ? push @$ref, $input : $ref->($proc, $input);
      }
    }
      
    $self->{on_exit}->($proc, $exit_value, $signal);
    $self->{on_signal}->($proc, $signal) if $signal > 0;
    $self->{on_fail}->($proc, $exit_value) if $exit_value > 0;
    $self->{on_success}->($proc) if $signal == 0 && $exit_value == 0;
    undef $watcher_stdout;
    undef $watcher_stderr;
    undef $watcher_child;
    undef $proc;
  };

  if($self->{impl} eq 'idle')
  {
    $watcher_child = AnyEvent->idle(cb => sub {
      my $kid = eval q{
        use POSIX ":sys_wait_h";
        waitpid($pid, WNOHANG);
      };
      # shouldn't be throwing an exception
      # inside a callback, but then it 
      # this should always work (?)
      die $@ if $@;
      $end_cb->($kid, $?) if $kid == $pid;
    });
  }
  else
  {
    $watcher_child = AnyEvent->child(
      pid => $pid,
      cb  => $end_cb,
    );
  }
  
  $self;
}

1;

=head1 CAVEATS

Some AnyEvent implementations may not work properly with the method
used by AnyEvent::Open3::Simple to wait for the child process to 
terminate.  See L<AnyEvent/"CHILD-PROCESS-WATCHERS"> for details.

This module uses an idle watcher instead of a child watcher to detect
program termination on Microsoft Windows (but not Cygwin).  This is
because the child watchers are unsupported by AnyEvent on Windows.
The idle watcher implementation seems to pass the test suite, but there
may be some traps for the unwary.  There may be other platforms or
event loops where this is the appropriate choice, and you can use the
C<ANYEVENT_OPEN3_SIMPLE> environment variable or the C<implementation>
attribute to force it use an idle watcher instead.  Patches for detecting
environments where idle watchers should be used are welcome and
encouraged.

The pure perl implementation that comes with Perl
(L<AnyEvent::Impl::Perl>) does not seem to work with this module
on Microsoft Windows so I make L<EV> a prereq on that platform 
(which does work).

Writing to a subprocesses stdin via L<AnyEvent::Open3::Simple::Process>'s
C<print> method is unsupported on Microsoft Windows (it does work under
Cygwin though).

There are some traps for the unwary relating to buffers and deadlocks,
L<IPC::Open3> is recommended reading.

If you register a call back for C<on_exit>, but not C<on_error> then
use a condition variable to wait for the process to complete as in
this:

 my $cv = AnyEvent->condvar;
 my $ipc = AnyEvent::Open3::Simple->new(
   on_exit => sub { $cv->send },
 );
 $ipc->run('command_not_found');
 $cv->recv;

You might be waiting forever if there is an error starting the
process (if for example you give it a bad command).  To handle
this situation you might use croak on the condition variable
in the event of error:

 my $cv = AnyEvent->condvar;
 my $ipc = AnyEvent::Open3::Simple->new(
   on_exit => sub { $cv->send },
   on_error => sub {
     my $error = shift;
     $cv->croak($error);
   },
 );
 $ipc->run('command_not_found');
 $cv->recv;

This will cause the C<recv> to die, printing a useful diagnostic
if the exception isn't caught somewhere else.

=head1 SEE ALSO

L<AnyEvent::Subprocess>, L<AnyEvent::Util>, L<AnyEvent::Run>.

=cut
