package Resmon::Module::LARGEFILES;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $dir = $arg->{'object'};
  opendir(DIR, $dir);
  my @bigfiles = grep { my @fileinfo = stat; $fileinfo[7] > $arg->{'limit'} } readdir(DIR);
  closedir(DIR);
  if (scalar(@bigfiles) > 0) {
    return $arg->set_status("BAD(large files exist)");
  } else {
    return $arg->set_status("OK(no large files)");
  }
}

1;
