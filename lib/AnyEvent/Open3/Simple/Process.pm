package AnyEvent::Open3::Simple::Process;

use strict;
use warnings;
use Carp qw( croak );

# ABSTRACT: process run using AnyEvent::Open3::Simple
# VERSION

=head1 DESCRIPTION

This class represents a process being handled by L<AnyEvent::Open3::Simple>.

=cut

sub new
{
  my($class, $pid, $stdin) = @_;
  bless { pid => $pid, stdin => $stdin, user => '' }, $class;
}

=head1 ATTRIBUTES

=head2 pid

 my $pid = $proc->pid;

Return the Process ID of the child process.

=cut

sub pid { shift->{pid} }

=head1 METHODS

=head2 print

 $proc->print(@data);

Write to the subprocess' stdin.

Be careful to use either the C<stdin> attribute on the L<AnyEvent::Open::Simple>
object or this C<print> methods for a given instance of L<AnyEvent::Open3::Simple>,
but not both!  Otherwise bad things may happen.

Currently on (non cygwin) Windows (Strawberry, ActiveState) this method is not
supported, so if you need to send (standard) input to the subprocess, use the
C<stdin> attribute on the L<AnyEvent::Open::Simple> constructor.

=cut

sub print
{
  my $stdin = shift->{stdin};
  croak "AnyEvent::Open3::Simple::Process#print is unsupported on this platform"
    if $^O eq 'MSWin32';
  print $stdin @_;
}

=head2 say

 $proc->say(@data);

Write to the subprocess' stdin, adding a new line at the end.  This functionality
is unsupported on Microsoft Windows.

Be careful to use either the C<stdin> attribute on the L<AnyEvent::Open::Simple>
object or this C<say> methods for a given instance of L<AnyEvent::Open3::Simple>,
but not both!  Otherwise bad things may happen.

Currently on (non cygwin) Windows (Strawberry, ActiveState) this method is not
supported, so if you need to send (standard) input to the subprocess, use the
C<stdin> attribute on the L<AnyEvent::Open::Simple> constructor.

=cut

sub say
{
  shift->print(@_, "\n");
}

=head2 close

 $proc->close

Close the subprocess' stdin.

=cut

sub close
{
  CORE::close(shift->{stdin});
}

=head2 user

Version 0.77

 $proc->user($user_data);
 my $user_data = $proc->user;

Get or set user defined data tied to the process object.  Any
Perl data structure may be used.  Useful for persisting data 
between callbacks, for example:

 AnyEvent::Open3::Simple->new(
   on_start => sub {
     my($proc) = @_;
     $proc->user({ message => 'hello there' });
   },
   on_stdout => sub {
     my($proc) = @_;
     say $proc->user->{message};
   },
 );

=cut

sub user
{
  my($self, $data) = @_;
  $self->{user} = $data if defined $data;
  $self->{user};
}

1;
