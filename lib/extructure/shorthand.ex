defmodule Extructure.Shorthand do
  @moduledoc """
  Shorthand-key construction (`+`) and exact-type pattern matching (`-`)
  for maps, lists, and key-pair tuples. Complements `Extructure.<~/2`
  (loose destructuring) by providing the inverse operation (`+`) and an
  Elixir-strict counterpart for pattern positions like function heads
  (`-`).

  See `+/1` and `-/1`.

  ## Usage

  Both operators override `Kernel`'s unary `+/1` and `-/1`. Use the
  `__using__` macro instead of plain `import` to drop the Kernel versions:

      defmodule MyMod do
        use Extructure.Shorthand
        # +/1 and -/1 are now in scope without ambiguity
      end
  """

  @typep ast() :: Macro.t()

  @doc """
  Drops `Kernel.+/1` and `Kernel.-/1` from scope and imports
  `Extructure.Shorthand` so the shorthand operators can be used
  unambiguously.
  """
  @spec __using__( keyword()) :: Macro.t()
  defmacro __using__( _opts) do
    quote do
      import Kernel, except: [ +: 1, -: 1]
      import Extructure.Shorthand
    end
  end

  @doc """
  Constructs a structure literal from variables using shorthand-key syntax.

  Bare variables inside `%{ ...}`, `[ ...]`, or `{ ...}` are expanded to
  `{key, var}` pairs where the key is the variable's name. Explicit
  `key: value` pairs may be mixed in.

  Falls back to `Kernel.+/1` for any other argument shape, so `+5` and
  `+x` (where `x` is a number) keep their standard Elixir meaning.

  ## Examples

      a = 1
      b = 2
      +%{ a, b}              # => %{ a: 1, b: 2}
      +%{ a, b: 3}           # => %{ a: 1, b: 3}
      +[ a, b]               # => [ a: 1, b: 2]
      +{ a, b}               # => {{ :a, 1}, { :b, 2}}
      +{ a, b: 4, c: 5}      # => {{ :a, 1}, { :b, 4}, { :c, 5}}
      +5                     # => 5  (delegates to Kernel.+/1)

  `+/1` only transforms its immediate argument — values inside the literal
  pass through unchanged. To get shorthand keys at nested levels, apply
  `+` again at each level:

      +%{ a, b: +%{ c, d}}   # => %{ a: 1, b: %{ c: 3, d: 4}}

  Prefix the literal with `@` to use string keys at the immediate level:

      +@%{ a, b}             # => %{ "a" => 1, "b" => 2}
      +@[ a, b]              # => [ {"a", 1}, {"b", 2}]
      +@{ a, b}              # => {{ "a", 1}, { "b", 2}}

  Like the bare-key shorthand, `@` only flips the immediate level; nested
  literals need their own `@` (e.g. `+@%{ a, b: +@%{ c}}`).
  """
  @spec +(ast()) :: ast()
  defmacro +(arg) do
    case maybe_expand( arg) do
      { :ok, ast} ->
        ast

      :passthrough ->
        quote do
          Kernel.+(unquote( arg))
        end
    end
  end

  @doc """
  Pattern-matches a structure literal using shorthand-key syntax — the
  exact-type counterpart to `Extructure.<~/2`'s loose destructure. Useful
  in function heads and any other pattern position:

      def add(-%{ a, b}), do: a + b

  Bare variables inside `%{ ...}`, `[ ...]`, or `{ ...}` are expanded to
  `{key, var}` patterns where the key is the variable's name. Explicit
  `key: value` pairs may be mixed in.

  Unlike `<~/2`, the right side must structurally match — there is no
  loose conversion between maps/lists/tuples and no optional-variable
  support. Use `<~/2` when you want those.

  Falls back to `Kernel.-/1` for any other argument shape.

  ## Examples

      -%{ a, b} = %{ a: 1, b: 2}
      # a = 1, b = 2

      -[ a, b] = [ a: 1, b: 2]
      # a = 1, b = 2

      -{ a, b} = {{ :a, 1}, { :b, 2}}
      # a = 1, b = 2

      -%{ a, b} = %{ a: 1}     # raises MatchError — exact match, no optional

      -5                        # => -5  (delegates to Kernel.-/1)

  Like `+/1`, `-/1` only transforms its immediate argument; nested literals
  pass through. Apply `-` at each level for nested shorthand:

      -%{ a, b: -%{ c, d}} = %{ a: 1, b: %{ c: 3, d: 4}}

  Prefix the literal with `@` to match string keys at the immediate level:

      -@%{ a, b} = %{ "a" => 1, "b" => 2}
      # a => 1, b => 2

      -@[ a, b] = [ {"a", 1}, {"b", 2}]
      # a => 1, b => 2

      -@{ a, b} = {{ "a", 1}, { "b", 2}}
      # a => 1, b => 2

  As with `+/1`, `@` only flips the immediate level; nested literals need
  their own `@`.
  """
  @spec -(ast()) :: ast()
  defmacro -(arg) do
    case maybe_expand( arg) do
      { :ok, ast} ->
        ast

      :passthrough ->
        quote do
          Kernel.-(unquote( arg))
        end
    end
  end

  # Returns `{:ok, expanded_ast}` for any structure-literal AST shape, or
  # `:passthrough` for anything else (so the caller can delegate to Kernel).
  # The `string_keys?` flag is flipped on by an `@`-prefix and converts
  # bare-var and kw-shorthand keys to binaries for the immediate level.
  @spec maybe_expand( ast(), boolean()) :: { :ok, ast()} | :passthrough
  defp maybe_expand( arg, string_keys? \\ false)

  # `@`-prefix toggles string-key mode for the immediate substructure
  defp maybe_expand({ :@, _, [ inner]}, _string_keys?) do
    maybe_expand( inner, true)
  end

  # map literal
  defp maybe_expand({ :%{}, ctx, args}, string_keys?) do
    { :ok, { :%{}, ctx, Enum.map( args, &expand_pair( &1, string_keys?))}}
  end

  # empty list
  defp maybe_expand( [], _string_keys?) do
    { :ok, []}
  end

  # non-empty list — including `[ a, b, ... | tail]` cons patterns
  defp maybe_expand([ _ | _] = args, string_keys?) do
    { :ok, expand_list( args, string_keys?)}
  end

  # 3+ tuple (and empty tuple)
  defp maybe_expand({ :{}, ctx, args}, string_keys?) do
    { :ok, { :{}, ctx, Enum.map( args, &expand_pair( &1, string_keys?))}}
  end

  # 2-tuple where the second element is a kw list — unfold into N+1 pairs
  defp maybe_expand({ first, second}, string_keys?) when not is_atom( first) and is_list( second) do
    if Keyword.keyword?( second) do
      pairs = [ expand_pair( first, string_keys?) | Enum.map( second, &expand_pair( &1, string_keys?))]

      ast =
        case pairs do
          [ a, b] ->
            { a, b}

          _ ->
            { :{}, [], pairs}
        end

      { :ok, ast}
    else
      raise ArgumentError,
            "Cannot interpret tuple `{ #{ Macro.to_string( first)}, #{ Macro.to_string( second)}}` as a shorthand-key tuple."
    end
  end

  # plain 2-tuple
  defp maybe_expand({ first, second}, string_keys?) when not is_atom( first) do
    { :ok, { expand_pair( first, string_keys?), expand_pair( second, string_keys?)}}
  end

  # anything else — let the caller delegate to Kernel
  defp maybe_expand( _other, _string_keys?) do
    :passthrough
  end

  # Walks a list AST element-by-element, expanding each "head" via
  # `expand_pair/2`. A trailing `:|` cons leaves its tail untouched so
  # `[ a, b | rest]` becomes `[ {:a, a}, {:b, b} | rest]` (or string-keyed
  # equivalents when `string_keys?` is true).
  @spec expand_list( [ ast()], boolean()) :: [ ast()]
  defp expand_list( ast, string_keys?)

  defp expand_list([{ :|, ctx, [ head, tail]}], string_keys?) do
    [{ :|, ctx, [ expand_pair( head, string_keys?), tail]}]
  end

  defp expand_list([ head | rest], string_keys?) do
    [ expand_pair( head, string_keys?) | expand_list( rest, string_keys?)]
  end

  defp expand_list( [], _string_keys?) do
    []
  end

  # Expands a single literal element: bare variables become `{name, var_ast}`
  # pairs, existing kv pairs pass through. When `string_keys?` is true, atom
  # names — both bare-var and kw-shorthand — are converted to binaries, and
  # already string-keyed pairs pass through as well. Anything else is
  # rejected at compile time.
  @spec expand_pair( ast(), boolean()) :: ast()
  defp expand_pair( arg, string_keys?)

  defp expand_pair({ name, _, ctx} = var_ast, string_keys?) when is_atom( name) and (is_atom( ctx) or is_nil( ctx)) do
    { maybe_to_string( name, string_keys?), var_ast}
  end

  defp expand_pair({ key, val}, string_keys?) when is_atom( key) do
    { maybe_to_string( key, string_keys?), val}
  end

  defp expand_pair({ key, _} = pair, true) when is_binary( key) do
    pair
  end

  defp expand_pair( other, _string_keys?) do
    raise ArgumentError,
          "Cannot interpret `#{ Macro.to_string( other)}` as a shorthand-key element."
  end

  @spec maybe_to_string( atom(), boolean()) :: atom() | String.t()
  defp maybe_to_string( name, string_keys?)

  defp maybe_to_string( name, true), do: Atom.to_string( name)
  defp maybe_to_string( name, false), do: name
end
