use inc::Module::Install;

name     'DBIx-Class-Tree-MaterializedPath';
all_from 'lib/DBIx/Class/Tree/MaterializedPath.pm';
author   'Norbert Buchmüller <norbi@nix.hu>';
license  'perl';

requires 'DBIx::Class' => 0.08107;

build_requires 'Test::More';

auto_install;

WriteAll;

