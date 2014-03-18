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
  bless { pid => $pid, stdin => $stdin }, $class;
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

1;
