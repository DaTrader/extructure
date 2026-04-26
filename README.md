# Extructure

Extructure is a flexible destructure library for Elixir.

By default, the library uses loose (flexible) matching, allowing for implicit structural conversions between maps, lists,
and tuples. The order of key-pair elements in a tuple or list is also taken loosely by default.   

Toggling from loose to Elixir-default ("rigid") mode is done via the `^` operator.

Optional variables are also supported with or without a default value.

## Installation

```elixir
def deps do
  [
    { :extructure, "~> 1.3"}
  ]
end
```

There are three ways to bring the operators into scope, depending on
which ones you need:

```elixir
defmodule Foo do
  import Extructure          # only `<~`
  # ..
end

defmodule Bar do
  use Extructure.Shorthand   # only `+/1` and `-/1`
  # ..
end

defmodule Baz do
  use Extructure             # all three: `<~`, `+/1`, `-/1`
  # ..
end
```

`use Extructure` is the convenience form — equivalent to
`import Extructure` plus `use Extructure.Shorthand`. Use the granular
forms when only one half is wanted, for example to avoid clashes with
another macro in scope, or in an umbrella where different apps need
different combinations. No application config involved.

## Docs

The docs can be found at [HexDocs](https://hexdocs.pm/extructure).

## Sample usage

#### Fetching two mandatory variables and one optional from the LiveView assigns

Assuming a map of socket assigns, standard pattern matching followed by retrieving an optional variable is shown
below:

```elixir
%{
  first_name: first_name,
  last_name: last_name,
} = socket.assigns

age = socket.assigns[ :age]
```

is a one-liner in Extructure:

```elixir
%{ first_name, last_name, _age} <~ socket.assigns
```

#### Implicit transformation between maps, lists and tuples with key pairs

Given Extructure's loose treatment of structures in terms of their interchangeability, the former can be expressed
in a more readable manner: 

```elixir
{ first_name, last_name, _age} <~ socket.assigns
```

or 

```elixir
[ first_name, last_name, _age] <~ socket.assigns
```

#### Default values

An optional variable can be written as a function taking zero or one argument, with the single argument being the default
value, and/or as the variable name prefixed with a single underscore character `_`.

```elixir
[ first_name, last_name, age( 25)] <~ socket.assigns
```
or

```elixir
[ first_name, last_name, _age( 25)] <~ socket.assigns
```

#### Flexible keyword list or tuple size and element order

```elixir
[ b, a] <~ [ a: 1, b: 2, c: 3]
# => [ b: 2, a: 1]

{ b, a} <~ {{ :a, 1}, { :b, 2}, { :c, 3}}
# => {{ :b, 2}, { :a, 1}}
```

#### Flexible keyword list head | tail extraction

Both single-element and multi-element heads are supported:

```elixir
[ b | rest] <~ [ a: 1, b: 2, c: 3]
# => [ b: 2, a: 1, c: 3]

[ a, b | rest] <~ [ a: 1, b: 2, c: 3, d: 4]
# => [ a: 1, b: 2, c: 3, d: 4]

[ b | [ a, c]] <~ [ a: 1, b: 2, c: 3, d: 4]
# => [ b: 2, a: 1, c: 3]

[ a | [ b, c( 25)]] <~ %{ a: 1, b: 2}
# => [ a: 1, b: 2, c: 25]

[ b | %{ c: %{ d}}] <~ [ a: 1, b: 2, c: %{ d: 5}]
# => [{ :b, 2} | %{ a: 1, c: %{ d: 5}}]
```

#### Fetching non-optional values

```elixir
foo = Keyword.fetch!( opts, :foo)
bar = Keyword.fetch!( opts, :bar)
baz = Keyword.fetch!( opts, :baz)
```

or

```elixir
foo = Map.fetch!( opts, :foo)
bar = Map.fetch!( opts, :bar)
baz = Map.fetch!( opts, :baz)
```

can both be written simply as:

```elixir
[ foo, bar, baz] <~ opts
# => fails if any of the three is not present in the opts
```

#### Enforcing "rigid" (Elixir default) matching of the structures   

The rigid approach is useful to ensure an Elixir-like matching of the right side, and necessary if deconstructing
standard Elixir tuples or non-keyword lists.

```elixir
^{ a, b, c} <~ { 1, 2, 3}
# ok

^[ a, b, c] <~ [ 1, 2, 3]
# ok

^{ b, a} <~ { 1, 2, 3}
# error

^[ a, b, c, d] <~ [ 1, 2, 3]
# error 

^[ a, b, c: c] <~ [ 1, 2, 3]
# error

^%{ a} <~ %{ a: 1, b: 2}
# ok
```

#### Destructuring from module (named) structures

This is similar to destructuring from a map:

```elixir
[ hour, minute, second] <~ DateTime.utc_now()
# => [ hour: 15, minute: 44, second: 14]
``` 

or with the module key:

```elixir
[ __struct__: module] <~ DateTime.utc_now()
# => [ __struct__: DateTime]
```

#### Nesting

Any level of nesting is supported, and with the `^` operator toggling from loose to rigid and vice versa, any matching
combination can be achieved.

Example from `extructure_test.exs`:

```elixir
%{ a, b: b = ^{ c, d, ^%{ e}}} <~ [ a: 1, b: { 3, 4, [ e: 5]}]
assert a == 1
assert b == { 3, 4, %{ e: 5}}
assert c == 3
assert d == 4
assert e == 5
```

#### Transforming the entire structure

When you need to extract and transform an entire structure and not just some of its elements, all it takes is specifying
an empty target structure (similar to `Enum.into/2`, but consistent with the Extructure syntax, so that nesting is
supported along with any other destructuring variables).

Ex:  

```elixir
[ a: a = []] <~ [ a: [ b: 2, c: 3]]
# a
# => %{ b: 2, c: 3}
``` 
or
```elixir
a = [] <~ %{ b: 2, c: 3}
# => [ b: 2, c: 3]
```

#### An exceptional treatment of maps

Unlike with lists and tuples, with maps the entire structure is transformed and associated with the corresponding
variable even if only a subset of its keys is being destructured.

Ex with destructuring into a map:

```elixir
[ a: a = %{ b}] <~ [ a: [ b: 2, c: 3]]
# a => %{ b: 2, c: 3}
# b => 2
``` 

Ex with destructuring into a list (same for tuples):

```elixir
[ a: a = [ b]] <~ [ a: [ b: 2, c: 3]]
# a => [ b: 2]
# b => 2
```

#### String keys

In addition to atom keys, Extructure supports destructuring from maps, key-value pair lists, and key-value pair tuples
with string keys. This is useful in cases such as destructuring JSON properties or params in LiveView.  

All it takes is to prefix the intended part of the expression on the left with a `@` character, e.g.:

```elixir
@[ a] <~ %{ "a" => 1}
# a => 1
```  

Just as `^` can be used in nested structures to toggle from loose to rigid mode and back, `@` can be used to toggle
from atom to string keys and back, e.g.:
   
```elixir
@[ a, b: [ c, d: @[ e]]] <~ %{ "a" => 1, "b" => %{ "c" => 3, "d" => [ e: 5]}}
# a => 1
# c => 3
# e => 5 
```

All matching restrictions apply the same as with atom keys. Therefore, missing non-optional variables will result in
failure while missing optional variables will not.

```elixir
@[ a] <~ %{ "b" => 2}
# => error

@[ a( 1)] <~ %{ "b" => 2}
# a => 1
```

Key type toggling can be used in combination with mode toggling when needed, e.g.:

```elixir
@^%{ a} <~ %{ "a" => 1}
# => a = 1
``` 

```elixir
@^%{ a} <~ [{ "a", 1}]
# => error
```

## Shorthand operators

The companion `Extructure.Shorthand` module provides two operators that
complement `<~`:

- `+/1` — constructs a structure literal from variables using
  shorthand-key syntax. The construction direction.
- `-/1` — pattern-matches a structure literal using shorthand-key
  syntax. The Elixir-strict counterpart to `<~`, useful in function
  heads and any other pattern position.

Both operators are brought into scope via `use Extructure.Shorthand` (or
`use Extructure` for the all-in-one).

#### Construction with `+/1`

Bare variables inside `%{ ...}`, `[ ...]`, or `{ ...}` are expanded to
`{key, var}` pairs whose key is the variable's name. Explicit
`key: value` pairs may be mixed in.

```elixir
a = 1
b = 2

+%{ a, b}              # => %{ a: 1, b: 2}
+%{ a, b: 3}           # => %{ a: 1, b: 3}
+[ a, b]               # => [ a: 1, b: 2]
+{ a, b}               # => {{ :a, 1}, { :b, 2}}
```

`+/1` only transforms its immediate argument — nested literals pass
through unchanged. To get shorthand keys at nested levels, apply `+`
again at each level:

```elixir
+%{ a, b: +%{ c, d}}   # => %{ a: 1, b: %{ c: 3, d: 4}}
```

`+/1` falls through to `Kernel.+/1` for any argument shape that isn't a
structure literal, so `+5` and `+x` (where `x` is a number) keep their
standard meaning.

#### Pattern matching with `-/1`

The pattern counterpart to `+/1`. Bare variables inside `%{ ...}`,
`[ ...]`, or `{ ...}` are expanded to `{key, var}` patterns:

```elixir
-%{ a, b} = %{ a: 1, b: 2}
# a => 1, b => 2

-[ a, b] = [ a: 1, b: 2]
# a => 1, b => 2

-{ a, b} = {{ :a, 1}, { :b, 2}}
# a => 1, b => 2

def add(-%{ a, b}), do: a + b
```

Unlike `<~`, the right side must structurally match — there is no loose
conversion between maps, lists, and tuples and no optional-variable
support. Use `<~` when those are needed.

`-/1` falls through to `Kernel.-/1` for any argument shape that isn't a
structure literal.

#### Head | tail in `+/1` and `-/1`

Bare-variable heads are expanded as shorthand pairs while the tail is
left untouched:

```elixir
-[ x | opts] = [ x: 1, y: 2]
# x => 1, opts => [ y: 2]

-[ a, b | rest] = [ a: 1, b: 2, c: 3, d: 4]
# a => 1, b => 2, rest => [ c: 3, d: 4]

x = 1
opts = [ y: 2, z: 3]
+[ x | opts]           # => [ x: 1, y: 2, z: 3]
```

Note: Elixir's parser rejects keyword shorthand before `|`, so an
explicit pair head must be written in tuple form:

```elixir
-[{ :x, 1} | opts] = [ x: 1, y: 2]
# opts => [ y: 2]
```

This is a parser limitation, not a library one.

## Limitations

#### Optional variables and default values

The original idea was to use the standard `\\` operator to denote optional and default variables in lists, tuples, and 
maps, but, as shown below, the Elixir parser does not support this expression in maps.

```elixir
[ a, b \\ nil] # ok
{ a, b \\ nil} # ok
%{ a, b \\ nil} # syntax error
```

So the decision was made that, until there's progress with the Elixir parser, the underscore-prefixed variable names
will be used for optional variables defaulting to nil, and the function (macro) call syntax will be used for optional
variables defaulting to nil or any other value, e.g.:

```elixir
%{ _a} # optional variable, defaults to nil
%{ a()} # ditto
%{ a( 25)} # optional variable, defaults to 25 
%{ _a( 25)} # ditto
```

The above syntax is used uniformly with all three types (maps, lists, tuples).           

The limitation that comes with this approach is that user-defined macro calls cannot be placed within the left-side
expression.

Should the Elixir core team decide to remove the parser restriction, support for the standard Elixir optional
variables (arguments) would be added and the present notation would be slowly phased out (left in for compatibility).  

## Formatting

The source code formatting in this library diverges from the standard `mix format` practice in that there's a leading
space character inserted before each initial argument / element, intended to improve readability (subject to the
author's personal perception).

Another detail diverging from the standard Elixir formatting is that, where present, multi-line function signatures
and multi-line `for`, `with`, `if`, etc. statements will not have the `do` at the end of the last line but, instead,
indented on a new line, e.g.:

```elixir
with { _, foo} <- get_foo( a, b, c),
     { _, bar} <- foo_to_bar( foo)
  do
  # logic
else
  _ ->
    x    
end
```

The preferred width is 120 characters for the code and 80 characters for the docs.
