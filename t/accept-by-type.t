use strictures 1;
use Test::More;
use Test::Fatal;

sub rx { (map qr{$_}si, join '.+', map qr{\Q$_\E}i, @_)[0] }

is exception {
    package TestCondition;
    use Moose;
    use MooseX::Types::Moose qw( Str );
    sub ACCEPT_TYPE { Str }
    with 'Raisable::Accept::Typed';
}, undef, 'declaring a condition accepting a specific type';

is exception {
    TestCondition->required_from(sub { 'foo' });
}, undef, 'valid value';

is exception {
    TestCondition->optional_from(sub { undef });
}, undef, 'null value';

like exception { TestCondition->optional_from(sub { { fnord => 23 } }) },
    rx(qw( value fnord ), __FILE__, qw( not Str or Undef )),
    'invalid value throws error';

done_testing;
