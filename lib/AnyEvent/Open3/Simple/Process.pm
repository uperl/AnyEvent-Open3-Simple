package AnyEvent::Open3::Simple::Process;

use strict;
use warnings;
use v5.10;
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

=head2 $proc-E<gt>pid

Return the Process ID of the child process.

=cut

sub pid { shift->{pid} }

=head1 METHODS

=head2 $proc-E<gt>print( @data )

Write to the subprocess' stdin.  This functionality is unsupported on Microsoft
Windows.

=cut

sub print
{
  my $stdin = shift->{stdin};
  croak "AnyEvent::Open3::Simple::Process#print is unsupported on this platform"
    if $^O eq 'MSWin32';
  print $stdin @_;
}

=head2 $proc-E<gt>say( @data )

Write to the subprocess' stdin, adding a new line at the end.

=cut

sub say
{
  shift->print(@_, "\n");
}

=head2 $proc-E<gt>close

Close the subprocess' stdin.

=cut

sub close
{
  CORE::close(shift->{stdin});
}

1;
