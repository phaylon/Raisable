use strictures 1;
use Test::More;
use Test::Fatal;

is exception {
    package TestCondition;
    use Moose;
    with qw( Raisable );
}, undef, 'declaring a simple condition';

my $BARRIER_THROW = sub {
    my $code = shift;
    return sub {
        return TestCondition
            ->handle(sub { die "barrier\n" })
            ->in($code);
    };
};

my $BARRIER_EMPTY = sub {
    my $code = shift;
    return sub { TestCondition->handle(sub { $_->final })->in($code) };
};

my $CALLER = sub {
    my $method = shift;
    $method .= '_from';
    return sub { TestCondition->$method(sub { return }) };
};

my $RUN = sub { (shift)->() };

is exception { optional->$CALLER->$BARRIER_THROW->$RUN },
    "barrier\n", 'throwing barrier throws right exception';

is optional->$CALLER->$BARRIER_EMPTY->$RUN, undef,
    'empty final barrier returns undef';

isa_ok exception { required->$CALLER->$BARRIER_EMPTY->$RUN },
    'TestCondition', 'exception from required with empty barrier';

is optional->$CALLER->$BARRIER_EMPTY->$BARRIER_THROW->$RUN, undef,
    'empty final barrier circumvents exception barrier';

done_testing;
