use Test::More tests => 1;

use POSIX qw(strftime);

use ResmonTest;

my $module = ResmonTest::load_module('Core::Sample', 'foo',
    'arg1' => 'bar',
    'arg2' => 'baz');

my $results = $module->handler();

is_deeply($results,
    {
        "check_name" => ["foo", "s"],
        "arg1" => ["bar", "s"],
        "arg2" => ["baz", "s"],
        "date" => [strftime("%d", localtime), "i"]
    },
    'Core::Sample metrics'
);
