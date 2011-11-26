use strictures 1;
use Test::More;
use Test::Fatal;

is exception {
    package TestCondition;
    use Moose;
    with 'Raisable';
}, undef, 'declaring a simple condition';

my @values = (9..13);
my $getter = sub { @values };
my $empty  = sub { };
my $undef  = sub { undef };
my $retry  = sub { my @with = @_; sub { $_->retry(values => [@with]) } };
my $final  = sub { my @with = @_; sub { $_->final(@with) } };
my $by_arg = sub { return unless $_{values}; @{ $_{values} } };

my $raise = sub {
    my $how  = shift;
    my $what = shift;
    $how .= '_from';
    return sub { TestCondition->$how($what) };
};

my $check = sub {
    my $name = shift;
    my $what = shift;
    my $vals = shift || [scalar @values];
    my $item = @_ ? shift : scalar(@$vals);
    is_deeply [$what->()], $vals, "$name in list context";
    is scalar($what->()), $item, "$name in scalar context";
};

$check->('->in', sub {
    TestCondition->handle($empty)->in($getter);
}, [@values], 5);

$check->('->handle', sub {
    TestCondition->handle($getter)->in($raise->(optional => $empty));
}, [5], 5);

$check->('skipped ->handle', sub {
    TestCondition->handle($empty)->in($raise->(optional => $empty));
}, [undef], undef);

$check->('->retry', sub {
    TestCondition
        ->handle($retry->(@values))
        ->in($raise->(optional => $by_arg));
}, [5], 5);

is_deeply [TestCondition->handle(sub { 23 })->in($undef)], [undef],
    'undefined value is valid in list context';

$check->('empty ->final', sub {
    TestCondition
        ->handle(sub { 23 })
        ->handle($final->())
        ->in($raise->(optional => $empty));
}, [undef], undef);

$check->('multi value ->final', sub {
    TestCondition
        ->handle(sub { 23 })
        ->handle($final->(23))
        ->in($raise->(optional => $empty));
}, [23], 23);

done_testing;
