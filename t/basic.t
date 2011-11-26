use strictures 1;
use Test::More;
use Test::Fatal;

is exception {
    package TestCondition;
    use Moose;
    with 'Raisable';
}, undef, 'the simplest possible condition';

is exception {
    package TestSimpleConditionNoValue;
    use Moose;
    has id      => (is => 'ro');
    has storage => (is => 'ro');
    with qw( Raisable );
    __PACKAGE__->meta->make_immutable;
}, undef, 'declaring a simple condition';

is exception {
    package TestSimpleStorage;
    use Moose;
    has data => (
        traits  => [qw( Hash )],
        is      => 'ro',
        default => sub { {} },
        handles => {
            _get_value  => 'get',
            _set_value  => 'set',
        },
    );
    has get_count => (
        traits  => [qw( Counter )],
        is      => 'ro',
        default => 0,
        handles => {
            inc_get_count => 'inc',
        },
    );
    sub counter {
        my ($self) = @_;
        my $start = $self->get_count;
        return sub { $self->get_count - $start };
    }
    sub get {
        my ($self, $name, %arg) = @_;
        my $via = $arg{optional} ? 'optional_from' : 'required_from';
        return TestSimpleConditionNoValue->$via(
            sub {
                my %topic = %_;
                my %arg   = @_;
                my $value;
                ::subtest "value retrieval" => sub {
                    ::ok $topic{id}, 'topic key argument';
                    ::isa_ok $topic{storage}, 'TestSimpleStorage',
                        'topic object argument';
                    ::ok $arg{id}, 'explicit key argument';
                    ::isa_ok $arg{storage}, 'TestSimpleStorage',
                        'explicit object argument';
                    $value = $topic{storage}->_get_value($topic{id});
                    ::done_testing;
                };
                $self->inc_get_count;
                return $value;
            },
            id      => $name,
            storage => $self,
        );
    }
    sub set {
        my ($self, $name, $value) = @_;
        return $self->_set_value($name, $value);
    }
    __PACKAGE__->meta->make_immutable;
}, undef, 'declaring a simple storage object';

my $store = TestSimpleStorage->new;
$store->set(fnord => 17);

subtest "handled by setting default" => sub {
    my $counter = $store->counter;
    is exception {
        note('fetching value');
        my $value = TestSimpleConditionNoValue
            ->handle(sub {
                note('retry');
                isa_ok $_[0], 'TestSimpleConditionNoValue', 'invocant';
                isa_ok $_, 'TestSimpleConditionNoValue', 'topic';
                $_->storage->set($_->id, uc $_->id);
                $_->retry;
            })->in(sub { $store->get('foo') });
        note('got value');
        is $value, 'FOO', 'correct value returned';
        is $counter->(), 2, 'retrieval routine ran twice';
        note('test for stored value');
        is $store->get('foo'), 'FOO', 'correct value stored';
        is $counter->(), 3, 'retriaval routine ran once more';
    }, undef, 'no errors';
    done_testing;
};

subtest "redirect to another storage" => sub {
    my $counter = $store->counter;
    is exception {
        my $fallback = TestSimpleStorage->new;
        $fallback->set(bar => 23);
        note('fetching value');
        my $value = TestSimpleConditionNoValue
            ->handle(sub {
                note('retry');
                isa_ok $_[0], 'TestSimpleConditionNoValue', 'invocant';
                isa_ok $_, 'TestSimpleConditionNoValue', 'topic';
                return $_->retry(storage => $fallback);
            })->in(sub { $store->get('bar') });
        note('got value');
        is $value, 23, 'alternate value returned';
        is $counter->(), 2, 'retrieval routine ran twice on original';
    }, undef, 'no errors';
    done_testing;
};

subtest "redirect to another slot" => sub {
    my $counter = $store->counter;
    is exception {
        note('fetching value');
        my $value = TestSimpleConditionNoValue
            ->handle(sub {
                note('retry');
                isa_ok $_[0], 'TestSimpleConditionNoValue', 'invocant';
                isa_ok $_, 'TestSimpleConditionNoValue', 'topic';
                return $_->retry(id => 'fnord');
            })->in(sub { $store->get('baz') });
        note('got value');
        is $value, 17, 'alternate slot value returned';
        is $counter->(), 2, 'retrieval routine ran twice';
    }, undef, 'no errors';
    done_testing;
};

