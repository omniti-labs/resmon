use Test::More tests => 11;
use File::Temp;

use POSIX qw(strftime);

use ResmonTest;

my ($fh, $filename) = File::Temp::tempfile(UNLINK => 1);

my $module = ResmonTest::load_module('Core::File', $filename);

my $results = $module->handler();

is_deeply($results->{present}, [1, "i"], "File present");
is_deeply($results->{size}, [0, "i"], "File size is 0");
is_deeply($results->{hardlinks}, [1, "i"], "Hard link count");
is_deeply($results->{atime}, $results->{"mtime"}, "atime == mtime");
is_deeply($results->{"mtime"}, $results->{ctime}, "mtime == ctime");
is_deeply($results->{aage}, $results->{mage}, "aage == mage");
is_deeply($results->{mage}, $results->{cage}, "mage == cage");
ok($results->{mage}[0] < 10, "File is less than 10 seconds old");
is_deeply($results->{uid}, [$>, "s"], "File UID is the current UID");
my @groups = split(/ /, $));
is_deeply($results->{gid}, [$groups[0], "s"],
    "File GID is the current GID");
is_deeply($results->{permissions}, ["0600", "s"], "File permissions");
