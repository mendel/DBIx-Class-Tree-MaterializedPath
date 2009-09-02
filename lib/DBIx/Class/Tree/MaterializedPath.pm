package DBIx::Class::Tree::MaterializedPath;

#TODO tests
# * set up SQLite environment
# * import a set of rows with known paths (1, 1.1, 1.2, 1.2.1, 1.2.2, 1.2.3, 1.2.3.1, 1.3) and check all possible relationship getters (->parent(), ->parents(), ->children(), ->ancestors(), ->descendants(), ->siblings(), ->is_root, ->is_branch, ->is_leaf)
# * test all methods altering the tree (first alter, then check relationships) - create a sub that creates the fixture and recreate the fixture before each modification test
#TODO document that the interface is compatible to DBIx::Class::Tree::AdjacencyList
#TODO document methods

use warnings;
use strict;

use base qw(DBIx::Class);

=head1 NAME

DBIx::Class::Tree::MaterializedPath - The great new DBIx::Class::Tree::MaterializedPath!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use DBIx::Class::Tree::MaterializedPath;

    my $foo = DBIx::Class::Tree::MaterializedPath->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=cut

=head1 FUNCTIONS

=head2 path_column

=cut

__PACKAGE__->mk_classdata(path_column => 'parent_id');


=head2 repair_tree

=cut

__PACKAGE__->mk_classdata(repair_tree => 0);


=head2 parent

=cut

sub parent
{
  my ($self) = (shift, @_);

  return $self->parents->first;
}

=head2 has_descendant

=cut

sub has_descendant
{
  my ($self) = (shift, @_);

  return $self->parents->count != 0;
}

=head2 parents

=cut

sub parents
{
  my ($self, @parents) = (shift, @_);

  #FIXME
}

=head2 ancestors

Direct and indirect parents.

=cut

sub ancestors
{
  my ($self, @ancestors) = (shift, @_);

  my @path_nodes = split /\./, $self->_path;
  my @parent_paths = map {
    join('.', $path_nodes[0..$_])
  } 0..$#path_nodes;

  my $rs = $self->result_source->resultset;

  if (@_) {
    #FIXME
  } else {
    return $rs->search(
      {
        $self->_qualified_path_column($rs) => { -in => \@parent_paths },
      }
    );
  }
}

=head2 children

=cut

sub children
{
  my ($self, @children) = (shift, @_);

  #FIXME
}


=head2 descendants

Direct and indirect children.

=cut

sub descendants
{
  my ($self, @descendants) = (shift, @_);

  my $dbh = $self->result_source->schema->storage->dbh;

  my $rs = $self->result_source->resultset;

  if (@_) {
    #FIXME
  } else {
    # note that we cannot use placeholders as we want it to be an index scan
    return $rs->search(
      {
        $self->_qualified_path_column($rs) =>
          { -like => [ $dbh->quote($self->_path . '.%') ] },
      }
    );
  }
}

=head2 attach_child

=cut

sub attach_child
{
  my ($self) = (shift, @_);
}

=head2 siblings

=cut

sub siblings
{
  my ($self) = (shift, @_);
}

=head2 attach_sibling

=cut

sub attach_sibling
{
  my ($self) = (shift, @_);
}

=head2 is_leaf

=cut

sub is_leaf
{
  my ($self) = (shift, @_);
}

=head2 is_root

=cut

sub is_root
{
  my ($self) = (shift, @_);
}

=head2 is_branch

=cut

sub is_branch
{
  my ($self) = (shift, @_);
}

=head2 set_primary_key 

=cut

sub set_primary_key
{
  my ($self) = (shift, @_);

  $self->next::method(@_);
}

sub _path
{
  my ($self, $path) = (shift, @_);

  if (@_) {
    $self->update({
      $self->_qualified_path_column => $path,
    });
    return $path;
  } else {
    return $self->get_column($self->path_column);
  }
}

sub _qualified_path_column
{
  my ($self, $rs) = (shift, @_);

  return sprintf('%s.%s', $rs->current_source_alias, $self->path_column);
}

=head1 AUTHOR

Norbert Buchmüller, C<< <norbi at nix.hu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-dbix-class-tree-materializedpath at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBIx-Class-Tree-MaterializedPath>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DBIx::Class::Tree::MaterializedPath


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DBIx-Class-Tree-MaterializedPath>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DBIx-Class-Tree-MaterializedPath>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DBIx-Class-Tree-MaterializedPath>

=item * Search CPAN

L<http://search.cpan.org/dist/DBIx-Class-Tree-MaterializedPath/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Norbert Buchmüller, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of DBIx::Class::Tree::MaterializedPath
