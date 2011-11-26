use strictures 1;

# ABSTRACT: Match conditions by payload

package Raisable::Match::Payload;
use Moose::Role;
use MooseX::AttributeShortcuts;
use Carp                    qw( croak );
use Params::Classify        qw( is_blessed is_ref is_regexp is_string );
use Scalar::Util            qw( reftype );
use Raisable::Util          qw( :all );

use syntax qw( simple/v2 );
use namespace::autoclean;

with qw( Raisable );

requires qw( payload );

our @CARP_NOT = @Raisable::Util::CARP_NOT;

my $payload_match = method ($pattern_map, $file, $line) {
    my $payload = $self->payload;
    my $where   = sprintf 'passed in %s line %d', $file, $line;
    FIELD: for my $name (keys %$pattern_map) {
        my $pattern = $pattern_map->{$name};
        my $value   = $payload->{$name};
        my @all = (is_ref($pattern, 'ARRAY') ? @$pattern : ($pattern));
        PATTERN: for my $match (@all) {
            if (reftype($match) and reftype($match) eq 'CODE') {
                local $_ = $value;
                next FIELD if $value->$match;
            }
            elsif (reftype($match) and reftype($match) eq 'REGEXP') {
                next FIELD if $value =~ $match;
            }
            elsif (is_string $match) {
                next FIELD if $value eq $match;
            }
            else {
                my $class = ref $self;
                my $type  = identify_value($match);
                croak qq(Condition class $class cannot match payload )
                    . qq(slot '$name' against $type $where);
            }
        }
        return 0;
    }
    return 1;
};

around MATCH (@args) {
    assert_called_on(object => $self);
    assert_argument_count(3, scalar(@args), $self);
    my ($value, $file, $line) = @args;
    if (is_ref $value, 'HASH') {
        return $self->$payload_match(@args);
    }
    return $self->$orig(@args);
};

1;

__END__

=head1 SYNOPSIS

    # declare a condition with a specified payload
    package My::Condition::Unparsable;
    use Moose;

    has type => (
        traits   => ['Role::HasPayload::Meta::Attribute::Payload'],
        is       => 'ro',
        required => 1,
    );

    has line => (
        is       => 'ro',
        required => 1,
    );

    with qw(
        Role::HasPayload::Auto
        Raisable::Match::Payload
    );

    1;

    ...

    # match against the payload
    My::Condition::Unparseable
        ->handle({ type => 'json' }, sub { ... })
        ->in(sub { ... });

=head1 DESCRIPTION

This is an extension of L<Raisable> that allows condition objects to be
matched against a hash reference additionally to other possible match
value types.

A L</payload> method needs to be implemented for this role to work. See
L<Role::HasPayload> for one provider of such a method.

=head2 Allowed match structures

The match value itself has to be a hash reference. Each named attribute
points to a value that is used to test the value of the condition payload
attribute. All supplied keys must pass their test for the match to
succeed.

The following types of values are permitted as test values:

=over

=item * A code reference

This will be invoked with the value in C<$_> and as first argument and
needs to return true if the value is a match.

=item * A regular expression

The pattern is matched against the payload attribute content.

=item * A string

The pattern is compared to the payload attribute content by string
comparison.

=item * An array reference

This can contain any of the above, but not another array reference. If one
of the test values matches the payload attribute value, the attribute will
match.

=back

=head1 IMPLEMENTS

=over

=item * L<Raisable>

=back

=head1 REQUIRES

=head2 payload

    my $payload_hash_ref = $condition->payload;

Needs to return a hash reference containing all the payload values that
can be matched against. Note that payload values are not cached.

=head1 METHODS

=head2 MATCH

    my $is_matched = $condition->MATCH( $value, $file, $line );

Extends L<Raisable/MATCH> to allow matching of hash references against
payload values.

=head1 SEE ALSO

=over

=item * L<Raisable>

=item * L<Role::HasPayload>

=back

=cut
