#!/usr/bin/env perl

use lib './t'; # For locating ResmonTest

use Test::Harness;
runtests(glob("t/*.t"));
