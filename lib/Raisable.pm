use strictures 1;

# ABSTRACT: Turn classes into resolvable conditions

package Raisable;
use Moose::Role;
use MooseX::AttributeShortcuts;
use Carp                    qw( croak );
use Params::Classify        qw( is_blessed is_ref is_regexp is_string );
use Scalar::Util            qw( reftype );
use Raisable::Util          qw( :all );

use aliased 'Raisable::Handler';

use syntax qw( simple/v2 );
use namespace::autoclean;

has condition_is_optional => (is => 'ro');
has condition_calculation => (is => 'ro');
has condition_arguments   => (is => 'ro', lazy => 1, builder => 1);

our $_HEAD = Handler->new(callback => method {
    return undef if $self->condition_is_optional;
    $self->throw;
});

our @CARP_NOT = @Raisable::Util::CARP_NOT;

my $raise = method ($class: $code, $args, $is_optional, $prev, %loc) {
    my $cond = $class->new(
        %$args,
        condition_is_optional => $is_optional,
        condition_arguments   => $args,
        $code
            ? (condition_calculation => $code)
            : (),
    );
    my $by_cond    = sub { $code ? undef : scalar $cond->RESOLVE };
    my $by_handler = sub { scalar $_HEAD->_resolve($cond, $prev) };
    for my $check ($by_cond, $by_handler) {
        my $value = $check->();
        return $value
            if ref($cond)->ACCEPT($value, @loc{qw( file line )});
    }
    my $default = $cond->DEFAULT;
    return $default
        if ref($cond)->ACCEPT($default, @loc{qw( file line )});
    return undef
        if $is_optional;
    $cond->throw;
};

my $run_guarded = method ($class: $code, $args, $is_optional, %loc) {
    my $value = topicalize($args, $code);
    unless ($class->ACCEPT($value, @loc{qw( file line )})) {
        return $class->$raise($code, $args, $is_optional, $value, %loc); 
    }
    return $value;
};

method MATCH (@args) {
    assert_called_on(object => $self);
    assert_argument_count(3, scalar(@args), $self);
    my ($value, $file, $line) = @args;
    my $class = ref $self;
    my $where = sprintf 'passed in %s line %d', $file, $line;
    if (reftype($value) and reftype($value) eq 'CODE') {
        return scalar topicalize($self, $value);
    }
    else {
        my $type = identify_value $value;
        die qq(Condition class $class cannot be matched against )
            . qq($type $where\n);
    }
}

method ACCEPT ($value) { return defined $value }

method RESOLVE { return undef }

method DEFAULT { return undef }

method optional ($class: @args) {
    assert_called_on(class => $class);
    assert_pairwise(scalar(@args), $class,
        q(a list of key/value pairs),
        q(option values),
    );
    return $class->$raise(undef, { @args }, 1, undef, caller_location);
}

method required ($class: @args) {
    assert_called_on(class => $class);
    assert_pairwise(scalar(@args), $class,
        q(a list of key/value pairs),
        q(option values),
    );
    return $class->$raise(undef, { @args }, 0, undef, caller_location);
}

method required_from ($class: $code, @args) {
    assert_called_on(class => $class);
    assert_code($code, $class, 'first argument');
    assert_pairwise(scalar(@args), $class,
        q(a code reference and a list of key/value pairs),
        q(option values),
    );
    return $class->$run_guarded($code, { @args }, 0, caller_location);
}

method optional_from ($class: $code, @args) {
    assert_called_on(class => $class);
    assert_code($code, $class, 'first argument');
    assert_pairwise(scalar(@args), $class,
        q(a code reference and a list of key/value pairs),
        q(option values),
    );
    return $class->$run_guarded($code, { @args }, 1, caller_location);
}

method handle ($class: @args) {
    assert_called_on(package => $class);
    assert_argument_count([1, 2], scalar(@args), $class);
    my %arg;
    if (@args == 1) {
        assert_code($args[0], $class, 'single argument');
        $arg{callback} = $args[0];
    }
    elsif (@args == 2) {
        assert_code($args[1], $class, 'second argument');
        @arg{qw( object_predicate callback )} = @args;
    }
    my $check = $class->meta->isa('Moose::Meta::Role') ? 'does' : 'isa';
    return $_HEAD->_extend(
        %arg,
        caller_location,
        class_predicate => fun ($condition) {
            return $condition->$check($class);
        },
    );
}

