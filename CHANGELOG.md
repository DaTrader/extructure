# Changelog

## v1.3.1 (2026-04-26)

#### Enhancements

- Support `@`-prefix on `+/1` and `-/1` for string keys, mirroring how
  `<~` uses `@` to toggle key type. Both bare-variable shorthand and
  kw-shorthand pairs become string-keyed:

  ```elixir
  a = 1
  b = 2
  +@%{ a, b}                         # => %{ "a" => 1, "b" => 2}
  +@[ a, b: 3]                       # => [ { "a", 1}, { "b", 3}]
  +@{ a, b}                          # => {{ "a", 1}, { "b", 2}}

  -@%{ a, b} = %{ "a" => 1, "b" => 2}
  # a => 1, b => 2

  -@[ a | rest] = [ { "a", 1}, { "b", 2}, { "c", 3}]
  # a => 1, rest => [ { "b", 2}, { "c", 3}]
  ```

  Like the bare-key shorthand, `@` only flips the immediate level —
  consistent with how `+/1` and `-/1` treat nested literals (`<~`
  propagates `@` into nested substructures, but the shorthand operators
  don't, since they don't recurse at all). Apply `@` again at each level
  for nested string keys.

## v1.3.0 (2026-04-26)

#### Enhancements

- Add `Extructure.Shorthand` with `+/1` (shorthand-key construction) and
  `-/1` (exact-type pattern matching) — the inverse and Elixir-strict
  counterparts to `<~`. Bare variables inside `%{ ...}`, `[ ...]`, or
  `{ ...}` literals are expanded to `{key, var}` pairs whose key is the
  variable's name; explicit `key: value` pairs may be mixed in.

  ```elixir
  use Extructure.Shorthand

  a = 1
  b = 2
  +%{ a, b}                      # => %{ a: 1, b: 2}
  +[ a, b: 3]                    # => [ a: 1, b: 3]
  +{ a, b}                       # => {{ :a, 1}, { :b, 2}}

  -%{ a, b} = %{ a: 1, b: 2}     # a => 1, b => 2
  -[ a, b] = [ a: 1, b: 2]       # a => 1, b => 2

  def add(-%{ a, b}), do: a + b
  ```

  `use Extructure.Shorthand` removes `Kernel.+/1` and `Kernel.-/1` from
  scope and imports the operators unambiguously. Both fall through to
  the corresponding `Kernel` operator for any argument shape that isn't a
  structure literal, so `+5` and `-x` keep their standard meaning.

- Support head|tail patterns in `+/1` and `-/1`. Bare-variable heads are
  expanded as shorthand pairs while the tail is left untouched:

  ```elixir
  -[ x | opts] = [ x: 1, y: 2]
  # x => 1, opts => [ y: 2]

  -[ a, b | rest] = [ a: 1, b: 2, c: 3, d: 4]
  # a => 1, b => 2, rest => [ c: 3, d: 4]

  x = 1
  opts = [ y: 2, z: 3]
  +[ x | opts]                   # => [ x: 1, y: 2, z: 3]
  ```

  Note: Elixir's parser rejects keyword shorthand before `|`, so explicit
  pair heads must be written in tuple form: `-[{ :x, 1} | opts] = ...`.

- Add `use Extructure` as a convenience entry point. Equivalent to
  `import Extructure` plus `use Extructure.Shorthand`, so all three
  operators (`<~`, `+/1`, `-/1`) come into scope at once. Use the
  granular forms when only one half is wanted — for instance to avoid
  clashes with another macro in scope, or in an umbrella where different
  apps need different combinations.

  ```elixir
  defmodule UsesAll do
    use Extructure              # `<~`, `+/1`, `-/1`
  end

  defmodule JustExtructure do
    import Extructure           # only `<~`
  end

  defmodule JustShorthand do
    use Extructure.Shorthand    # only `+/1` and `-/1`
  end
  ```

## v1.2.0 (2026-04-25)

#### Enhancements

- Support multi-element head in loose head|tail destructuring. Previously
  only the single-head form `[ a | rest]` worked; now any number of heads
  may be specified before the `|`:

  ```elixir
  [ a, b | rest] <~ [ a: 1, b: 2, c: 3, d: 4]
  # a => 1, b => 2, rest => [ c: 3, d: 4]

  [ a, b, c | rest] <~ [ a: 1, b: 2, c: 3, d: 4, e: 5]
  # a => 1, b => 2, c => 3, rest => [ d: 4, e: 5]
  ```

  Works with map and key-pair tuple right sides as well, and supports a
  structured tail:

  ```elixir
  [ a, b | %{ c, d}] <~ [ a: 1, b: 2, c: 3, d: 4]
  # a => 1, b => 2, c => 3, d => 4
  ```

## v1.1.2 (2026-04-25)

#### Bug fixes

- Allow destructuring `:__struct__` from a struct via list LHS. Previously the
  loose `[ _ | _]` deep-merge path stripped `__struct__` via `Map.from_struct/1`
  before lookup, so `[ __struct__: module] <~ some_struct` silently failed with
  a `MatchError`. The struct now flows through unchanged — Elixir structs
  already behave like maps for `Map.has_key?/2` and `Map.fetch!/2`, so the same
  field lookup works uniformly. This restores the behavior the implementation
  had before the loose-list rewrite in v0.3.0, and aligns with how Elixir's own
  pattern matching treats `__struct__` (`%{ __struct__: m} = some_struct`).

  ```elixir
  # previously raised MatchError; now correctly binds module == Date
  [ __struct__: module] <~ Date.utc_today()
  ```

## v1.1.1 (2026-04-25)

#### Bug fixes

- Fix collision when the right-side data contains `:_` as a value. The internal
  "no contribution" sentinel in the merger structure used to be the atom `:_`,
  which is also a value the user might legitimately have in their data. As a
  result, a key whose right-side value happened to be `:_` was incorrectly
  dropped from the merged structure, causing a spurious `MatchError` (or, for
  optional variables, the actual `:_` value being thrown away in favor of the
  default). The sentinel is now a tagged 2-tuple that the user cannot
  realistically collide with. The atoms `:loose` and `:rigid` were never
  affected but are now covered by tests as well.

  ```elixir
  # previously raised MatchError; now correctly binds a == :_
  %{ a, b} <~ %{ a: :_, b: 2}
  ```

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
