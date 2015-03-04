package My::ModuleBuild;

use strict;
use warnings;
use 5.006;
use base qw( Module::Build );

sub new
{
  my($class, %args) = @_;
  
  if($^O eq 'MSWin32')
  {
    if(eval q{ use 5.020; 1 })
    {
      $args{requires}->{Event} = 0;
    }
    else
    {
      $args{requires}->{EV} = 0;
    }
  }
  
  my $self = $class->SUPER::new(%args);
  $self;
}

1;
