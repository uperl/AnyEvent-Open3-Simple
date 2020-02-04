# AnyEvent::Open3::Simple [![Build Status](https://secure.travis-ci.org/plicease/AnyEvent-Open3-Simple.png)](http://travis-ci.org/plicease/AnyEvent-Open3-Simple) [![Build status](https://ci.appveyor.com/api/projects/status/hbsdj04dds4oy6wo/branch/master?svg=true)](https://ci.appveyor.com/project/plicease/AnyEvent-Open3-Simple/branch/master) ![windows](https://github.com/plicease/AnyEvent-Open3-Simple/workflows/windows/badge.svg) ![macos](https://github.com/plicease/AnyEvent-Open3-Simple/workflows/macos/badge.svg)

Interface to open3 under AnyEvent

# SYNOPSIS

```perl
use 5.010;
use AnyEvent;
use AnyEvent::Open3::Simple;

my $done = AnyEvent->condvar;

my $ipc = AnyEvent::Open3::Simple->new(
  on_start => sub {
    my $proc = shift;       # isa AnyEvent::Open3::Simple::Process
    my $program = shift;    # string
    my @args = @_;          # list of arguments
    say 'child PID: ', $proc->pid;
  },
  on_stdout => sub {
    my $proc = shift;       # isa AnyEvent::Open3::Simple::Process
    my $line = shift;       # string
    say 'out: ', $string;
  },
  on_stderr => sub {
    my $proc = shift;       # isa AnyEvent::Open3::Simple::Process
    my $line = shift;       # string
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
    my $program = shift;    # string
    my @args = @_;          # list of arguments
    warn "error: $error";
    $done->send;
  },
);

$ipc->run('echo', 'hello there');
$done->recv;
```

# DESCRIPTION

