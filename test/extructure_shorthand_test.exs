defmodule Extructure.ShorthandTest.Adder do
  use Extructure.Shorthand

  def add(-%{ a, b}), do: a + b
end

defmodule Extructure.ShorthandTest do
  use ExUnit.Case
  use Extructure.Shorthand
  alias Extructure.ShorthandTest.Adder

  test "+%{ ...} — bare vars become implicit-key pairs in a map" do
    a = 1
    b = 2
    assert +%{ a, b} == %{ a: 1, b: 2}
  end

  test "+%{ ...} — bare and explicit kv pairs may be mixed" do
    a = 1
    assert +%{ a, b: 3} == %{ a: 1, b: 3}
    assert +%{ a: 5, b: 6} == %{ a: 5, b: 6}
  end

  test "+%{} — empty map passes through" do
    assert +%{} == %{}
  end

  test "+[ ...] — bare vars become implicit-key pairs in a kw list" do
    a = 1
    b = 2
    assert +[ a, b] == [ a: 1, b: 2]
    assert +[ a, b: 3] == [ a: 1, b: 3]
  end

  test "+[] — empty list passes through" do
    assert +[] == []
  end

  test "+{ ...} — bare vars become implicit-key pairs in a tuple of pairs" do
    a = 1
    b = 2
    c = 3
    assert +{ a, b} == {{ :a, 1}, { :b, 2}}
    assert +{ a, b, c} == {{ :a, 1}, { :b, 2}, { :c, 3}}
    assert +{ a} == {{ :a, 1}}
  end

  test "+{ ...} — kw shorthand inside a tuple unfolds into N+1 pairs" do
    a = 1
    assert +{ a, b: 4} == {{ :a, 1}, { :b, 4}}
    assert +{ a, b: 4, c: 5} == {{ :a, 1}, { :b, 4}, { :c, 5}}
  end

  test "+{} — empty tuple passes through" do
    assert +{} == {}
  end

  test "+/1 falls through to Kernel.+/1 for non-structure args" do
    assert +5 == 5
    x = 7
    assert +x == 7
  end

  test "-%{ ...} matches a map with shorthand keys" do
    -%{ a, b} = %{ a: 1, b: 2}
    assert a == 1
    assert b == 2
  end

  test "-%{ ...} with mixed bare and explicit pairs" do
    -%{ a, b: 3} = %{ a: 1, b: 3}
    assert a == 1
  end

  test "-[ ...] matches a kw list with shorthand keys" do
    -[ a, b] = [ a: 1, b: 2]
    assert a == 1
    assert b == 2
  end

  test "-{ ...} matches a tuple of pairs with shorthand keys" do
    -{ a, b} = {{ :a, 1}, { :b, 2}}
    assert a == 1
    assert b == 2
  end

  test "-{ ...} with kw shorthand inside a tuple unfolds and matches" do
    -{ a, b: 4} = {{ :a, 1}, { :b, 4}}
    assert a == 1
  end

  test "-/1 raises MatchError on missing key (no loose conversion)" do
    rhs = Map.new( a: 1)

    assert_raise MatchError, fn ->
      -%{ a, b} = rhs
      _ = { a, b}
    end
  end

  test "-/1 in a function head" do
    assert Adder.add( %{ a: 1, b: 2}) == 3
  end

  test "-/1 falls through to Kernel.-/1 for non-structure args" do
    assert -5 == -5
    x = 7
    assert -x == -7
  end

  test "-[ head | tail] binds first kv to a shorthand head and the rest to tail" do
    -[ x | opts] = [ x: 1, y: 2]
    assert x == 1
    assert opts == [ y: 2]
  end

  test "-[ head | tail] tail can be empty" do
    -[ x | opts] = [ x: 1]
    assert x == 1
    assert opts == []
  end

  test "-[ a, b | tail] multi-head" do
    -[ a, b | rest] = [ a: 1, b: 2, c: 3, d: 4]
    assert a == 1
    assert b == 2
    assert rest == [ c: 3, d: 4]
  end

  test "-[ head | tail] with explicit pair as head" do
    -[{ :x, 1} | opts] = [ x: 1, y: 2]
    assert opts == [ y: 2]
  end

  test "+[ head | tail] prepends a shorthand pair to a tail list" do
    x = 1
    opts = [ y: 2, z: 3]
    assert +[ x | opts] == [ x: 1, y: 2, z: 3]
  end

  test "+[ a, b | tail] multi-head construction" do
    a = 1
    b = 2
    rest = [ c: 3]
    assert +[ a, b | rest] == [ a: 1, b: 2, c: 3]
  end
end

defmodule Extructure.UnifiedUseTest do
  use ExUnit.Case
  use Extructure

  test "use Extructure brings <~, +/1, and -/1 into scope at once" do
    %{ a, b} <~ %{ a: 1, b: 2}
    assert a == 1
    assert b == 2

    c = 3
    d = 4
    assert +%{ c, d} == %{ c: 3, d: 4}

    -[ x, y] = [ x: 5, y: 6]
    assert x == 5
    assert y == 6
  end
end
