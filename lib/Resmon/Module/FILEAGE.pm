package Resmon::Module::FILEAGE;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $file = $arg->{'object'};
  my @statinfo = stat($file);
  my $age = time() - $statinfo[9];
  return $arg->set_status("BAD(too old $age seconds)")
        if($arg->{maximum} && ($age > $arg->{maximum}));
  return $arg->set_status("BAD(too new $age seconds)")
        if($arg->{minimum} && ($age > $arg->{minimum}));
  return $arg->set_status("OK($age)");
}
1;
