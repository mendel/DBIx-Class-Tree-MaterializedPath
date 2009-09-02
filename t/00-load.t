#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'DBIx::Class::Tree::MaterializedPath' );
}

diag( "Testing DBIx::Class::Tree::MaterializedPath $DBIx::Class::Tree::MaterializedPath::VERSION, Perl $], $^X" );
