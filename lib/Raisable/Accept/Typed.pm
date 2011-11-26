use strictures 1;

# ABSTRACT: Declare acceptable values by type constraint

package Raisable::Accept::Typed;
use Moose::Role;
use MooseX::AttributeShortcuts;
use MooseX::Types::Moose    qw( Undef Defined );
use Carp                    qw( croak );
use Devel::PartialDump      qw( dump );
use Raisable::Util          qw( :all );

use syntax qw( simple/v2 );
use namespace::autoclean;

our @CARP_NOT = @Raisable::Util::CARP_NOT;

around ACCEPT ($class: $value, $file, $line) {
    my $valid = $class->ACCEPT_TYPE;
    my $null  = $class->NULL_TYPE;
    return 1
        if $valid->check($value);
    return 0
        if $null->check($value);
    die sprintf(
        qq{The value %s %s is not a valid %s or %s\n},
        dump($value),
        sprintf('received at %s line %d', $file, $line),
        $valid->name,
        $null->name,
    );
}

method ACCEPT_TYPE { Defined }

method NULL_TYPE { Undef }

with qw( Raisable );

1;

__END__

=head1 SYNOPSIS

    package Condition::Unparseable;
    use Moose;
    use MooseX::Types::Moose qw( HashRef );

    method ACCEPT_TYPE { HashRef }

    with 'Raisable::Accept::Typed';

    1;

=head1 DESCRIPTION

This is an extension of L<Raisable> that restricts the handled values by
L<Moose> type constraints. You can customize the acceptable values by
providing your own L</ACCEPT_TYPE> and L</NULL_TYPE> methods.

=head1 IMPLEMENTS

=over

=item * L<Raisable>

=back

=head1 METHODS

=head2 ACCEPT

    my $is_accepted = ConditionClass->ACCEPT( $value, $file, $line );

Overrides L<Raisable/ACCEPT>. A valid type has to pass the constraint
returned from L>/ACCEPT_TYPE>. If it isn't valid, it has to pass the
L</NULL_TYPE> constraint to indicate it is a non-value. If neither value
passes, the method will croak with a descriptive error.

=head2 ACCEPT_TYPE

    my $type_constraint = ConditionClass->ACCEPT_TYPE;

Has to return a L<Moose::Meta::TypeConstraint>. The constraint will be
used to determine if a value is acceptable to resolve the condition. By
default, the C<Defined> type constraint is returned.

=head2 NULL_TYPE

    my $type_constraint = ConditionClass->NULL_TYPE;

Has to return a L<Moose::Meta::TypeConstraint>. The constraint will be
used to determine if a value is a valid non-value marker indicating that a
condition could not be resolved. By default, the C<Undef> type constraint
is returned.

=head1 SEE ALSO

=over

=item * L<Raisable>

=item * L<Moose>

=item * L<Moose::Manual::Types>

=back

=cut
