package DBIx::Class::Tree::MaterializedPath;

#TODO write DESCRIPTION (describe MP model and it's performance, mention that there can be more than one root nodes, root nodes have 0 as the parent, the id is usually an integer, ...)
#TODO override ->insert to set the MP
#TODO tests
# * set up SQLite environment
# * import a set of rows with known paths (1, 1.1, 1.2, 1.2.1, 1.2.2, 1.2.3, 1.2.3.1, 1.3) and check all possible relationship getters (->parent(), ->parents(), ->children(), ->ancestors(), ->descendants(), ->siblings(), ->is_root, ->is_branch, ->is_leaf)
# * test all methods altering the tree (first alter, then check relationships) - create a sub that creates the fixture and recreate the fixture before each modification test
# * test that all the other rows did not change (ie. no unwanted side-effects)
#TODO document that the interface is compatible to DBIx::Class::Tree::AdjacencyList

use warnings;
use strict;

use 5.005;

use base qw(DBIx::Class);

use Scalar::Util qw(blessed looks_like_number);
use List::MoreUtils qw(any);

use namespace::clean;

=head1 NAME

DBIx::Class::Tree::MaterializedPath - DBIx::Class plugin for storing tree data in the materialized path model

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Set up the node result class:

  package MyApp::Schema::Node;

  __PACKAGE__->load_components(qw(
    Tree::MaterializedPath
    # ...
  ));

  __PACKAGE__->add_columns(
    node_id => {
      data_type => 'integer',
      is_nullable => 0,
      is_auto_increment => 1,
    },
    materialized_path => {
      data_type => 'text',    # make sure all your MPs fit into it!
      is_nullable => 0,
    },
    depth => {
      data_type => 'integer',
      is_nullable => 0,
    },
    # ...
  );

  __PACKAGE__->set_primary_key('node_id');

  __PACKAGE__->materialized_path_column('materialized_path'); # or use the default
  __PACKAGE__->materialized_path_depth_column('depth');       # or use the default
  __PACKAGE__->materialized_path_separator('.');              # or use the default

Now you can use the tree much like with L<DBIx::Class::Tree::AdjacencyList>
(except that it scales better for most workloads:-).

  use MyApp::Schema::Node;

  my $node = MyApp::Schema::Node->create({ ... });

  my $children_rs = $employee->children;
  my @siblings = $employee->children;

  my $parent = $employee->parent;
  $employee->parent(7);

=head1 DESCRIPTION

FIXME

=head1 METHODS

=cut

=head2 $class->materialized_path_column([$column_name])

Gets/sets the column name where the materialized path is stored.

Default: 'materialized_path'

=cut

__PACKAGE__->mk_classdata(materialized_path_column => 'materialized_path');


=head2 $class->materialized_path_separator([$separator_string])

Gets/sets the separator string (usually a character) in the materialized path.

Default: '.'

=cut

__PACKAGE__->mk_classdata(materialized_path_separator => '.');

=head2 $class->materialized_path_depth_column([$depth_column])

Gets/sets the name of the column where the depth of the node from the root node
is stored.

This column is redundant (the information can be extracted from the
materialized path column), but it pays back as it gives the possibility to use
indexes on the depth. (In fact, the materialized path model already contains
redundancy, trading it off for performance.)

Default: 'depth'

=cut

__PACKAGE__->mk_classdata(materialized_path_depth_column => 'depth');


=head2 $node->parent([$parent_node])

=head2 $node->parent([$parent_id])

Gets/sets the parent node. (Setting the parent node means moving the node and
all its children.)

If C<$parent_id> is C<undef> or 0, it will make C<$node> a root node.

Returns: $parent_node | on setting: 0 if C<$parent_node> is already the parent of C<$node>, 1 otherwise

=cut

sub parent
{
  my ($self, $parent_node) = (shift, @_);

  if (@_) {
    return $self->_set_parent($parent_node);
  } else {
    return $self->_get_parent();
  }
}

# $node->_get_parent()
# 
# Gets the parent node.
# 
# Returns: $parent_node
# 
sub _get_parent
{
  my ($self) = (shift, @_);

  my $parent_id = ($self->_materialized_path_elements)[-1];

  my $rs = $self->result_source->resultset;

  return $rs->find(
    {
      $self->_qualified_primary_key_column($rs) => $parent_id,
    }
  );
}