This module provides an interface to open3 while running under AnyEvent
that delivers data from stdout and stderr as lines are written by the
subprocess.  The interface is reminiscent of [IPC::Open3::Simple](https://metacpan.org/pod/IPC::Open3::Simple),
although this module does provides a somewhat different API, so it
cannot be used a drop in replacement for that module.

There are already a number of interfaces for interacting with subprocesses
in the context of [AnyEvent](https://metacpan.org/pod/AnyEvent), but this one is the most convenient for my
usage.  Note the modules listed in the SEE ALSO section below for other
interfaces that may be more or less appropriate.

# CONSTRUCTOR

Constructor takes a hash or hashref of event callbacks and attributes.
Event callbacks have an `on_` prefix, attributes do not.

## ATTRIBUTES

- implementation

    The implementation to use for detecting process termination.  This should
    be one of `child`, `idle` or `mojo`.  On all platforms except for Microsoft
    Windows (but not Cygwin) the default is `child`.

    You can change the default by setting the `ANYEVENT_OPEN3_SIMPLE`
    environment variable, like this:

    ```
    % export ANYEVENT_OPEN3_SIMPLE=idle
    ```

    The `mojo` implementation is experimental and allows you to use
    [AnyEvent::Open3::Simple](https://metacpan.org/pod/AnyEvent::Open3::Simple) with [Mojolicious](https://metacpan.org/pod/Mojolicious) but without [EV](https://metacpan.org/pod/EV)
    (which is usually required for [AnyEvent](https://metacpan.org/pod/AnyEvent), [Mojolicious](https://metacpan.org/pod/Mojolicious) interaction).

## EVENTS

These events will be triggered by the subprocess when the run method is
called. Each event callback (except `on_error`) gets passed in an
instance of [AnyEvent::Open3::Simple::Process](https://metacpan.org/pod/AnyEvent::Open3::Simple::Process) as its first argument
which can be used to get the PID of the subprocess, or to write to it.
`on_error` does not get a process object because it indicates an error in
the creation of the process.

Not all of these events will fire depending on the execution of the
child process.  In the very least exactly one of `on_start` or `on_error`
will be called.

- `on_start` ($proc, $program, @arguments)

    Called after the process is created, but before the run method returns
    (that is, it does not wait to re-enter the event loop first).

    In versions 0.78 and better, this event also gets the program name
    and arguments passed into the [run](https://metacpan.org/pod/AnyEvent::Open3::Simple#run)
    method.

- `on_error` ($error, $program, @arguments)

    Called when there is an execution error, for example, if you ask
    to run a program that does not exist.  No process is passed in
    because the process failed to create.  The error passed in is
    the error thrown by [IPC::Open3](https://metacpan.org/pod/IPC::Open3) (typically a string which begins
    with "open3: ...").

    In some environments open3 is unable to detect exec errors in the
    child, so you may not be able to rely on this event.  It does
    seem to work consistently on Perl 5.14 or better though.

    Different environments have different ways of handling it when
    you ask to run a program that doesn't exist.  On Linux and Cygwin,
    this will raise an `on_error` event, on `MSWin32` it will
    not trigger a `on_error` and instead cause a normal exit
    with a exit value of 1.

    In versions 0.77 and better, this event also gets the program name
    and arguments passed into the [run](https://metacpan.org/pod/AnyEvent::Open3::Simple#run)
    method.

- `on_stdout` ($proc, $line)

    Called on every line printed to stdout by the child process.

- `on_stderr` ($proc, $line)

    Called on every line printed to stderr by the child process.

- `on_exit` ($proc, $exit\_value, $signal)

    Called when the processes completes, either because it called exit,
    or if it was killed by a signal.

- `on_success` ($proc)

    Called when the process returns zero exit value and is not terminated by a signal.

- `on_signal` ($proc, $signal)

    Called when the processes is terminated by a signal.

- `on_fail` ($proc, $exit\_value)

    Called when the process returns a non-zero exit value.

# METHODS

## run

```perl
$ipc->run($program, @arguments);
$ipc->run($program, @arguments, \$stdin);             # (version 0.76)
$ipc->run($program, @arguments, \@stdin);             # (version 0.76)
$ipc->run($program, @arguments, sub {...});           # (version 0.80)
$ipc->run($program, @arguments, \$stdin, sub {...});  # (version 0.80)
$ipc->run($program, @arguments, \@stdin, sub {...});  # (version 0.80)
```

Start the given program with the given arguments.  Returns
immediately.  Any events that have been specified in the
constructor (except for `on_start`) will not be called until
the process re-enters the event loop.

You may optionally provide the full content of standard input
as a string reference or list reference as the last argument
(or second to last if you are providing a callback below).
If provided as a list reference, it will be joined by new lines
in whatever format is native to your Perl.  Currently on
(non cygwin) Windows (Strawberry, ActiveState) this is the only
way to provide standard input to the subprocess.

Do not mix the use of passing standard input to [run](https://metacpan.org/pod/AnyEvent::Open3::Simple#run)
and [AnyEvent::Open3::Simple::Process#print](https://metacpan.org/pod/AnyEvent::Open3::Simple::Process#print) or [AnyEvent::Open3::Simple::Process#say](https://metacpan.org/pod/AnyEvent::Open3::Simple::Process#say),
otherwise bad things may happen.

In version 0.80 or better, you may provide a callback as the last argument
which is called before `on_start`, and takes the process object as its only
argument.  For example:

```perl
foreach my $i (1..10)
{
  $ipc->run($prog, @args, \$stdin, sub {
    my($proc) = @_;
    $proc->user({ iteration => $i });
  });
}
```

This is useful for making data accessible to `$ipc` object's callbacks that may
be out of scope otherwise.

# CAVEATS

Some AnyEvent implementations may not work properly with the method
used by AnyEvent::Open3::Simple to wait for the child process to
terminate.  See ["CHILD-PROCESS-WATCHERS" in AnyEvent](https://metacpan.org/pod/AnyEvent#CHILD-PROCESS-WATCHERS) for details.

This module uses an idle watcher instead of a child watcher to detect
program termination on Microsoft Windows (but not Cygwin).  This is
because the child watchers are unsupported by AnyEvent on Windows.
The idle watcher implementation seems to pass the test suite, but there
may be some traps for the unwary.  There may be other platforms or
event loops where this is the appropriate choice, and you can use the
`ANYEVENT_OPEN3_SIMPLE` environment variable or the `implementation`
attribute to force it use an idle watcher instead.  Patches for detecting
environments where idle watchers should be used are welcome and
encouraged.

As of version 0.85, this module works on Windows with [AnyEvent::Impl::EV](https://metacpan.org/pod/AnyEvent::Impl::EV),
[AnyEvent::Impl::Event](https://metacpan.org/pod/AnyEvent::Impl::Event) and [AnyEvent::Impl::Perl](https://metacpan.org/pod/AnyEvent::Impl::Perl) (possibly others),
although in the past they have either not worked or had limitations placed
on them.  Because the author of [AnyEvent](https://metacpan.org/pod/AnyEvent) does not hold the native Windows
port of Perl in high regard problems such as this may pop up again
in the future and may not be addressed, and may be out of the control of the
author of this module.

Performance for the idle watcher implementation on native Windows (non-Cygwin)
is almost certainly suboptimal, but the author of this module uses it
and finds it useful despite this.

Writing to a subprocesses stdin with [AnyEvent::Open3::Simple::Process#print](https://metacpan.org/pod/AnyEvent::Open3::Simple::Process#print)
or [AnyEvent::Open3::Simple::Process#say](https://metacpan.org/pod/AnyEvent::Open3::Simple::Process#say) is unsupported on Microsoft
Windows (it does work under Cygwin though).

There are some traps for the unwary relating to buffers and deadlocks,
[IPC::Open3](https://metacpan.org/pod/IPC::Open3) is recommended reading.

If you register a call back for `on_exit`, but not `on_error` then
use a condition variable to wait for the process to complete as in
this:

```perl
my $cv = AnyEvent->condvar;
my $ipc = AnyEvent::Open3::Simple->new(
  on_exit => sub { $cv->send },
);
$ipc->run('command_not_found');
$cv->recv;
```

You might be waiting forever if there is an error starting the
process (if for example you give it a bad command).  To handle
this situation you might use croak on the condition variable
in the event of error:

```perl
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
```

This will cause the `recv` to die, printing a useful diagnostic
if the exception isn't caught somewhere else.

# SEE ALSO

[AnyEvent::Subprocess](https://metacpan.org/pod/AnyEvent::Subprocess), [AnyEvent::Util](https://metacpan.org/pod/AnyEvent::Util), [AnyEvent::Run](https://metacpan.org/pod/AnyEvent::Run).

# AUTHOR

Author: Graham Ollis <plicease@cpan.org>

Contributors:

Stephen R. Scaffidi

Scott Wiersdorf

# COPYRIGHT AND LICENSE

This software is copyright (c) 2012-2019 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
