#!/usr/bin/env perl

use strict;
use warnings;

use inc::Module::Install 0.91;

name     'DBIx-Class-Tree-MaterializedPath';
all_from 'lib/DBIx/Class/Tree/MaterializedPath.pm';
readme_from 'lib/DBIx/Class/Tree/MaterializedPath.pm';
auto_set_repository;

requires 'DBIx::Class' => '0.08107';
requires 'Scalar::Util' => '1.19';
requires 'List::MoreUtils' => '0.22';
requires 'namespace::clean' => '0.11';

test_requires 'Test::Most' => '0.21';
test_requires 'Test::More' => '0.92';
test_requires 'Test::Differences' => '0.4801';
test_requires 'Test::Deep' => '0.103';
test_requires 'Test::Warn' => '0.21';
test_requires 'Test::Exception' => '0.27';

author_requires 'Test::Pod' => '1.22';
author_requires 'Test::Pod::Coverage' => '1.08';
author_requires 'Pod::Coverage' => '0.18';
author_requires 'Module::Install::ExtraTests' => '0.006';
author_requires 'Module::Install::ReadmeFromPod' => '0.06';
author_requires 'Module::Install::AuthorRequires' => '0.02';
author_requires 'Module::Install::Repository' => '0.06';

extra_tests;

auto_install;

WriteAll;
