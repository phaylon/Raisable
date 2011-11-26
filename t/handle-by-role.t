use strictures 1;
use Test::More;
use Test::Fatal;

my %STORE = (foo => 23, bar => undef);

is exception {
    package TestConditionRoleNoValue;
    use Moose::Role;
    has key => (is => 'ro');
    with qw( Raisable );
}, undef, 'declaring a simple condition role';

is exception {
    package TestConditionUndefined;
    use Moose;
    with qw( TestConditionRoleNoValue );
}, undef, 'declaring a simple non-existant condition';

is exception {
    package TestConditionUnset;
    use Moose;
    with qw( TestConditionRoleNoValue );
}, undef, 'declaring a simple non-existant condition';

my $GET = sub {
    my ($name) = @_;
    return TestConditionUnset->required(key => $name)
        unless exists $STORE{$name};
    return TestConditionUndefined->required(key => $name)
        unless defined $STORE{$name};
    return $STORE{$name};
};

my $GET_SAFE = sub {
    my ($name) = @_;
    return TestConditionRoleNoValue
        ->handle(sub { ref })
        ->in(sub { $GET->($name) });
};

is $GET_SAFE->('qux'), 'TestConditionUnset',
    'unset condition matched';
is $GET_SAFE->('bar'), 'TestConditionUndefined',
    'undefined condition matched';
is $GET_SAFE->('foo'), 23,
    'defined value returned';

done_testing;
