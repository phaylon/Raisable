use strictures 1;
use Test::More;
use Test::Fatal;

is exception {
    package TestCondition;
    use Moose;
    has data => (is => 'ro', required => 1);
    sub RESOLVE { $_[0]->data->{foo} }
    with 'Raisable';
}, undef, 'declared a self resolving condition';

my $data = {};

isa_ok exception { TestCondition->required(data => $data) },
    'TestCondition',
    'resolving condition raised to exception when nothing was found';

is scalar(
    TestCondition
        ->handle(sub { $data->{foo} = 23; $_->retry })
        ->in(sub { TestCondition->required(data => $data) })
), 23, 'retry with condition resolution';

done_testing;