method final (@args) {
    assert_called_on(object => $self);
    assert_argument_count([0, 1], scalar(@args), $self);
    return final_marker(@args);
}

method retry (@args) {
    assert_called_on(object => $self);
    assert_pairwise(scalar(@args), $self,
        q(a list of key/value pairs),
        q(option values),
    );
    my %full = (%{ $self->condition_arguments || {} }, @args);
    if (my $calc = $self->condition_calculation) {
        return scalar topicalize(\%full, $calc);
    }
    return scalar $self->RESOLVE;
}

method _build_condition_arguments { {} }

with qw( Throwable );

1;

__END__

=head1 SYNOPSIS

    # first we declare a condition
    package MyCondition::Requirement::Description;
    use Moose;

    has file        => (is => 'ro');
    has description => (is => 'ro');

    with 'Raisable';

    1;

    ...

    # later you can resolve the condition to try and find a value
    my $descr_foo = MyCondition::Requirement::Description
        ->optional(file => 'foo.html');

    # you can also require that a value be returned
    my $descr_bar = MyCondition::Requirement::Description
        ->required(file => 'bar.html');

    # there's also options for giving a default resolution function
    my $descr_baz = MyCondition::Requirement::Description
        ->optional_from(sub {
            my $description = $_{description}
                or return undef;
            render_content($description);
        }, file => 'baz.html', description => $user_supplied_value);

    ...

    # now you can handle conditions on an outer scope
    MyCondition::Requirement::Description->handle(
        sub { $_->file eq 'foo.html' },
        sub { $_->retry(content => 'The foo HTML file') \},
    )->in(sub {
        # ... code that might need the condition resolved
    });

=head1 DESCRIPTION

This role is an extension of L<Throwable>, implementing conditions that
might be resolved by handlers set up in an outer dynamical scope.

Since every C<Raisable> is also a L<Throwable> and can turn into an
exception, you can use every extensino you could use for L<Throwable>
exceptions like description message generation or payload collection.

=head2 Declaring condition classes

The only requirement for a class to be turned into a condition is that
it's built on L<Moose>. Since this is a normal L<Moose::Role>, you can
apply it to anything you normally can. There's no real black magic here.

The simplest form of a condition would look like this:

    package Condition;
    use Moose;
    with 'Raisable';
    1;

Note that every condition is also always a L<Throwable>.

You can consume other roles and declare attributes like with any other
L<Moose> class. In fact, you will often want to declare attributes that
give a closer specification of the condition:

    package Condition::ConfigFile;
    use Moose;
    has filename => (is => 'ro');
    with 'Raisable';
    1;

The condition object will be available to all resolution handlers. As
such, the attributes and methods of your conditino class should encapsulate
everything that's required to possibly resolve the condition.

=head2 Raising conditions explicitly

The simplest case of raising a condition is to just expect a value. There
is no other logic attached to the condition besides the (optional or
required) request of a value.

This can be done by calling L</optional> or L</required> on the condition
class:

    my $file = Condition::ConfigFile
        ->optional(filename => 'app.conf')
        // 'etc/app.conf';

As you can see, the method is called with the constructor arguments for
the condition object.

In the above you can also see the difference between L</optional> and
L</required> conditions. An optional condition will return an undefined
value if nothing could be resolved, while a required one will turn into
an exception if none of the handlers could do anything about it.

=head2 Raising with a resolution function

Sometimes there is more logic involved than just fetching a value. Let's
declare a condition we raise when we can't parse a line of content:

    package Condition::Unparseable;
    use Moose;

    has line => (is => 'ro');
    has type => (is => 'ro');

    with 'Raisable';

    1;

The condition contains the C<line> we couldn't parse and the C<type> we
expect it to be in. The C<type> is useful so handlers can match specific
types of lines that made problems. We can incorporate the condition into
a parsing routine like the following:

    my @parsed;
    while (defined( my $line = shift @lines )) {
        my $data = Condition::Unparseable->required_from(
            sub {
                try { decode_json($_{line}) }
                catch { undef };
            },
            line => $line,
            type => 'json',
        );
        push @parsed, @$data;
    }

