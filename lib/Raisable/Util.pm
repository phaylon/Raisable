use strictures 1;

# ABSTRACT: Internal utility functions for Raisable

package Raisable::Util;

use Carp                qw( croak );
use Params::Classify    qw( is_blessed is_ref );
use Scalar::Util        qw( reftype );
use Data::Dump          qw( pp );

use syntax qw( simple/v2 );
use namespace::clean;

use Sub::Exporter -setup => {
    exports => [qw(
        assert_called_on
        assert_code
        assert_pairwise
        assert_argument_count
        identify_value
        caller_location
        final_marker
        is_final_marker
        final_marker_value
        topicalize
    )],
};

our @CARP_NOT = qw(
    Raisable
    Raisable::Handler
    Raisable::MatchPayload
);

my %inverse = (class => 'object', object => 'class', package => 'object');

my $caller = fun ($proto) {
    (my $method = (caller 2)[3]) =~ s{^.+::([^:]+)$}{$1};
    my $class  = ref($proto) || $proto;
    return $class, $method;
};

my $final_class = join '::', __PACKAGE__, '_FINAL';

fun topicalize ($value, $code) {
    if (is_blessed $value) {
        local $_ = $value;
        return $value->$code;
    }
    elsif (is_ref $value, 'HASH') {
        local *_ = { %$value };
        return $code->(%$value);
    }
    else {
        die "Unable to topicalize " . identify_value($value);
    }
}

fun final_marker ($value) {
    return bless { value => $value }, $final_class;
}

fun is_final_marker ($value) {
    return is_blessed $value, $final_class;
}

fun final_marker_value ($marker) {
    return $marker->{value};
}

fun caller_location {
    my ($file, $line) = (caller 1)[1, 2];
    return file => $file, line => $line;
}

fun identify_value ($value) {
    return 'an undefined value'
        unless defined $value;
    return 'a non-reference value'
        unless ref $value;
    return sprintf('a %s reference', ref $value)
        unless is_blessed $value;
    return sprintf('an object of the class %s', ref $value);
};

fun assert_code ($value, $proto, $argument_str) {
    my ($class, $method) = $proto->$caller;
    return if reftype($value) and reftype($value) eq 'CODE';
    croak sprintf
        q(%s to method '%s' on %s has to be a code reference, not %s),
        ucfirst($argument_str), $method, $class, identify_value($value);
}

fun assert_pairwise ($count, $proto, $argument_str, $wrong_str) {
    my ($class, $method) = $proto->$caller;
    return unless $count % 2;
    croak sprintf(
          q(The method '%s' on %s expected %s, )
        . q(but received an odd number of %s),
        $method, $class, $argument_str, $wrong_str,
    );
}

fun assert_called_on ($type, $proto) {
    my ($class, $method) = $proto->$caller;
    if ($type eq 'object') {
        return if is_blessed $proto;
    }
    elsif ($type eq 'package') {
        return unless ref $proto;
    }
    elsif ($type eq 'class') {
        return if not(ref $proto)
            and $proto->meta->isa('Moose::Meta::Class');
    }
    croak sprintf q(%s method '%s' on %s cannot be called as %s method),
        ucfirst($type), $method, $class, $inverse{$type};
}

fun assert_argument_count ($limit, $got, $proto) {
    my ($class, $method) = $proto->$caller;
    my ($min, $max) = ref($limit) ? @$limit : (($limit) x 2);
    return if $got <= $max and $got >= $min;
    croak sprintf q(The method '%s' on %s expects %s %s, but received %d),
        $method, $class,
        ref($limit) ? "$min to $max" : $limit,
        (not ref($limit) and $limit == 1) ? 'argument' : 'arguments',
        $got;
}

1;

__END__

=head1 DESCRIPTION

This is an internal module of L<Raisable>.

=cut
