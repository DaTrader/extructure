# Changelog

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