# $node->_set_parent([$parent_node])
# $node->_set_parent([$parent_id])
# 
# Sets the parent node.
#
# If C<$parent_id> is C<undef> or 0, it will make C<$node> a root node.
# 
# Returns: 0 if C<$parent_node> is already the parent of C<$node>, 1 otherwise
# 
sub _set_parent
{
  my ($self, $parent) = (shift, @_);

  if (!blessed $parent &&
    (!defined $parent || (looks_like_number($parent) && $parent == 0))
  ) {
    #FIXME extract this duplicated code into a method
    my $descendants_rs = $self->descendants;
    while (my $descendant = $descendants_rs->next) {
      my @former_parent_ids = $descendant->_materialized_path_elements;
      $descendant->_materialized_path_elements(
        @former_parent_ids[ -($descendant->_depth - $self->_depth) .. -1 ]
      );
    }

    $self->_materialized_path_elements(undef);

    return 1;
  }

  my $parent_node;
  if (blessed $parent) {
    $parent_node = $parent;
  } else {
    my $rs = $self->result_source->resultset;

    $parent_node = $rs->find({
        $self->_qualified_primary_key_column($rs) => $parent,
    }) or $self->throw_exception("Cannot find parent node by id (id: $parent)");
  }

  $self->throw_exception("Cannot make a node the parent of itself") if
    $parent_node->id == $self->id;

  $self->throw_exception("Cannot make a descendant node the parent of the node")
    if any { $_->id == $self->id } $self->descendants;

  return 0 if ($self->_materialized_path_elements)[-1] == $parent_node->id;

  my @new_grandparent_ids = $parent_node->_materialized_path_elements;

  my $descendants_rs = $self->descendants;
  while (my $descendant = $descendants_rs->next) {
    my @former_parent_ids = $descendant->_materialized_path_elements;
    $descendant->_materialized_path_elements(
      @new_grandparent_ids,
      @former_parent_ids[ -($descendant->_depth - $self->_depth) .. -1 ]
    );
  }

  $self->_materialized_path_elements(@new_grandparent_ids, $parent_node->id);

  return 1;
}


=head2 $node->has_descendant($node_id)

Returns true if C<$node> has a descendant with the given C<$node_id>.

Returns: $has_descendant

=cut

sub has_descendant
{
  my ($self, $node_id) = (shift, @_);

  my $rs = $self->descendants;

  my $descendant_rs = $rs->search(
    {
      $self->_qualified_primary_key_column($rs) => $node_id,
    },
    {
      rows => 1,
    }
  );

  return $descendant_rs->single ? 1 : 0;
}

=head2 $node->parents()

Returns a one-element resultset (in scalar context) or list (in list context)
that contains the parent node object.

Useful if you want to treat the tree as a DAG.

Returns: $parent_node

=cut

sub parents
{
  my ($self) = (shift, @_);

  if (wantarray) {
    return ($self->parent);
  } else {
    my $parent = $self->parent;

    my $rs = $self->result_source->resultset;

    return $rs->search(
      {
        $self->_qualified_primary_key_column($rs) => $parent->id,
      }
    );
  }
}

=head2 $node->ancestors()

Returns a resultset (in scalar context) or list (in list context) of the
ancestors (ie. direct and indirect parents) of C<$node>.

Returns: $ancestors_rs | @ancestors

=cut

sub ancestors
{
  my ($self) = (shift, @_);

  my @ancestor_ids = $self->_materialized_path_elements;

  my $rs = $self->result_source->resultset;

  return $rs->search(
    {
      $self->_qualified_primary_key_column($rs) => { -in => \@ancestor_ids },
    }
  );
}

=head2 $node->children()

Returns a resultset (in scalar context) or list (in list context) of (direct)
child node objects.

Returns: $children_rs | @children

=cut

sub children
{
  my ($self) = (shift, @_);

  my $rs = $self->descendants;

  return $rs->search(
    {
      $self->_qualified_depth_column($rs) => $self->_depth + 1,
    }
  );
}


=head2 $node->descendants()

Returns a resultset (in scalar context) or list (in list context) of
descendants (direct and indirect children) of C<$node>.

Returns: $descendants_rs | @descendants

=cut

sub descendants
{
  my ($self) = (shift, @_);

  my $dbh = $self->result_source->schema->storage->dbh;

  my $rs = $self->result_source->resultset;

  # note that we cannot use placeholders as we want it to be an index scan (so
  # the actual value of the RHS of LIKE must be known at query planning time)
  return $rs->search(
    {
      $self->_qualified_materialized_path_column($rs) => { -like =>
        $dbh->quote(
          $self->_materialized_path . $self->materialized_path_separator . '%'
        )
      },
    }
  );
}