This will try to resolve the value with the passed subroutine, and only if
that returns an unacceptable value raise the condition as an object that
can be resolved by handlers. The L</required_from> and L</optional_from>
methods in a sense are guarding the routines and intercept in case they
return an undefined value.

The above already allows for many possibilities of handling the condition.
A handler might return an empty array reference to skip the unparseable
lines. It might parse the lines itself and return the data. Or it can
retry the callback with a different line.

To extend on what we have now, you could pass a parser to the condition
instead of fully encapsulating it, giving the handlers the option of using
it directly when resolving the condition. You can pass along the rest of
the C<@lines>, so a handler can resolve by combining multiple lines if the
outer scope wants to allow some form of multi-line statements.

The passed routine will receive the arguments passed to C<required_from>
inside C<%_> and as a hash passed directly to the subroutine. You should
try to keep these as side-effect free as possible, since the handlers can
rerun them and modify their arguments.

Just as with L</required> and L</optional>, L</required_from> will turn
the condition into an exception if it isn't resolved, while calling
L</optional_from> will give you an undefined value if nothing could be
done about it.

=head2 Matching conditions

Now that we have declared some conditions and are raising them at certain
points in our code, we need a way to add resolutions from the outer
dynamic scope.

The handlers are built up as a chain and then walked upwards looking for
possible resolutions. Handlers are added to the chain by calling
L</handle> on the class or role you want to handle. These calls can be
chained together to provide multiple ways of handling a condition. The
declared chain is active inside a code reference then passe to L</in>.

    Condition::Unparseable
        ->handle(sub {
            warn "Unable to parse: " . $_->line;
            return [];
        })
        ->handle(sub {
            $_->line eq "FIXTURES\n"
                ? [@fixtures]
                : undef;
        })
        ->in(sub { parse_file('somefile.json') });

You'll see that the condition object is now available in C<$_>. It is also
given to the subroutine as argument.

When the C<parse_file> invocation above hits a line that isn't valid JSON,
the second handler will be asked to resolve the condition. If the line
argument is a C<FIXTURES\n> marker, we insert some predeclared records
instead.

If the condition couldn't be resolved that way, the uppermost handler will
resolve the condition by returning an empty array reference, which leads
to it simply skipping unparseable lines. It will also warn if that is the
case. If the condition were to contain the source file and line number
that is parsed, you could give a more detailed warning at that point.

You can call L</handle> on classes and roles. If it is invoked on a role,
the declared handlers will be asked to resolve for all conditions that
applied the role. This means that you can handle all conditions by calling
L</handle> on C<Raisable> itself.

=head2 Restricted condition matching

In the above example, we have handlers that try to resolve all conditions
of the class they were declared on. The fixture handler simply returned
an undefined value if it couldn't handle the line. Instead, it could've
supplied a separate match routine:

    Condition::Unparseable
        ->handle(
            sub { $_->line eq "FIXTURES\n" },
            sub { [@fixtures] },
        )->in(sub { parse_file('somefile.json') });

The match routine receives the same argument as the handler. By default,
only code references can be used to match condition objects. There is also
a L<Raisable::Match::Payload> role you can consume to match hash
references against payload attribute values. Other matching formats can be
implemented by extending L>/MATCH>.

=head2 Retrying the calculation

