package Resmon::Module::LARGEFILES;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $dir = $arg->{'object'};
  opendir(DIR, $dir);
  my @bigfiles = grep { my @fileinfo = stat; $fileinfo[7] > $arg->{'limit'} } readdir(DIR);
  closedir(DIR);
  if (scalar(@bigfiles) > 0) {
    return "BAD(large files exist)";
  } else {
    return "OK(no large files)";
  }
}

1;
