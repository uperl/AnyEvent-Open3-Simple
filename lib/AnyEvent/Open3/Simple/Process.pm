package main;

use strict;
use warnings;
use v5.10;
use mop;

# ABSTRACT: process run using AnyEvent::Open3::Simple
# VERSION

class AnyEvent::Open3::Simple::Process {

=head1 DESCRIPTION

This class represents a process being handled by L<AnyEvent::Open3::Simple>.

=head1 METHODS

=head2 $proc-E<gt>pid

Return the Process ID of the child process.

=cut

  has $pid is ro = die '$pid is required';
  has $stdin is ro = die '$stind is required';

=head2 $proc-E<gt>print( @data )

Write to the subprocess' stdin.

=cut

  method print
  {
    print $stdin @_;
  }

=head2 $proc-E<gt>say( @data )

Write to the subprocess' stdin, adding a new line at the end.

=cut

  method say
  {
    $self->print(@_, "\n");
  }

=head2 $proc-E<gt>close

Close the subprocess' stdin.

=cut

  method close
  {
    CORE::close($stdin);
  }

}

1;