=head2 $node->attach_child($child [, $child2, ...])

Attaches the nodes (C<$child, $child2, ...>) to C<$node>.

The child nodes (C<$child, $child2, ...>) can be node instances or primary key
values (in any combination).

Returns: 0 if $node is already the parent of any of $child, $child2, ..., 1 otherwise

=cut

sub attach_child
{
  my ($self, @children) = (shift, @_);

  foreach my $child (@children) {
    if (!blessed $child) {
      my $rs = $self->result_source->resultset;
      $child = $rs->find({
        $self->_qualified_primary_key_column($rs) => $child,
      }) or $self->throw_exception("Cannot find child node by id (id: $child)");
    }
  }

  $self->throw_exception("Cannot make a node the parent of itself") if
    any { $_->id == $self->id } @children;

  my @ancestor_ids = $self->_materialized_path_elements;
  foreach my $child (@children) {
    $self->throw_exception("Cannot make an ancestor node the child of the node")
      if any { $_ == $child->id } @ancestor_ids;
  }

  return 0 if
    any { ($_->_materialized_path_elements)[-1] == $self->id } @children;

  foreach my $child (@children) {
    $child->parent($self);
  }

  return 1;
}

=head2 $node->siblings()

Returns a resultset (in scalar context) or list (in list context) of
the siblings of C<$node>.

Returns: $siblings_rs | @siblings

=cut

sub siblings
{
  my ($self) = (shift, @_);

  my $rs = $self->result_source->resultset;

  return $rs->search(
    {
      $self->_qualified_materialized_path_column($rs) => $self->_materialized_path,
      $self->_qualified_primary_key_column($rs) => { '!=' => $self->id },
    }
  );
}

=head2 $node->attach_sibling($sibling [, $sibling2, ...])

Attaches the nodes (C<$sibling, $sibling2, ...>) to the parent of C<$node>.

The sibling nodes (C<$sibling, $sibling2, ...>) can be node instances or
primary key values (in any combination).

Returns: 0 if $node's parent is already the parent of any of the siblings, 1 otherwise

=cut

sub attach_sibling
{
  my ($self, @siblings) = (shift, @_);

  foreach my $sibling (@siblings) {
    if (!blessed $sibling) {
      my $rs = $self->result_source->resultset;
      $sibling = $rs->find({
        $self->_qualified_primary_key_column($rs) => $sibling,
      }) or $self->throw_exception("Cannot find sibling node by id (id: $sibling)");
    }
  }

  $self->throw_exception("Cannot make a node the sibling of itself") if
    any { $_->id == $self->id } @siblings;

  my @ancestor_ids = $self->_materialized_path_elements;
  foreach my $sibling (@siblings) {
    $self->throw_exception("Cannot make an ancestor node the sibling of the node")
      if any { $_ == $sibling->id } @ancestor_ids;
  }

  foreach my $sibling (@siblings) {
    $self->throw_exception("Cannot make a descendant node the sibling of the node")
      if any { $_->id == $sibling->id } $self->descendants
  }

  foreach my $sibling (@siblings) {
    $sibling->parent($self->parent);
  }

  return 1;
}

=head2 $node->is_leaf()

Returns true iff C<$node> is a leaf node (ie. it has no children).

Returns: $is_leaf

=cut

sub is_leaf
{
  my ($self) = (shift, @_);

  my $descendant_rs = $self->descendants->search(
    undef,
    {
      rows => 1,
    }
  );

  return $descendant_rs->single ? 1 : 0;
}

=head2 $node->is_root()

Returns true iff C<$node> is the root node (ie. it has no parent).

Returns: $is_root

=cut

sub is_root
{
  my ($self) = (shift, @_);

  return !$self->_materialized_path_elements;
}

=head2 $node->is_branch()

Returns true iff C<$node> has a parent and has children.

Returns: $is_branch

=cut

sub is_branch
{
  my ($self) = (shift, @_);

  return !$self->is_root && !$self->is_leaf;
}

=head2 $node->set_primary_key()

Overridden from L<DBIx::Class::ResultSource/set_primary_key> to check that the
primary key is one column.

=cut

sub set_primary_key
{
  my ($self, @pk_columns) = (shift, @_);

  $self->throw_exception(__PACKAGE__ . " does not work with multiple columns primary key")
    if @pk_columns > 1;

  return $self->next::method(@_);
}

