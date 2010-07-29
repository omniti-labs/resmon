package Resmon::Module::DATE;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  return "OK(".time().")";
}

1;
