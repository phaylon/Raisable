use strictures 1;
use Test::More;
use Test::Fatal;

sub rx { (map qr{$_}si, join '.+', map qr{\Q$_\E}i, @_)[0] }

is exception {
    package TestCondition;
    use Moose;
    with 'Raisable';
}, undef, 'declaring a simple condition';

subtest "matching errors" => sub {
    my $cond = TestCondition->new;
    like exception { TestCondition->MATCH(qw( foo bar 23 )) },
        rx(qw(
            object method MATCH TestCondition
            cannot called class
        ), __FILE__), 'match on class';
    like exception { $cond->MATCH('foo') },
        rx(qw(
            MATCH TestCondition expects 3 arguments
            received 1
        ), __FILE__), 'missing arguments for matching';
    like exception { $cond->MATCH('foo', 'source', 23) },
        rx(qw(
            condition class TestCondition
            cannot match non reference
            in source line 23
        )), 'invalid match value';
    done_testing;
};

subtest "->optional errors" => sub {
    my $cond = TestCondition->new;
    like exception { $cond->optional },
        rx(qw(
            class method optional TestCondition
            cannot called object
        ), __FILE__), 'called optional as object method';
    like exception { TestCondition->optional(23) },
        rx(qw(
            method optional expected key value pairs
            received odd number option values
        ), __FILE__), 'called optional with invalid arguments';
    done_testing;
};

subtest "->required errors" => sub {
    my $cond = TestCondition->new;
    like exception { $cond->required },
        rx(qw(
            class method required TestCondition
            cannot called object
        ), __FILE__), 'called required as object method';
    like exception { TestCondition->required(23) },
        rx(qw(
            method required expected key value pairs
            received odd number option values
        ), __FILE__), 'called required with invalid arguments';
    done_testing;
};

subtest "->required_from errors" => sub {
    my $cond = TestCondition->new;
    like exception { $cond->required_from(sub { }) },
        rx(qw(
            class method required_from TestCondition
            cannot called object
        ), __FILE__), 'called required_from as object method';
    like exception { TestCondition->required_from(23) },
        rx(qw(
            first argument method required_from code reference
            not non reference
        ), __FILE__), 'called required_from without code reference';
    like exception { TestCondition->required_from(sub { }, 23) },
        rx(qw(
            method required_from expected key value pairs
            received odd number option values
        ), __FILE__), 'called required_from with invalid arguments';
    done_testing;
};

subtest "->optional_from errors" => sub {
    my $cond = TestCondition->new;
    like exception { $cond->optional_from(sub { }) },
        rx(qw(
            class method optional_from TestCondition
            cannot called object
        ), __FILE__), 'called optional_from as object method';
    like exception { TestCondition->optional_from(23) },
        rx(qw(
            first argument method optional_from code reference
            not non reference
        ), __FILE__), 'called optional_from without code reference';
    like exception { TestCondition->optional_from(sub { }, 23) },
        rx(qw(
            method optional_from expected key value pairs
            received odd number option values
        ), __FILE__), 'called optional_from with invalid arguments';
    done_testing;
};

subtest "->handle errors" => sub {
    my $cond = TestCondition->new;
    like exception { $cond->handle(sub { }) },
        rx(qw(
            package method handle TestCondition
            cannot called object
        ), __FILE__), 'called handle as object method';
    like exception { TestCondition->handle },
        rx(qw(
            method handle TestCondition expects 1 to 2 arguments
            received 0
        ), __FILE__), 'called handle with no arguments';
    like exception { TestCondition->handle(23, sub {}, 47) },
        rx(qw(
            method handle TestCondition expects 1 to 2 arguments
            received 3
        ), __FILE__), 'called handle with too many arguments';
    like exception { TestCondition->handle(undef) },
        rx(qw(
            single argument method handle TestCondition code reference
            not undefined
        ), __FILE__), 'called single value handle without code reference';
    like exception { TestCondition->handle(undef, undef) },
        rx(qw(
            second argument method handle TestCondition code reference
            not undefined
        ), __FILE__), 'called two value handle without code reference';
    subtest "extended handler" => sub {
        my $pre = TestCondition->handle(sub { });
        like exception { $pre->handle(undef) },
            rx(qw(
                single argument method handle Handler code reference
                not undefined
            ), __FILE__),
            'called single value handle without code reference';
        like exception { $pre->handle(undef, undef) },
            rx(qw(
                second argument method handle Handler code reference
                not undefined
            ), __FILE__),
            'called two value handle without code reference';
        done_testing;
    };
    done_testing;
};

subtest "->final errors" => sub {
    my $cond = TestCondition->new;
    like exception { TestCondition->final },
        rx(qw(
            object method final TestCondition
            cannot called class
        ), __FILE__), 'called final as class method';
    like exception { $cond->final(2, 3) },
        rx(qw(
            method final TestCondition expects 0 to 1 arguments
            received 2
        ), __FILE__), 'called final with too many arguments';
    done_testing;
};

subtest "->retry errors" => sub {
    my $cond = TestCondition->new;
    like exception { TestCondition->retry },
        rx(qw(
            object method retry TestCondition
            cannot called class
        ), __FILE__), 'called retry as class method';
    like exception { $cond->retry(23) },
        rx(qw(
            method retry expected key value pairs
            received odd number option values
        ), __FILE__), 'called retry with invalid arguments';
    done_testing;
};

subtest "->in errors" => sub {
    my $pre = TestCondition->handle(sub { });
    like exception { ref($pre)->in(sub { }) },
        rx(qw(
            object method in Handler
            cannot called class
        ), __FILE__), 'called in as class method';
    like exception { $pre->in },
        rx(qw(
            method in Handler expects 1 argument
            received 0
        ), __FILE__), 'called in with no arguments';
    like exception { $pre->in(sub { }, 23) },
        rx(qw(
            method in Handler expects 1 argument
            received 2
        ), __FILE__), 'called in with too many arguments';
    like exception { $pre->in(undef) },
        rx(qw(
            single argument method in Handler code reference
            not undefined
        ), __FILE__), 'called in without code reference';
    done_testing;
};

done_testing;
