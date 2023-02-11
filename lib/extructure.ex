defmodule Extructure do
  @moduledoc """
  Implementation of the `<~` extructure operator.
  """

  @typep mode() :: :loose | :rigid
  @typep metadata() :: keyword()

  @typep input() ::
           input_expr()
           | { input(), input()}
           | [ input()]
           | atom()
           | number()
           | binary()

  @typep input_expr() :: { input_expr() | atom(), metadata(), atom() | [ input()]}
  @typep dummy() :: :_

  @dummy :_

  @doc """
  Destructures the right hand side expression into and according to the
  left side expression.

  Supports destructure-like implicit keys (with the same name as the
  variable) as well as optional values, flexible keyword and key pair tuple
  size and order of elements, implicit transformation between a map, list
  and a key pair tuple.

  Also supports toggling between the loose mode and the standard Elixir
  pattern matching ("rigid") mode where none of the flexibilities except
  for the optional variables are allowed.

  Fully enforces pattern matching between the left and right side once
  taken into account the optional values and structural transformation.

  When using optional values their key/value pairs are merged with the right
  hand side before applying the assignment.

  #### Features

  - Optional values - Prefix the variable name with an underscore and/or
    declare it as a function with zero arguments. If used, the underscore
    is trimmed from the variable's name e.g. an `_a` is translated to `a`.

  - Optional values - Declare the variable as a function taking the default
    value as its single argument.

  - In the loose (default) mode use the maps, keywords and key-pair tuples
    interchangeably as you see fit.

  - Toggle the loose mode into the rigid mode by using the unary `^` operator
    left to the map, list or tuple that requires Elixir-like pattern matching.
    If requiring a loose matching again at a nested level in the structure,
    use the `^` operator again to toggle back to loose and so on.

  - To match typical tuples, switch to the rigid mode with the `^` operator,
    if only for the tuple in question.

  For nesting, use the keys as you would in plain Elixir matching:

  ```elixir
  %{ a: %{ b}} <~ [ a: %{ b: 2}]
  # a variable is not set
  # b variable is set to 2
  ```
  or
  ```elixir
  %{ a: a = %{ b}} <~ [ a: %{ b: 2}]
  # both a and b variables are set
  ```

  #### Note

  - Variables with specified keys must be (in a keyword list) trailing those
  without the explicit keys:

      ```elixir
      %{ a, b, c: c, d: _d} <~ %{ a: 1, b: 2, c: 3}
      ```
      or
      ```elixir
      [ a, b, c: c, d: _d] <~ %{ a: 1, b: 2, c: 3}
      ```

  - Any errors in the left-side expression are detected in compile time.

  #### Usage

  Instead of:

  ```elixir
  %{
    first_name: fist_name,
    last_name: last_name,
  } = socket.assigns

  age = socket.assigns[ :age]
  ```

  simply use:

  ```elixir
  %{ first_name, last_name, _age} <~ socket.assigns
  ```
  or
  ```elixir
  { first_name, last_name, _age( 25)} <~ socket.assigns
  ```
  or
  ```elixir
  [ first_name, last_name, age( 25)] <~ socket.assigns
  ```

  See the `README.md` and `extructure_test.ex` files for more examples.
  """
  defmacro left <~ right do
    extract( left, right)
  end

  # Extracts (destructures) data from the right side into the left side expression.
  @spec extract( input(), input()) :: Macro.output()
  defp extract( left, right) do
    opts =
      [ mode: :loose]
      |> one_off( var_optionality: "Can't use optional variable outside of an Extructure match.")

    case { left, dig( left, opts)} do
      { _, { term, @dummy}} ->
        quote do
          unquote( term) = unquote( right)
        end

      { _, { term, merger}} ->
        quote do
          unquote( term) = Extructure.deep_merge( unquote( merger), unquote( right))
        end
    end
  end

  # Digs into the left-side expression and returns a tuple with two elements:
  # - a standard elixir left-side expression with all variables associated with their keys,
  #    whether derived from their names or from the explicitly specified keys,
  # - a merger structure derived from the left side expression to deep-merge the right-side
  #   expression into so that
  @spec dig( input(), keyword()) :: { input(), { mode(), input()} | input()}

  # list
  defp dig( args, opts) when is_list( args) do
    opts =
      opts
      |> pair_var( true)
      |> one_off()

    Enum.reduce( args, { [], []}, &prepend_acc( &1, &2, opts))
    |> finalize_acc( opts[ :mode], & &1)
  end

  # map
  defp dig( { :%{}, context, args}, opts) do
    opts =
      opts
      |> pair_var( true)
      |> one_off()

    Enum.reduce( args, { [], []}, &prepend_acc( &1, &2, opts))
    |> finalize_acc( opts[ :mode], &{ :%{}, context, &1})
  end

  # tuple other than a tuple of 2
  defp dig( { :{}, context, args}, opts) do
    opts =
      opts
      |> pair_var( opts[ :mode] == :loose)
      |> one_off()

    Enum.reduce( args, { [], []}, &prepend_acc( &1, &2, opts))
    |> finalize_acc( opts[ :mode], &{ :{}, context, &1})
  end

  # tuple of 2 special case, but not key/value pair
  defp dig( { first, second}, opts) when not is_atom( first) do
    opts =
      opts
      |> pair_var( opts[ :mode] == :loose)
      |> one_off()

    Enum.reduce( [ first, second], { [], []}, &prepend_acc( &1, &2, opts))
    |> finalize_acc( opts[ :mode], fn
      [ first, second] ->
        { first, second}

      list ->
        { :{}, [], List.to_tuple( list)}
    end)
  end

  # matching
  defp dig( { :=, context, args}, opts) do
    opts =
      opts
      |> pair_var( false)
      |> one_off( var_optionality: "Can't use optional variable in an Elixir match")

    Enum.reduce( args, { [], []}, &prepend_acc( &1, &2, opts))
    |> finalize_acc(
      nil,
      fn args ->
        { :=, context, args}
      end,
      fn
        [ @dummy, right] ->
          right

        [ left, @dummy] ->
          left

        [ _left, _right] = args ->
          { :=, context, args}
      end
     )
  end

  # list head | tail matching
  defp dig( { :|, context, args}, opts) do
    opts = one_off( opts)

    [ head, tail] = args
    { head_args, head_merger} = dig( head, opts)
    { tail_args, tail_merger} = dig( tail, pair_var( opts, false))
    args = [ head_args, tail_args]
    merger = [ head_merger, tail_merger]
    { { :|, context, args}, { :|, context, merger}}
  end

  # toggles structural matching on and off
  defp dig( { :^, _context, args}, opts) do
    opts =
      opts
      |> pair_var( true)
      |> toggle_match_mode()

    [ arg] = args
    dig( arg, opts)
  end

  # standalone variable (without a key)
  defp dig( { var_key, _, _} = variable, opts) when is_atom( var_key) do
    cond do
      opts[ :pair_var] ->
        interpret_var( {}, variable, opts)

      optional_variable?( variable) ->
        raise_on_no_optional( variable, opts)
        { trim_underscore( variable), @dummy}

      true ->
        { trim_underscore( variable), @dummy}
    end
  end

  # other key/term pair
  defp dig( { key, term}, opts) when is_atom( key) do
    opts = pair_var( opts, true)

    case { term, dig( term, opts)} do
      { { :^, _, _}, { term, @dummy}} ->
        { { key, term}, { key, @dummy}}

      { { :^, _, _}, { term, merger}} ->
        { { key, term}, { key, merger}}

      { { _, _, _}, { { _, _}, _}} ->
        interpret_var( { key}, term, opts)

      { _, { term, @dummy}} ->
        { { key, term}, { key, @dummy}}

      { _, { term, merger}} ->
        { { key, term}, { key, merger}}
    end
  end

  # everything else
  defp dig( other, _opts) do
    { other, @dummy}
  end

  # Instructs interpreting sole variables as key pairs or leaving them as they are.
  @spec pair_var( keyword(), boolean()) :: keyword()
  defp pair_var( opts, true) do
    Keyword.put( opts, :pair_var, true)
  end

  defp pair_var( opts, false) do
    Keyword.delete( opts, :pair_var)
  end

  # Sets one off options valid for just the next nested AST level.
  @spec one_off( keyword(), keyword() | nil) :: keyword()
  defp one_off( opts, one_off \\ nil)
  defp one_off( opts, one_off) when one_off in [ nil, []] do
    Keyword.delete( opts, :one_off)
  end

  defp one_off( opts, one_off) do
    Keyword.put( opts, :one_off, one_off)
  end

  # Toggles structural matching mode from rigid to loose and vice versa.
  # Raises KeyError if :mode not found in options.
  @spec toggle_match_mode( keyword()) :: keyword()
  defp toggle_match_mode( opts) do
    update_in( opts[ :mode], fn
      :rigid ->
        :loose

      :loose ->
        :rigid

      nil ->
        raise KeyError, key: :mode, term: "dig options"
    end)
  end

  # Interprets a variable with an optionally provided key to override
  # the variable name as a key.
  # Since nil is a valid key, we use a key holding tuple that can have
  # 0 or 1 elements.
  @spec interpret_var( {} | { atom()}, tuple(), keyword()) ::
          { { atom(), tuple()}, { atom(), dummy()}} |
          { { atom(), tuple()}, { atom(), any()}}
  defp interpret_var( key_holder, variable, opts) do
    case { key_holder, variable_with_value( variable, opts)} do
      { {}, { { var_key, _, _} = variable, default_value}} ->
        kv_with_optional_merger( var_key, variable, default_value)

      { { key}, { variable, default_value}} ->
        kv_with_optional_merger( key, variable, default_value)
    end
  end

  defp kv_with_optional_merger( key, variable, default_value) do
    { { key, variable}, { key, default_value}}
  end

  # Returns a variable with its default value.
  # The `_` prefix in an optional variable name is trimmed.
  @spec variable_with_value( { atom(), list(), nil | list()}, keyword()) :: { input_expr(), input() | dummy()}
  defp variable_with_value( { _, _, [ _ | [ _ | _]]} = term, _) do
    raise "Term `#{ Macro.to_string( term)}` is not a variable."
  end

  defp variable_with_value( { _, _, _} = variable, opts) do
    { var_key, context, default_value_holder} = variable
    new_variable = { var_key, context, nil}

    if optional_variable?( variable) do
      raise_on_no_optional( new_variable, opts)
      { trim_underscore( new_variable), default_value( default_value_holder)}
    else
      { new_variable, @dummy}
    end
  end

  defp default_value( default_value_holder) do
    default_value_holder && List.first( default_value_holder)
  end

  # Verifies if a variable is an optional one
  @spec optional_variable?( input_expr()) :: boolean()
  defp optional_variable?( { var_key, _, args}) when is_atom( var_key) do
    is_list( args) or String.starts_with?( Atom.to_string( var_key), "_")
  end

  # Raises if a reason was provided why a var cannot be optional.
  @spec raise_on_no_optional( input_expr(), keyword()) :: :ok | no_return()
  defp raise_on_no_optional( variable, opts) do
    if reason = opts[ :one_off][ :var_optionality] do
      raise ArgumentError, "#{ inspect( reason)}: #{ Macro.to_string( variable)}."
    else
      :ok
    end
  end

  # Trims a prefixed underscore if any in a variable name.
  @spec trim_underscore( input_expr()) :: input_expr()
  defp trim_underscore( { var_key, context, args} = variable) when is_atom( var_key) do
    case Atom.to_string( var_key) do
      "_" <> var_str ->
        { String.to_atom( var_str), context, args}

      _ ->
        variable
    end
  end

  # prepends a dug macro arg to args and mergers in the acc
  @spec prepend_acc( input(), acc, keyword()) :: acc
        when acc: { [ input()], [ input()]}
  defp prepend_acc( left, acc, opts) do
    { args, mergers} = acc
    { arg, merger} = dig( left, opts)
    { [ arg | args], [ merger | mergers]}
  end

  # reverses args and, unless @dummy, optionals too
  @spec finalize_acc( { list(), list()}, mode() | nil, creator, creator | nil) ::
          { input(), input() | { mode(), input()}}
        when creator: ( list() -> input())
  defp finalize_acc( acc, mode, creates_left, creates_merger \\ nil) do
    creates_merger = creates_merger || creates_left
    { left_args, merger_args} = acc
    left = creates_left.( Enum.reverse( left_args))
    merger = creates_merger.( Enum.reverse( merger_args))

    { left, mode && { mode, merger} || merger}
  end

  # Deep-merges a map, Keyword or a tuple on the right into a map, Keyword or tuple on the left.
  # If the mode is loose, the right side structure is merged loosely into the left structure,
  # while if it is rigid, it is merged according to the Elixir matching rules.
  # Note: when merging without a mode on the left, it means, its a default value.
  @doc false
  @spec deep_merge( { mode(), type_left} | type_left, type_right) :: type_left | no_return()
        when type_left: type,
             type_right: type,
             type: map() | keyword() | tuple()

  # loose map
  def deep_merge( { :loose, %{} = left}, right) do
    Map.merge( left, to_map( right), &deep_resolve/3)
    |> Map.reject( &dummy?( &1))
  end

  # rigid map
  def deep_merge( { :rigid, %{} = left}, right) do
    Map.merge( left, right, &deep_resolve/3)
    |> Map.reject( &dummy?( &1))
  end

  # improper loose list with any tail
  def deep_merge( { :loose, [ head | @dummy]}, right) do
    [ head] = deep_merge( { :loose, [ head]}, right)
    tail = delete_pair( right, head)
    [ head | to_list( tail)]
  end

  # improper loose list with tail to extructure
  def deep_merge( { :loose, [ head | { mode, _} = tail]}, right) when mode in [ :loose, :rigid] do
    [ head] = deep_merge( { :loose, [ head]}, right)
    tail = deep_merge( tail, delete_pair( right, head))
    [ head | tail]
  end

  # loose list
  def deep_merge( { :loose, left}, right) when is_list( left) do
    left_keys = Keyword.keys( left)

    merged =
      Keyword.merge( left, to_list( right), &deep_resolve/3)
      |> Keyword.reject( &dummy?( &1))
      |> Keyword.reject( fn { k, _} -> k not in left_keys end)

    Enum.map( left_keys, &{ &1, merged[ &1]})
  end

  # rigid list
  def deep_merge( { :rigid, left}, right) when is_list( left) do
    Keyword.merge( left, right, &deep_resolve/3)
    |> Keyword.reject( &dummy?( &1))
  end

  # loose tuple
  def deep_merge( { :loose, left}, right) when is_tuple( left) do
    deep_merge( { :loose, Tuple.to_list( left)}, right)
    |> List.to_tuple()
  end

  # rigid tuple with another same-sized rigid tuple
  def deep_merge( { :rigid, left}, right)
      when is_tuple( left) and
           is_tuple( right) and
           tuple_size( left) == tuple_size( right)
    do
    List.zip( [ Tuple.to_list( left), Tuple.to_list( right)])
    |> Enum.map( fn { left, right} ->
      deep_resolve( nil, left, right)
    end)
    |> List.to_tuple()
  end

  # rigid tuple with any other structure
  def deep_merge( { :rigid, left}, right) when is_tuple( left) do
    raise MatchError, term: right
  end

  # Merging with a default value
  def deep_merge( left, nil), do: left
  def deep_merge( _left, right), do: right

  # Merge recursively if the key exists in both structures.
  defp deep_resolve( _key, left, right)
       when ( is_map( left) or is_list( left) or is_tuple( left)) and
            ( is_map( right) or is_list( right) or is_tuple( right))
    do
    deep_merge( left, right)
  end
  defp deep_resolve( _key, _left, right), do: right

  # Skip element marked as dummy.
  defp dummy?( { _, @dummy}), do: true
  defp dummy?( { _, _}), do: false

  # Transform keyword list or tuple into map
  defp to_map( %{} = map), do: map
  defp to_map( kw) when is_list( kw), do: Map.new( kw)
  defp to_map( tuple) when is_tuple( tuple), do: to_list( tuple) |> Map.new()

  # Transform map or tuple into keyword list.
  defp to_list( kw) when is_list( kw), do: kw
  defp to_list( %{} = map), do: Keyword.new( map)
  defp to_list( tuple) when is_tuple( tuple), do: Tuple.to_list( tuple)

  # Delete key pair from a structure
  defp delete_pair( kw, pair) when is_list( kw), do: List.delete( kw, pair)
  defp delete_pair( %{} = map, pair), do: Map.delete( map, elem( pair, 0))
  defp delete_pair( tuple, pair) when is_tuple( tuple) do
    tuple
    |> Tuple.to_list()
    |> delete_pair(pair)
    |> List.to_tuple()
  end
end
