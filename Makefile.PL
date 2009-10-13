use inc::Module::Install;

name     'DBIx-Class-Tree-MaterializedPath';
all_from 'lib/DBIx/Class/Tree/MaterializedPath.pm';
author   'Norbert Buchmüller <norbi@nix.hu>';
license  'perl';

requires 'DBIx::Class' => '0.08107';
requires 'Scalar::Util' => '1.19';
requires 'List::MoreUtils' => '0.22';
requires 'namespace::clean' => '0.11';

build_requires 'Test::More';

auto_install;

WriteAll;
