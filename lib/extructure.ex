defmodule Extructure do
  @moduledoc """
  Implementation of the `<~` extructure operator.
  """
  alias Extructure.DigOpts
  require Logger

  @typep mode() :: :loose | :rigid
  @typep head_tail() :: maybe_improper_list()

  @typep input() ::
           input_expr()
           | { input(), input()}
           | [ input()]
           | atom()
           | number()
           | binary()

  @typep metadata() :: keyword()
  @typep input_expr() :: { input_expr() | atom(), metadata(), atom() | [ input()]}
  @typep dummy() :: :_

  @dummy :_

  @doc """
  Destructures the right hand side expression into and according to the
  left side expression.

  Supports destructure-like implicit keys (with the same name as the
  variable) as well as optional variables, flexible keyword and key-pair tuple
  size and order of elements, implicit transformations between a map, list
  and a key pair tuple.

  Also supports toggling between the loose mode and the standard Elixir
  pattern matching ("rigid") mode where none of the flexibilities are allowed.

  Fully enforces pattern matching between the left and the right side once
  taken into account the optional variables and structural transformation.

  #### Features

  - Optional variables - Prefix the variable name with an underscore and/or
    declare it as a function with zero arguments. If used, the underscore
    is trimmed from the variable's name e.g. an `_a` is translated to `a`.

  - Optional variables - Declare the variable as a function taking the default
    value as its single argument.

  - In the loose (default) mode use maps, keywords and key-pair tuples
    interchangeably as you see fit.

  - Toggle the loose mode into the rigid mode by using the unary `^` operator
    left to a map, list or tuple that requires Elixir-like pattern matching.
    If requiring a loose matching again at a nested level in the structure,
    use the `^` operator again to toggle back to loose and so on.

  - To match typical tuples or non-keyword lists, switch to the rigid mode with
    the `^` operator, if only for the tuple in question.

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

  - Variables with specified keys must be placed (in a keyword list) trailing
    the ones without the explicit keys:

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

  See the `README.md` and `extructure_test.exs` files for more examples.
  """
  defmacro left <~ right do
    extract( left, right)
  end

  # Extracts (destructures) data from the right side into the left side expression.
  @spec extract( input(), input()) :: Macro.output()
  defp extract( left, right) do
    opts =
      DigOpts.new(
        mode: :loose,
        pair_var: false,
        one_off: []
      )
      |> DigOpts.one_off( var_optionality: "Can't use optional variable outside of an Extructure match.")

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
  @spec dig( input(), DigOpts.t()) :: { input(), { mode(), input()} | input()}

  # empty list (transform the entire structure)
  defp dig( [] = args, opts) do
    dig_args( args, opts.mode, opts, fn _ -> { @dummy, [], nil} end, & &1)
  end

  # list
  defp dig( [ _ | _] = args, opts) do
    opts =
      opts
      |> DigOpts.pair_var( opts.mode == :loose)
      |> DigOpts.one_off()

    dig_args( args, opts.mode, opts, & &1)
  end

  # empty map (transform the entire structure)
  defp dig( { :%{}, context, [] = args}, opts) do
    dig_args( args, opts.mode, opts, fn _ -> { @dummy, [], nil} end, &{ :%{}, context, &1})
  end

  # map
  defp dig( { :%{}, context, args}, opts) do
    opts =
      opts
      |> DigOpts.pair_var( true)
      |> DigOpts.one_off()

    dig_args( args, opts.mode, opts, &{ :%{}, context, &1})
  end

  # empty tuple (transform the entire structure)
  defp dig( { :{}, context, [] = args}, opts) do
    dig_args( args, opts.mode, opts, fn _ -> { @dummy, [], nil} end, &{ :{}, context, &1})
  end

  # tuple other than a tuple of 2
  defp dig( { :{}, context, args}, opts) do
    opts =
      opts
      |> DigOpts.pair_var( opts.mode == :loose)
      |> DigOpts.one_off()

    dig_args( args, opts.mode, opts, &{ :{}, context, &1})
  end

  # tuple of 2 special case, but not key/value pair
  defp dig( { first, second}, opts) when not is_atom( first) do
    opts =
      opts
      |> DigOpts.pair_var( opts.mode == :loose)
      |> DigOpts.one_off()

    dig_args( [ first, second], opts.mode, opts, fn
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
      |> DigOpts.pair_var( false)
      |> DigOpts.one_off( var_optionality: "Can't use optional variable in an Elixir match")

    dig_args( args, nil, opts, &{ :=, context, &1}, fn
      [ @dummy, right] ->
        right

      [ left, @dummy] ->
        left

      [ _left, _right] = args ->
        { :=, context, args}
    end)
  end

  # list head | tail matching
  defp dig( { :|, context, args}, opts) do
    opts = DigOpts.one_off( opts)

    [ head, tail] = args
    { head_args, head_merger} = dig( head, opts)
    { tail_args, tail_merger} = dig( tail, DigOpts.pair_var( opts, false))
    args = [ head_args, tail_args]
    merger = [ head_merger, tail_merger]
    { { :|, context, args}, { :|, context, merger}}
  end

  # toggles structural matching on and off
  defp dig( { :^, _context, args}, opts) do
    opts =
      opts
      |> DigOpts.pair_var( true)
      |> DigOpts.toggle_mode()

    [ arg] = args
    dig( arg, opts)
  end

  # standalone variable (without a key)
  defp dig( { var_key, context, _} = variable, opts) when is_atom( var_key) do
    cond do
      opts.pair_var ->
        interpret_var( {}, variable, opts)

      opts.mode == :rigid and match?( { @dummy, _, _}, variable) ->
        { variable, @dummy}

      match?( { @dummy, _, _}, variable) ->
        Logger.warn "Unnamed underscore variable makes no sense in a loose match: #{ inspect( context)}"

      optional_variable?( variable) ->
        raise_on_no_optional( variable, opts)
        variable = trim_underscore( variable)

        if opts.mode == :rigid do
          Logger.warn(
            "Optional variable #{ Macro.to_string( variable)} makes no sense in a rigid match: #{ inspect( context)}"
          )
        end

        { variable, @dummy}

      true ->
        { trim_underscore( variable), @dummy}
    end
  end

  # other key/term pair
  defp dig( { key, term}, opts) when is_atom( key) do
    opts = DigOpts.pair_var( opts, true)

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

  # Applies the args creation and merger creation functions to each individual
  # argument and merger dug up.
  @spec dig_args( list(), mode() | nil, DigOpts.t(), creator, creator | nil) :: { input(), input() | { mode(), input()}}
        when creator: ( list() -> input())
  defp dig_args( args, mode, opts, creates_left, creates_merger \\ nil) do
    { left_args, merger_args} = Enum.reduce( args, { [], []}, &prepend_acc( &1, &2, opts))
    creates_merger = creates_merger || creates_left
    left = creates_left.( Enum.reverse( left_args))
    merger = creates_merger.( Enum.reverse( merger_args))

    { left, mode && { mode, merger} || merger}
  end

  # prepends a dug macro arg to args and mergers in the acc
  @spec prepend_acc( input(), acc, DigOpts.t()) :: acc
        when acc: { [ input()], [ input()]}
  defp prepend_acc( left, acc, opts) do
    { args, mergers} = acc
    { arg, merger} = dig( left, opts)
    { [ arg | args], [ merger | mergers]}
  end

  # Interprets a variable with an optionally provided key to override
  # the variable name as a key.
  # Since nil is a valid key, we use a key holding tuple that can have
  # 0 or 1 elements.
  @spec interpret_var( {} | { atom()}, tuple(), DigOpts.t()) ::
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
  @spec variable_with_value( { atom(), list(), nil | list()}, DigOpts.t()) :: { input_expr(), input() | dummy()}
  defp variable_with_value( { _, _, [ _ | [ _ | _]]} = term, _) do
    raise "Term `#{ Macro.to_string( term)}` is not an acceptable variable."
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
  @spec raise_on_no_optional( input_expr(), DigOpts.t()) :: :ok | no_return()
  defp raise_on_no_optional( variable, opts) do
    if reason = opts.one_off[ :var_optionality] do
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

  defguard is_mode( mode) when mode in [ :loose, :rigid]

  # Deep-merges a map, Keyword or a tuple on the right into a map, Keyword or tuple on the left.
  # If the mode is loose, the right side structure is merged loosely into the left structure,
  # while if it is rigid, it is merged according to the Elixir matching rules.
  # Note: when merging without a mode on the left, it means, its a default value.
  @doc false
  @spec deep_merge( { mode(), type_left} | type_left, type_right) :: type_left | no_return()
        when type_left: type,
             type_right: type,
             type: map() | keyword() | tuple()

  # loose or rigid map
  def deep_merge( { :loose, %{} = left}, right) when map_size( left) == 0, do: to_map( right)
  def deep_merge( { :rigid, %{} = left}, %{} = right) when map_size( left) == 0, do: right
  def deep_merge( { mode, %{} = left}, right) when is_mode( mode) do
    right = mode == :loose && to_map( right) || right

    Map.merge( left, Map.take( right, Map.keys( left)), &deep_resolve/3)
    |> Map.reject( &dummy?( &1))
  end

  # list with dummy head and/or tail
  def deep_merge( { mode, [ head | tail]} = left, right) when is_mode( mode) and ( head == @dummy or tail == @dummy) do
    merge_head_tail( left, right)
  end

  # improper list with head merger structure
  def deep_merge( { mode, [ { head_mode, _} | tail]} = left, right)
      when is_mode( mode) and is_mode( head_mode) and tail != []
    do
    merge_head_tail( left, right)
  end

  # improper list with tail merger structure
  def deep_merge( { mode, [ _ | { tail_mode, _}]} = left, right) when is_mode( mode) and is_mode( tail_mode) do
    merge_head_tail( left, right)
  end

  # loose list
  def deep_merge( { :loose, []}, right), do: to_list( right)
  def deep_merge( { :loose, [ _ | _] = left}, right) do
    right = to_map( right)

    right_taken =
      Enum.reduce( left, [], fn { left_key, _} = left_kv, right_taken ->
        cond do
          Map.has_key?( right, left_key) ->
            [ { left_key, right[ left_key]} | right_taken]

          not dummy?( left_kv) ->
            [ left_kv | right_taken]

          true ->
            right_taken
        end
      end)
      |> Enum.reverse()

    Keyword.merge( left, right_taken, &deep_resolve/3)
    |> Keyword.reject( &dummy?( &1))
  end

  # rigid empty list replaced with another list
  def deep_merge( { :rigid, []}, right) when is_list( right), do: right

  # rigid list with another same-size list
  def deep_merge( { :rigid, [ _ | _] = left}, [ _ | _] = right) do
    if length( left) == length( right) do
      [ left, right]
      |> List.zip()
      |> Enum.map( fn { left, right} ->
        deep_resolve( left, right)
      end)
    else
      raise MatchError, term: right
    end
  end

  # rigid list with with any other structure
  def deep_merge( { :rigid, left}, right) when is_list( left) do
    raise MatchError, term: right
  end

  # loose tuple
  def deep_merge( { :loose, left}, right) when is_tuple( left) do
    deep_merge( { :loose, Tuple.to_list( left)}, right)
    |> List.to_tuple()
  end

  # rigid tuple replaced with another tuple
  def deep_merge( { :rigid, {}}, right) when is_tuple( right), do: right

  # rigid tuple with another same-sized tuple
  def deep_merge( { :rigid, left}, right)
      when is_tuple( left)
           and is_tuple( right)
           and tuple_size( left) == tuple_size( right)
    do
    [ Tuple.to_list( left), Tuple.to_list( right)]
    |> List.zip()
    |> Enum.map( fn { left, right} ->
      deep_resolve( left, right)
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

  # Merges any of the legit head | tail combinations
  @spec merge_head_tail( { mode(), head_tail()}, term()) :: list()

  # loose [ key-pair head | any tail]
  defp merge_head_tail( { :loose, [ { k, _} = head | @dummy]}, right) when is_atom( k) do
    [ head] = deep_merge( { :loose, [ head]}, right)
    tail = delete_pair( right, head)
    [ head | to_list( tail)]
  end

  # loose [ key-pair head | term or a merger structure tail]
  defp merge_head_tail( { :loose, [ { k, _} = head | tail]}, right) when is_atom( k) do
    [ head] = deep_merge( { :loose, [ head]}, right)
    tail = deep_merge( tail, delete_pair( right, head))
    [ head | tail]
  end

  # loose list with an invalid merger format.
  defp merge_head_tail( { :loose, _} = left, _right) do
    raise ArgumentError, "Invalid loose merger format: #{ inspect( left)}"
  end

  # rigid list with a term other than list on the right side
  defp merge_head_tail( { :rigid, _}, right) when not is_list( right) do
    raise MatchError, term: right
  end

  # rigid [ any head | any tail]
  defp merge_head_tail( { :rigid, [ @dummy | @dummy]}, right) do
    right
  end

  # rigid [ any head | tail term or merger structure]
  defp merge_head_tail( { :rigid, [ @dummy | tail]}, right) do
    tail = deep_merge( tail, tl( right))
    [ hd( right) | tail]
  end

  # rigid [ head term or merger structure | any tail]
  defp merge_head_tail( { :rigid, [ head | @dummy]}, right) do
    head = deep_merge( head, hd( right))
    [ head | tl( right)]
  end

  # rigid [ term or merger structure | term or merger structure]
  defp merge_head_tail( { :rigid, [ head | tail]}, right) do
    head = deep_merge( head, hd( right))
    tail = deep_merge( tail, tl( right))
    [ head | tail]
  end

  # Merge recursively both left and right side values are structures,
  # otherwise return the right side value.
  @spec deep_resolve( atom(), any(), any()) :: any()
  defp deep_resolve( key \\ nil, left, right)
  defp deep_resolve( _key, left, right)
       when ( is_map( left) or is_list( left) or is_tuple( left)) and
            ( is_map( right) or is_list( right) or is_tuple( right))
    do
    deep_merge( left, right)
  end
  defp deep_resolve( _key, _left, right), do: right

  # Verifies if a merger is a dummy.
  defp dummy?( { _, @dummy}), do: true
  defp dummy?( { _, _}), do: false

  # Transforms keyword list or tuple into map
  defp to_map( %{ __struct__: _} = map), do: Map.from_struct( map)
  defp to_map( %{} = map), do: map
  defp to_map( kw) when is_list( kw), do: Map.new( kw)
  defp to_map( tuple) when is_tuple( tuple), do: to_list( tuple) |> Map.new()

  # Transforms map or tuple into keyword list.
  defp to_list( kw) when is_list( kw), do: kw
  defp to_list( %{ __struct__: module} = struct) do
    [ __struct__: module] ++ to_list( Map.from_struct( struct))
  end
  defp to_list( %{} = map), do: Keyword.new( map)
  defp to_list( tuple) when is_tuple( tuple), do: Tuple.to_list( tuple)

  # Deletes key pair from a structure
  defp delete_pair( kw, pair) when is_list( kw), do: List.delete( kw, pair)
  defp delete_pair( %{} = map, pair), do: Map.delete( map, elem( pair, 0))
  defp delete_pair( tuple, pair) when is_tuple( tuple) do
    tuple
    |> Tuple.to_list()
    |> delete_pair( pair)
    |> List.to_tuple()
  end
end
