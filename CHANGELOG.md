# Changelog

## v1.1.0 (2026-01-22)

#### Compatibility fixes

- Adjust tests to account for unpredictable order of map keys (OTP 26+)
- Replace deprecated `Logger.warn/1` with `Logger.warning/1`
- Replace deprecated `List.zip/1` with `Enum.zip/1`

## v1.0.0 (2023-05-27)

#### Enhancements

- Rescue and reraise BadMapError and ArgumentError as MatchError for error consistency when destructuring. 

## v0.3.1 (2023-05-07)

#### Enhancements

- Add support for string keys, e.g.:

  ```elixir
  @[ a, b, _c] <~ %{
    "a" => 1,
    "b" => 2
  }
  # a => 1
  # b => 2
  # c => nil
  ```

## v0.3.0 (2023-04-29)

#### Enhancements

- Enable map destructuring as a whole even with a subset of keys specified

  When in loose mode we can typically use maps, lists and tuples interchangeably. However, to circumvent a problem that
  cannot be solved without completely redesigning the library (and making its execution much slower), an exception has
  been introduced in this version.
  
  The problem is related to the fact that the library is ultimately relying on pattern matching to associate values
  in a structure on the right (available only at runtime) with the variables on the left side (available for
  manipulation at compile time only). 
  
  To illustrate the problem, consider what the two statements below translate into:
  
  ```elixir
  [ a: a = %{ b}] <~ term
  # translates into:
  [ a: a = %{ b: b}] = adjusted_term
   ```
  
  while
  
  ```elixir
  [ a: a = [ b]] <~ term
  # translates into:
  [ a: a = [ b: b]] = adjusted_term
  ```
  
  The former automatically associates an entire structure in `term` with the variable `a`, not just its subset with the
  variable `b` only, while the latter associates the keyword list with just the `b` key (note: the Extructure logic
  drops all key-value pairs except for the `b` in runtime so the pattern matching does not fail). 
  
  In previous versions the logic used to drop all undeclared keys from the maps as well in order to enforce a behavioral
  similarity with lists and tuples, but this approach came with a tradeoff - not being able to destructure both the
  structure as a whole and some of its elements in a single statement. This is why this restriction has been removed
  in the v0.3.0.
  
#### Bug fixes
  
- Destructure module structure as a whole as the module structure (not as a plain map). 
 
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
