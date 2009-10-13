#!perl -T

use Test::Most;

BEGIN {
	use_ok( 'DBIx::Class::Tree::MaterializedPath' );
}

diag( "Testing DBIx::Class::Tree::MaterializedPath $DBIx::Class::Tree::MaterializedPath::VERSION, Perl $], $^X" );

done_testing;
