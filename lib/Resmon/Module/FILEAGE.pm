package Resmon::Module::FILEAGE;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $file = $arg->{'object'};
  my @statinfo = stat($file);
  my $age = time() - $statinfo[9];
  return "BAD($age seconds, too old)"
        if($arg->{maximum} && ($age > $arg->{maximum}));
  return "BAD($age seconds, too new)"
        if($arg->{minimum} && ($age > $arg->{minimum}));
  return "OK($age seconds)";
}
1;
