use strictures 1;
use Test::More;
use Test::Fatal;

is exception {
    package TestCondition;
    use Moose;
    has default => (is => 'ro');
    sub DEFAULT { $_[0]->default }
    with 'Raisable';
}, undef, 'declaring a condition with a default value';

is(TestCondition->optional, undef, 'no default');
is(TestCondition->optional(default => 23), 23, 'with default');
is(TestCondition->handle(sub { 17 })->in(sub {
    return TestCondition->optional(default => 23);
}), 17, 'default overruled by accepted handler return');

done_testing;
