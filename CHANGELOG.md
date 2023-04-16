# Changelog

## v0.2.2 (2023-04-16)

#### Bug fixes

- Fix the flaw with a list or a tuple not failing when non optional variables are missing. The following used to pass
  but now fails as supposed to:

  ```elixir
  [ a ] <~ [ b: 1]
  # => MatchError
  ```

- Fix the flaw with rigid list and tuple not supporting unnamed underscore variables.

  ```elixir
  [ x: ^{ a, _, _, d}] <~ %{ x: { 1, 2, 3, 4}}
  # => [x: {1, 2, 3, 4}]
  # a
  # => 1
  # d
  # => 4
  ```

## v0.2.1 (2023-02-26)

#### Enhancements

- Support transforming entire structures on the right side by specifying an empty map, tuple or list, e.g.:

  ```elixir
  [ a: a = %{}] <~ [ a: [ b: 2, c: 3]]
  # a
  # => %{b: 2, c: 3}
  ``` 

- Support destructuring from module (named) structures as if plain maps, e.g:
  
  ```elixir
  [ a, b] <~ %Foo{ a: 1, b: 2}
  # => [a: 1, b: 2]
  ```

#### Bug fixes

- Make maps on the left dictate the keys to merge in the same way lists and tuples do.  

## v0.2.0 (2023-02-19)

#### Breaking Changes

- Make rigid lists match identically as in standard Elixir matching. It is necessary to depart from any looseness in
  rigid lists as otherwise, a standard pattern matching based destructuring is not possible (always converting
  the variables to variable pairs).

  Ex:
  ```elixir
  ^[ a, b] <~ [ 1, 2]
  # => [ 1, 2]
  
  ^[ a, b] <~ [ 1, 2, 3]
  # => MatchError
  ```
  
#### Deprecations

- Warn when optional variables used with rigid lists or tuples for it no longer makes no sense.

## v0.1.1 (2023-02-11)

#### Enhancements

- Added support for head | tail destructure e.g.
  ```elixir
  [ b | rest] <~ [ a: 1, b: 2, c: 3]
  # => [ b: 2, a: 1, c: 3]
  ```

## v0.1.0 (2023-02-05)

- Initial implementation
