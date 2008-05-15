package Resmon::Module::DATE;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $arg->set_status("OK(".time().")");
}

1;
