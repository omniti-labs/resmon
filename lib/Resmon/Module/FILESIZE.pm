package Resmon::Module::FILESIZE;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $file = $arg->{'object'};
  my @statinfo = stat($file);
  my $size = $statinfo[7];
  my $minsize = $arg->{minimum};
  my $maxsize = $arg->{maximum};
  return $arg->set_status("BAD(too big, $size > $maxsize)")
        if($maxsize && ($size > $maxsize));
  return $arg->set_status("BAD(too small, $size < $minsize)")
        if($minsize && ($size > $minsize));
  return $arg->set_status("OK($size)");
}
1;