# $node->_materialized_path()
#
# Read-only accessor for the materialized path column.
#
# Returns: $path
#
sub _materialized_path
{
  my ($self) = (shift, @_);

  return $self->${ \($self->materialized_path_column) };
}

# $node->_depth()
#
# Read-only accessor for the depth column.
#
# Returns: $path
#
sub _depth
{
  my ($self) = (shift, @_);

  return $self->${ \($self->materialized_path_depth_column) };
}

# $node->_qualified_column($rs, $column)
#
# Returns the C<$column> column name, qualified with the current result source
# alias of the C<$rs> resultset.
#
# Returns: $qualified_column
#
sub _qualified_column
{
  my ($self, $rs, $column) = (shift, @_);

  return sprintf('%s.%s',
    $rs->current_source_alias,
    $column
  );
}

# $node->_qualified_primary_key_column($rs)
#
# Returns the column name of the primary key, qualified with the current result
# source alias of the C<$rs> resultset.
#
# Returns: $qualified_primary_key_column
#
sub _qualified_primary_key_column
{
  my ($self, $rs) = (shift, @_);

  return $self->_qualified_column($rs,
    ($self->result_source->primary_columns)[0]
  );
}

# $node->_qualified_materialized_path_column($rs)
#
# Returns the column name of the materialized path column, qualified with the
# current result source alias of the C<$rs> resultset.
#
# Returns: $qualified_materialized_path_column
#
sub _qualified_materialized_path_column
{
  my ($self, $rs) = (shift, @_);

  return $self->_qualified_column($rs,
    $self->materialized_path_column
  );
}

# $node->_qualified_depth_column($rs)
#
# Returns the column name of the depth column, qualified with the current
# result source alias of the C<$rs> resultset.
#
# Returns: $qualified_depth_column
#
sub _qualified_depth_column
{
  my ($self, $rs) = (shift, @_);

  return $self->_qualified_column($rs,
    $self->materialized_path_depth_column
  );
}

# $node->_encode_materialized_path(@nodes)
#
# Builds the materialized path string for an ancestry of C<@nodes> (the first
# element of C<@nodes> is the root node, the last element is the parent of the
# actual node whose materialized path is being built).
#
# Each element of C<@nodes> is either a node object or the id of it.
#
# Returns: $materialized_path_string
#
sub _encode_materialized_path
{
  my ($self, @nodes) = (shift, @_);

  return join($self->materialized_path_separator,
    map { blessed $_ ? $_->id : $_ } @nodes
  );
}

# $node->_decode_materialized_path($materialized_path_string)
#
# Parses the materialized path string and returns the list of the ids of the
# corresponding nodes (the first element of C<@nodes> is the root node, the
# last element is the parent of the actual node whose materialized path is
# being parsed).
#
# Returns: @nodes
#
sub _decode_materialized_path
{
  my ($self, $materialized_path_string) = (shift, @_);

  return split quotemeta($self->materialized_path_separator),
    $materialized_path_string;
}

# $node->_materialized_path_elements([@node_ids])
#
# Get/set the list of materialized path as a list of parent node ids (starting
# from the root node) of C<$node>.
#
# As a special exception (read: kludge), a single C<undef> means to make
# C<$node> a root node (an empty list does not work, as it cannot be
# distinguished from a getter call).
#
# Returns: @node_ids
#
sub _materialized_path_elements
{
  my ($self, @node_ids) = (shift, @_);

  if (@_) {
    # handle the special exception (kludge)
    @node_ids = () if @node_ids == 1 && !defined $node_ids[0];

    $self->update({
      $self->materialized_path_column =>
        $self->_encode_materialized_path(@node_ids),
      $self->materialized_path_depth_column => $#node_ids,
    });
  } else {
    @node_ids = $self->_decode_materialized_path(
      $self->_materialized_path
    );
  }

  return @node_ids;
}

=head1 TODO

=head1 CAVEATS

=head1 SEE ALSO

L<DBIx::Class>, L<DBIx::Class::Tree>, L<DBIx::Class::Tree::AdjacencyList>

=head1 AUTHOR

Norbert Buchmüller, C<< <norbi at nix.hu> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-dbix-class-tree-materializedpath at rt.cpan.org>, or through the web
interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBIx-Class-Tree-MaterializedPath>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

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

The interface was chosen to resemble that of L<DBIx::Class::Tree> (eg.
L<DBIx::Class::Tree::AdjacencyList>) as closely as possible.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Norbert Buchmüller, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of DBIx::Class::Tree::MaterializedPath
