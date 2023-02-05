# Extructure

Extructure is a flexible destructure library for Elixir.

By default the library is using loose (flexible) matching, allowing for implicit structural conversions (maps,
lists and tuples, from one to another). Tuple and list key pair element order are also taken loosely by default.

Toggling from loose to Elixir-default ("rigid") mode is done via the `^` operator.

Optional variables are also supported with or without a default value.

## Installation

```elixir
def deps do
  [
    {:extructure, "~> 0.1.0"}
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

Assuming a map of socket assigns, a standard pattern matching followed by retrieving an optional value as shown below:

```elixir
%{
  first_name: fist_name,
  last_name: last_name,
} = socket.assigns

age = socket.assigns[:age]
```

is a one-liner in Extructure:

```elixir
%{first_name, last_name, _age} <~ socket.assigns
```

#### Implicit transformation between maps, lists and tuples with key pairs

Given the Extructure's loose treatment of structures in terms of their interchangeability, the former can be expressed
in a more readable manner:

```elixir
{first_name, last_name, _age} <~ socket.assigns
```

or

```elixir
[first_name, last_name, _age] <~ socket.assigns
```

#### Default values

An optional variable can be written as a function taking zero or one arguments, with a single argument being the default
value, and/or as the variable name prefixed with a single underscore character `_`.

```elixir
[first_name, last_name, age(25)] <~ socket.assigns
```
or

```elixir
[first_name, last_name, _age(25)] <~ socket.assigns
```

#### Flexible keyword list and tuple of key pairs size and element order

```elixir
[b, a] <~ [a: 1, b: 2, c: 3]
# => [b: 2, a: 1]

{b, a} <~ {{:a, 1}, {:b, 2}, {:c, 3}}
# => {{:b, 2}, {:a, 1}}
```

#### Enforcing "rigid" (Elixir default) matching of the structures

The rigid approach is useful to ensure the Elixir-like matching of the right side, and necessary if deconstructing
standard Elixir tuples.

```elixir
^{a, b, c} <~ {1, 2, 3}
# ok

^{b, a} <~ {{:a, 1}, {:b, 2}, {:c, 3}}
# error

^[b, a] <~ [a: 1, b: 2, c: 3]
# error

^%{a} <~ %{a: 1, b: 2}
# ok
```

#### Nesting

Any level of nesting is supported, and with the `^` operator toggling from loose to rigid and vice versa, any matching
combination can be achieved.

Ex from the `extructure_test.ex`:

```elixir
%{a, b: b = ^{c, d, ^%{e}}} <~ [a: 1, b: {3, 4, [e: 5]}]
assert a == 1
assert b == {3, 4, %{ e: 5}}
assert c == 3
assert d == 4
assert e == 5
```
