defmodule Extructure.Keylist do
  @moduledoc """
  A subset of Elixir `Keyword` functions slightly modified to support both
  atom and string keys.
  """

  @type key() :: atom() | String.t()
  @type value() :: any()
  @type t() :: [ { key(), value()}]

  @spec merge( t(), t, ( key(), value(), value() -> value())) :: t()
  def merge( keylist1, keylist2, fun)
      when is_list( keylist1) and is_list( keylist2) and is_function( fun, 3)
    do
    if keylist?( keylist1) do
      do_merge( keylist2, [], keylist1, keylist1, fun, keylist2)
    else
      raise ArgumentError,
            "expected a keylist as the first argument, got: #{ inspect( keylist1)}"
    end
  end

  defp do_merge( [ { key, value2} | tail], acc, rest, original, fun, keylist2)
       when is_atom( key) or is_bitstring( key)
    do
    case :lists.keyfind( key, 1, original) do
      { ^key, value1} ->
        acc = [ { key, fun.( key, value1, value2)} | acc]
        original = :lists.keydelete( key, 1, original)
        do_merge( tail, acc, delete( rest, key), original, fun, keylist2)

      false ->
        do_merge( tail, [ { key, value2} | acc], rest, original, fun, keylist2)
    end
  end

  defp do_merge( [], acc, rest, _original, _fun, _keylist2) do
    rest ++ :lists.reverse( acc)
  end

  defp do_merge(_other, _acc, _rest, _original, _fun, keylist2) do
    raise ArgumentError,
          "expected a keylist list as the second argument, got: #{ inspect( keylist2)}"
  end

  @spec keylist?( term()) :: boolean()
  def keylist?( term)

  def keylist?( [ { key, _value} | rest]) when is_atom( key) or is_bitstring( key), do: keylist?( rest)
  def keylist?( []), do: true
  def keylist?( _other), do: false

  @spec delete( t(), key()) :: t()
  @compile { :inline, delete: 2}
  def delete( keylist, key) when is_list( keylist) and is_atom( key) or is_bitstring( key) do
    case :lists.keymember( key, 1, keylist) do
      true -> delete_key( keylist, key)
      _ -> keylist
    end
  end

  defp delete_key( [ { key, _} | tail], key), do: delete_key( tail, key)
  defp delete_key( [ {_, _} = pair | tail], key), do: [ pair | delete_key( tail, key)]
  defp delete_key( [], _key), do: []

  @spec reject( t(), ( { key(), value()} -> as_boolean( term()))) :: t()
  def reject( keywords, fun) when is_list( keywords) and is_function( fun, 1) do
    do_reject( keywords, fun)
  end

  defp do_reject( [], _fun), do: []

  defp do_reject( [ {_, _} = entry | entries], fun) do
    if fun.( entry) do
      do_reject( entries, fun)
    else
      [ entry | do_reject( entries, fun)]
    end
  end
end
