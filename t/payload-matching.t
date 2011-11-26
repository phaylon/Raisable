use strictures 1;
use Test::More;
use Test::Fatal;

sub rx { (map qr{$_}si, join '.+', map qr{\Q$_\E}i, @_)[0] }

is exception {
    package TestCondition;
    use Moose;
    sub payload { return { foo => 'bar' } }
    with qw( Raisable Raisable::Match::Payload );
}, undef, 'declaring a simple payloaded condition';

my $match = sub {
    my $pattern = shift;
    return scalar TestCondition
        ->handle(sub { 0 })
        ->handle({ foo => $pattern }, sub { 1 })
        ->in(sub { TestCondition->required });
};

ok $match->('bar'), 'match by string';
ok !$match->('qux'), 'mismatch by string';

ok $match->(qr{^BA}i), 'match by regexp';
ok !$match->(qr{^BA$}i), 'mismatch by regexp';

ok $match->(sub { $_ eq 'bar' }), 'match by code reference';
ok !$match->(sub { $_ eq 'qux' }), 'mismatch by code reference';

my %check = (
    string => { match => 'bar', mismatch => 'qux' },
    regexp => { match => qr{^BA}i, mismatch => qr{^BA$}i },
    code   => {
        match    => sub { $_ eq 'bar' },
        mismatch => sub { $_ eq 'qux' },
    }
);

ok !$match->([
    $check{string}{mismatch},
    $check{regexp}{mismatch},
    $check{code}{mismatch},
]), 'multiple mismatches in group';

ok $match->([
    $check{string}{match},
    $check{regexp}{mismatch},
    $check{code}{mismatch},
]), 'match string in group';

ok $match->([
    $check{string}{mismatch},
    $check{regexp}{match},
    $check{code}{mismatch},
]), 'match regexp in group';

ok $match->([
    $check{string}{mismatch},
    $check{regexp}{mismatch},
    $check{code}{match},
]), 'match code reference in group';

like exception { $match->(undef) },
    rx(qw(
        condition class TestCondition cannot match undefined
    ), __FILE__), 'undefined match value';

done_testing;