subtest "unhandled guarding condition" => sub {
    my $counter = $store->counter;
    isa_ok my $error = exception {
        note('fetching value');
        $store->get('qux');
    }, 'TestSimpleConditionNoValue', 'exception';
    is $error->id, 'qux', 'correct argument attribute value';
    is $counter->(), 1, 'retrieval routine only ran once';
    done_testing;
};

subtest "unhandled optional value condition" => sub {
    my $counter = $store->counter;
    is exception {
        note('fetching value');
        my $value = $store->get('quux', optional => 1);
        note('got value');
        is $value, undef, 'unknown value is undefined';
        is $counter->(), 1, 'retrieval routine only ran once';
    }, undef, 'no errors';
    done_testing;
};

subtest "guarding condition with empty fallback" => sub {
    my $counter = $store->counter;
    isa_ok my $error = exception {
        note('fetching value');
        TestSimpleConditionNoValue
            ->handle(sub { $_->retry })
            ->in(sub { $store->get('qux') });
    }, 'TestSimpleConditionNoValue', 'exception';
    is $error->id, 'qux', 'correct argument attribute value';
    is $counter->(), 2, 'retrieval routine ran twice';
    done_testing;
};

subtest "optional value condition with empty fallback" => sub {
    my $counter = $store->counter;
    is exception {
        note('fetching value');
        my $value = TestSimpleConditionNoValue
            ->handle(sub { $_->retry })
            ->in(sub { $store->get('quux', optional => 1) });
        note('got value');
        is $value, undef, 'unknown value is undefined';
        is $counter->(), 2, 'retrieval routine ran twice';
    }, undef, 'no errors';
    done_testing;
};

subtest "matching a condition by code reference" => sub {
    my $counter = $store->counter;
    is exception {
        my $first  = 0;
        my $second = 0;
        my $first_check  = 0;
        my $second_check = 0;
        my $inner_return = 23;
        TestSimpleConditionNoValue
            ->handle(sub {
                $first_check++;
                return unless $_->id eq 'first';
                $first++;
                return 1;
            }, sub { 17 })
            ->handle(sub {
                $second_check++;
                return unless $_->id eq 'second';
                $second++;
                return 1;
            }, sub { $inner_return })
            ->in(sub {
                note('fetching normal values');
                is $store->get('first'),  17, 'first value';
                is $store->get('second'), 23, 'second value';
                note('values fetched');
                is $first,  1, 'first handler matched once';
                is $second, 1, 'second handler matched once';
                is $counter->(), 2, 'value was retrieved twice';
                is $first_check, 1, 'outer match only reached once';
                is $second_check, 2, 'inner match reached twice';
                note('fetching without finding a value');
                $inner_return = undef;
                is $store->get('second', optional => 1), undef,
                    'undefined value passed through';
                note('attempt to fetch complete');
                is $first, 1, 'no match on first handler';
                is $second, 2, 'match on second handler';
                is $first_check, 2, 'first match reached';
                is $second_check, 3, 'second match also reached';
                is $counter->(), 3, 'value retrieved once';
            });
    }, undef, 'no errors';
    done_testing;
};

subtest "explicit raising" => sub {
    is_deeply [TestCondition->optional],
        [undef], 'optional in list context';
    is scalar(TestCondition->optional),
        undef, 'optional in scalar context';
    isa_ok exception { TestCondition->required },
        'TestCondition', 'raised';
    is scalar(TestCondition
        ->handle(sub { 23 })
        ->in(sub { TestCondition->required })),
        23, 'value returned from raised condition';
    is scalar(TestCondition
        ->handle(sub { 23 })
        ->in(sub { TestCondition->optional })),
        23, 'value returned from optional condition';
    done_testing;
};

done_testing;
