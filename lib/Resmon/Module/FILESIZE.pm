package Resmon::Module::FILESIZE;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $file = $arg->{'object'};
  my @statinfo = stat($file);
  my $size = $statinfo[7];
  my $minsize = $arg->{minimum};
  my $maxsize = $arg->{maximum};
  return "BAD($size, too big)"
        if($maxsize && ($size > $maxsize));
  return "BAD($size, too small)"
        if($minsize && ($size > $minsize));
  return "OK($size)";
}
1;
