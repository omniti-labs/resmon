use Test::More tests => 13;

use POSIX qw(strftime);

use File::Temp;

use ResmonTest;

my $dirname = File::Temp::tempdir(CLEANUP => 1);

my $module;
my $results;

$module = ResmonTest::load_module('Core::FileCount', "$dirname");
$results = $module->handler();
is_deeply($results, { "count" => [0, "i"] }, "Empty Directory, no filters");

open(FH, ">$dirname/foo"); close(FH);
$results = $module->handler();
is_deeply($results, { "count" => [1, "i"] }, "One file, no filters");

open(FH, ">$dirname/bar"); close(FH);
$results = $module->handler();
is_deeply($results, { "count" => [2, "i"] }, "Two files, no filters");

$module = ResmonTest::load_module('Core::FileCount', "$dirname",
    "filename" => "ba");
$results = $module->handler();
is_deeply($results, { "count" => [1, "i"] }, "Filename filter: ba (bar)");

open(FH, ">$dirname/baz"); close(FH);
$results = $module->handler();
is_deeply($results, { "count" => [2, "i"] }, "Filename filter: ba (bar, baz)");

my $now = time;
my $then = $now - 300;
utime $then, $then, "$dirname/baz";

$module = ResmonTest::load_module('Core::FileCount', "$dirname",
    "min_modified" => "150");
$results = $module->handler();
is_deeply($results, { "count" => [1, "i"] }, "min_modified - 1 file");

utime $then, $then, "$dirname/bar";
$results = $module->handler();
is_deeply($results, { "count" => [2, "i"] }, "min_modified - 2 files");

$module = ResmonTest::load_module('Core::FileCount', "$dirname",
    "max_modified" => "150");
$results = $module->handler();
is_deeply($results, { "count" => [1, "i"] }, "max_modified - 1 file");
utime $now, $now, "$dirname/baz";

$module = ResmonTest::load_module('Core::FileCount', "$dirname",
    "min_size" => "1");
$results = $module->handler();
is_deeply($results, { "count" => [0, "i"] }, "min_size - 0 files");

open(FH, ">$dirname/foo"); print FH "foobar\n"; close(FH);
$results = $module->handler();
is_deeply($results, { "count" => [1, "i"] }, "min_size - 1 file");

$module = ResmonTest::load_module('Core::FileCount', "$dirname",
    "max_size" => "1");
$results = $module->handler();
is_deeply($results, { "count" => [2, "i"] }, "max_size - 2 files");

$module = ResmonTest::load_module('Core::FileCount', "$dirname",
    "permissions" => "06[04][04]");
$results = $module->handler();
is_deeply($results, { "count" => [3, "i"] }, "permissions - 3 files");

chmod 0666, "$dirname/foo";
$results = $module->handler();
is_deeply($results, { "count" => [2, "i"] }, "permissions - 2 files");

# Unable to test uid/gid without root access