The C>Condition::Unparseable> handlers in the examples earlier only
returned full values in case something couldn't be parsed.  But handlers
also have the ability to retry the routine:

    Condition::Unparseable
        ->handle(
            sub { $_->line =~ m{^\s+#} },
            sub {
                (my $corrected = $_->line) = s{^\s+#+}{};
                my $data = $_->retry(line => $corrected)
                    or return undef;
                $data->{disabled} = 1;
                return $data;
            },
        )->in(sub { parse_file('somefile.json') });

This example uses L</retry> to try and parse the line again after it
corrected it. This handler will take commented out records and, if they
are parseable, add a C<disabled> value to them.

You might ask yourself what happens when L</retry> is invoked on a
condition raised via L</required> or L</optional> that don't carry any
resolution logic with them. The easy answer is that nothing happens. It
is a null operation that simply returns an undefined value. The condition
class can override this by extending the L</RESOLVE> method.

=head2 Skipping the rest of the handlers

In some cases you might want to immediately stop resolving a condition.
If you examined a problem and it is that bad that no resolution should be
allowed, you have multiple options:

=over

=item * Turning the condition into an immediate exception

If you want to make sure that the computation doesn't continue as usual,
you can install a handler that raises the condition to exception level:

    Condition::Unparseable
        ->handle(
            sub { is_a_really_really_bad_condition($_) },
            sub { $_->throw },
        )->in(sub { parse_file('somefile.json') });

This will throw the condition as an exception if the object was
determined to describe a condition we shouldn't try to handle. This is an
extreme measure that locks out any higher resolutions, so be careful when
thinking about using it.

=item * Returning a finalized value

Instead of turning the condition into an exception, you can also break out
of the chain at any point by returning a finalized value:

    Condition::Unparseable
        ->handle(
            sub { not_that_bad_but_still_not_good($_) },
            sub { return $_->final },
        )->in(sub { parse_file('somefile.json') });

Here we return the result of calling the L</final> method on the
condition. This will return a special marker telling the condition system
to stop trying to resolve the issue and return an undefined value. If the
condition was raised as L</required>, it will be turned into an exception
before returning to the code that originally raised it. But if it was
declared optional, the calling code will receive an undefiend value at
this point and can choose to handle the unresolved condition.

You can also pass a value to L</final>. This is not useful in this simple
case, since you can always just return a value. The feature only really
becomes meaningful in more complicated settings.

=back

Note that both of these options stop conditino resolution at the point of
use and you're basically isolating the matched conditions from the
outside.

=head2 Matching against custom values

To determine if a handler matches a condition object, the system will
call L</MATCH> as an object method on the condition. You can override or
extend this method to customize how the condition supports to be matched.

The role L<Raisable::Match::Payload> already exists and implements simple
matching against attributes declared to be payload.

=head2 Changing the values a condition might accept

By default, any defined value is acceptable for the condition to be
resolved. An undefined value indicates the inability to resolve the
condition. This functionality can be customized by extending the
L</ACCEPT> method.

The role L<Raisable::Accept::Typed> already exists and implements value
acceptance via L<Moose> type constraints.

=head2 Default condition resolution method

While the ability to provide a resolution logic routine when raising a
condition is nice, some conditions occur often and are usually resolved
in the same way. To make this easier, a L</RESOLVE> method is used as a
fallback resolution. The method will be asked to resolve the condition
before all dynamic handlers in the chain, and will also be called on
L</retry>. Any custom resolution function will override this routine.

    package Condition::Storage::Locate;
    use Moose;

    has storage => (is => 'ro');
    has key     => (is => 'ro');

    sub RESOLVE {
        my ($self) = @_;
        return $self->storage->get($self->key);
    }

    with 'Raisable';

    1;

With this, a handler can return a custom item, look up a different one in
the storage, or put something into the storage before retrying the
resolution via L</retry>.

A custom resolution function passed with L</required_from> and
L</optional_from> overrides the calling of L</RESOLVE> either at the
raising of the condition or on L</retry>.

=head2 Extensions

=over

=item * L<Raisable::Match::Payload>

Allows matching of conditions by comparing a match specification to
payload attributes.

=item * L<Raisable::Accept::Typed>

Restricts what values are acceptable as resolution values and as non
values by L<Moose> type constraints.

=back

=head1 IMPLEMENTS

=over

=item * L<Throwable>

=back

=head1 METHODS

=head2 handle

    my $outer_all = ConditionClass->handle( \&handler );
    my $inner_all = $outer_all->handle( \&handler );
    my $value_all = $inner_all->in( \&might_raise );

    my $outer_spec = ConditionClass->handle( $match, \&handler );
    my $inner_spec = $outer_spec->handle( $match, \&handler );
    my $value_spec = $inner_spec->in( \&might_raise );

Adds a handler to the dynamic condition resolution chain. It can be called
on classes or roles that implemented C<Raisable>. Multiple C<handle> calls
can be chained together and will match the same class or role. The
returned object also provides the L</in> method handling the scope in
which the handlers are active.

Can be called with one or two arguments. In the one argument form, only a
handler is supplied. In the two argument form, the first value is the
match specification, and the second one is the handler code reference.

Both the handler and the matcher will be called with the condition as
first argument and as topic in C<$_>. The handler will always be called in
scalar context.

=head2 in

    my $value = ConditionClass->handle( \&handler )->in( \&might_raise );

Callable on the return value of L</handle>. This will invoke the code
reference using the chain pointed to by the L</handle> return value for
resolution.

The context the code reference is invoked in depends on the context of the
call to C<in>.

=head2 required

    my $value = ConditionClass->required( %arguments );

Creates a new condition object and tries to resolve it. If it can't be
resolved, the condition will be turned into an exception. This method
always return a scalar.

Accepts a hash reference of key/value argument pairs for the condition.

=head2 optional

    my $value = ConditionClass->optional( %arguments );

Creates a new condition object and tries to resolve it. If it can't be
resolved, the condition will return an undefined value. This method always
return a scalar.

Accepts a hash reference of key/value argument pairs for the condition.

=head2 required_from

    my $value = ConditionClass->required_from( \&resolve, %arguments );

Tries to resolve the condition via the code reference given as first
argument. The code reference will receive the C<%arguments> that were
passed in. If the code reference can't immediately resolve the condition,
a condition instance will be created and the handlers get a chance to
resolve it.

If no handler could resolve the condition, it will be thrown as an
exception. This method always returns a scalar. The resolution function is
always called in scalar context.

=head2 optional_from

    my $value = ConditionClass->optional_from( \&resolve, %arguments );

Tries to resolve the condition via the code reference given as first
argument. The code reference will receive the C<%arguments> that were
passed in. If the code reference can't immediately resolve the condition,
a condition instance will be created and the handlers get a chance to
resolve it.

If no handler could resolve the condition, an undefined value will be
returned. This method always returns a scalar. The resolution function is
always called in scalar context.

=head2 retry

    my $value = $condition->retry( %override_arguments );

Retries the resolution function passed in via L</required_from> or
L</optional_from>. If L</required> or l</optional> are used instead and no
function was provided, the L</RESOLVE> method will be called as object
method instead. By default, this is a null operation and returns an
undefined value.

The passed in arguments can override and extend the ones passed in when
the condition was raised. This allows for retrying with different values.
The function always returns a scalar.

=head2 final

    my $final_marker = $condition->final;
    my $final_marker = $condition->final( $value );

Returns a marker that, if returned from a handler, immediately stops the
resolution chain and returns the C<$value> or an undefined value if
nothing was provided to the point at which the condition was raised.

=head2 ACCEPT

    my $is_value_valid = ConditionClass->ACCEPT( $value, $file, $line );

This method determines if the C<$value> satisfies the condition. By
default only an undefined value is unacceptable. The method also receives
the file and (approximate) line number of where the values originates from
for better error handling.

=head2 MATCH

    my $is_match = $condition->MATCH( $value, $file, $line );

Determines if the condition is matched by the C<$value>. By default only
code references are valid match values. All other types will issue an
error. See L<Raisable::Match::Payload> for an extension allowing you to
match against condition attributes.

The method also receives the file and (approximate) line number the match
value is coming from for error handling purposes.

A code reference C<$value> will receive the condition as C<$_> and as
first argument.

=head2 RESOLVE

    my $value = $condition->RESOLVE;

This is basically a fallback routine. If L</require> or L</optional> were
used and no resolution routine supplied, this condition method will be
used to try and resolve the condition before the handlers get invoked. It
is also used on L</retry>.

The method is always called in scalar context and must always return a
scalar value.

=head2 DEFAULT

    my $value = $condition->DEFAULT;

The value of this method is returned when no other acceptable value could
be found. By default, it returns an undefined value.

=head1 CAVEATS

=head2 Context restriction

This module currently assumes and enforces scalar context in most cases.
Invalid value detection would get much more complicated if dynamic context
were provided. Only having to deal with a single context also makes the
code more robust and easier to debug.

=head1 SEE ALSO

=over

=item * L<Throwable>

=item * L<Raisable::Match::Payload>

=item * L<Raisable::Accept::Typed>

=item * L<Moose>

=back

=cut
