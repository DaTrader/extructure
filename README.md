# Extructure

Extructure is a flexible destructure library for Elixir.

By default the library is using loose (flexible) matching, allowing for implicit structural conversions (maps, lists and
tuples, from one to another). The key-pair element order in a tuple or a list is also taken loosely by default.   

Toggling from loose to Elixir-default ("rigid") mode is done via the `^` operator.

Optional variables are also supported with or without a default value.

## Installation

```elixir
def deps do
  [
    { :extructure, "~> 1.0.0"}
  ]
end
```

Import the Extructure module in every module where you use it:
```elixir
defmodule Foo do
  # uses, aliases, and imports
  import Extructure
  
  # ..
end
```

## Docs

The docs can be found at [HexDocs](https://hexdocs.pm/extructure).

## Sample usage

#### Fetching two mandatory variables and one optional from the LiveView assigns

Assuming a map of socket assigns, a standard pattern matching followed by retrieving an optional variable is shown
below:

```elixir
%{
  first_name: fist_name,
  last_name: last_name,
} = socket.assigns

age = socket.assigns[ :age]
```

is a one-liner in Extructure:

```elixir
%{ first_name, last_name, _age} <~ socket.assigns
```

#### Implicit transformation between maps, lists and tuples with key pairs

Given the Extructure's loose treatment of structures in terms of their interchangeability, the former can be expressed
in a more readable manner: 

```elixir
{ first_name, last_name, _age} <~ socket.assigns
```

or 

```elixir
[ first_name, last_name, _age] <~ socket.assigns
```

#### Default values

An optional variable can be written as a function taking zero or one arguments, with a single argument being the default
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

{ b, a} <~ { { :a, 1}, { :b, 2}, { :c, 3}}
# => { { :b, 2}, { :a, 1}}
```

#### Flexible keyword list head | tail extraction

```elixir
[ b | rest] <~ [ a: 1, b: 2, c: 3]
# => [ b: 2, a: 1, c: 3]

[ b | [ a, c]] <~ [ a: 1, b: 2, c: 3, d: 4]
# => [ b: 2, a: 1, c: 3]

[ a | [ b, c( 25)]] <~ %{ a: 1, b: 2}
# => [a: 1, b: 2, c: 25]

[ b | %{ c: %{ d}}] <~ [ a: 1, b: 2, c: %{ d: 5}]
# => [ { :b, 2} | %{ a: 1, c: %{ d: 5}}
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
# => [hour: 15, minute: 44, second: 14]
``` 

or with the module key:

```elixir
[ __struct__: module] <~ DateTime.utc_now()
# => [__struct__: DateTime]
```

#### Nesting

Any level of nesting is supported, and with the `^` operator toggling from loose to rigid and vice versa, any matching
combination can be achieved.

Ex from the `extructure_test.ex`:

```elixir
%{ a, b: b = ^{ c, d, ^%{ e}}} <~ [ a: 1, b: { 3, 4, [ e: 5]}]
assert a == 1
assert b == { 3, 4, %{ e: 5}}
assert c == 3
assert d == 4
assert e == 5
```

#### Transforming the entire structure

When in need to extract and transform an entire structure and not just some of its elements, all it takes is specifying
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
variable even if there's only a subset of its variables getting destructured.

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

In addition to atom keys, Extructure supports destructuring from maps, key-value pair lists and key-value pair tuples
with string keys. This feature is useful in such use cases as destructuring JSON properties or params in LiveView.  

All it takes is to prefix the intended part of the expression on the left with a `@` character, e.g.:

```elixir
@[ a] <~ %{ "a" => 1}
# a => 1
```  

Just like `^` can be used in nested structures to toggle from loose to rigid mode and back, `@` can be used to toggle
from atom to string keys and back, e.g.:
   
```elixir
@[ a, b: [ c, d: @[ e]]] <~ %{ "a" => 1, "b" => %{ "c" => 3, "d" => [ e: 5]}}
# a => 1
# c => 3
# e => 5 
```

All matching restrictions apply same as with atom keys. Therefore, missing non-optional variables will result in failure
while missing optional variables will not.

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
@^%{ a} <~ [ { "a", 1}]
# => error
```

## Limitations

#### Optional variables and default values

The original idea was to use the standard `\\` operator to denote optional and default variables in lists, tuples, and 
maps, but, as shown below, the Elixir parser does not support this expression in maps.

```elixir
[ a, b \\ nil] # ok
{ a, b \\ nil} # ok
%{ a, b \\ nil} # syntax error
```

So, decision was made that, until there's a progress with the Elixir parser, the underscore prefixed variable names will
be used for optional variables defaulting to nil, and the function (macro) call syntax will be used for the optional
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

Should the Elixir core team decide to remove the parser restriction, a support for the standard Elixir optional
variables (arguments) would be added and the present notation would be slowly phased out (leaving it to the
compatibility mode).  

## Formatting

The source code formatting in this library diverges from the standard formatting practice based on using `mix format`
in so much that there's a leading space character inserted before each initial argument / element with an intention to
improve the code readability (subject to the author's personal perception).

Another detail diverging from the standard Elixir formatting is that, where present, multi-line function signatures,
and multi-line `for`, `with`, `if`, etc. statements will not have the `do` at the end of the last of the lines but,
instead, indented in a new line, e.g.:

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
