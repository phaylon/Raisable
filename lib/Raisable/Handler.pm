use strictures 1;

# ABSTRACT: Internal resolution handler for Raisable

package Raisable::Handler;
use Moose;
use MooseX::AttributeShortcuts;
use Raisable::Util          qw( :all );

use syntax qw( simple/v2 );
use namespace::autoclean;

has callback            => (is => 'ro', required => 1);
has class_predicate     => (is => 'ro');
has object_predicate    => (is => 'ro');
has parent              => (is => 'ro');
has file                => (is => 'ro');
has line                => (is => 'ro');

our @CARP_NOT = @Raisable::Util::CARP_NOT;

method handle (@args) {
    assert_called_on(object => $self);
    assert_argument_count([1, 2], scalar(@args), $self);
    my %arg;
    if (@args == 1) {
        assert_code($args[0], $self, 'single argument');
        $arg{callback} = $args[0];
    }
    elsif (@args == 2) {
        assert_code($args[1], $self, 'second argument');
        @arg{qw( object_predicate callback )} = @args;
    }
    return $self->_extend(%arg, caller_location);
}

method in (@args) {
    assert_called_on(object => $self);
    assert_argument_count(1, scalar(@args), $self);
    assert_code($args[0], $self, 'single argument');
    my ($code) = @args;
    local $Raisable::_HEAD = $self;
    return $code->();
}

method _extend (%arg) {
    return ref($self)->new(
        parent          => $self,
        class_predicate => $self->class_predicate,
        %arg,
    );
}

method _resolve ($condition, $previous) {
    my $class_p  = $self->class_predicate;
    my $object_p = $self->object_predicate;
    my $file     = $self->file;
    my $line     = $self->line;
    return scalar $self->_next($condition, $previous)
        if ($class_p and not $condition->$class_p)
        or (defined($object_p)
            and not $condition->MATCH($object_p, $file, $line)
        );
    my $callback = $self->callback;
    my $returned = topicalize($condition, $callback);
    if (is_final_marker $returned) {
        return final_marker_value($returned);
    }
    unless (ref($condition)->ACCEPT($returned, $file, $line)) {
        return scalar $self->_next($condition, $previous);
    }
    return $returned;
}

method _next ($condition, $previous) {
    return $previous
        unless $self->parent;
    return $self->parent->_resolve($condition, $previous);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DESCRIPTION

This is an internal module of L<Raisable>.

=cut
