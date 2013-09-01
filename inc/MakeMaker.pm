package inc::MakeMaker;

use Moose;
use namespace::autoclean;
use v5.10;

with 'Dist::Zilla::Role::InstallTool';

sub setup_installer
{
  my($self) = @_;
  
  my($makefile) = grep { $_->name eq 'Makefile.PL' } @{ $self->zilla->files };
  
  my $content = $makefile->content;
  
  if($content =~ s{\t}{ }g)
  {
    $makefile->content($content);
    $self->zilla->log("replace tabs with spaces in Makefile.PL");
  }
  else
  {
    $self->zilla->log("no tabs in Makefile.PL");
  }
}
