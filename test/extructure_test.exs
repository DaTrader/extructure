defmodule ExtructureTest do
  use ExUnit.Case
  doctest Extructure

  import Extructure

  test "default map" do
    %{ a, b: %{  c}} <~ %{ a: 1, b: %{ c: 3}}
    assert a == 1
    assert c == 3
  end

  test "default list" do
    [ a, b: [ c]] <~ [ a: 1, b: [ c: 3]]
    assert a == 1
    assert c == 3
  end

  test "default (loose) tuple" do
    { a, c} <~ { { :a, 1}, { :c, 3}}
    assert a == 1
    assert c == 3
  end

  test "default mixed structures" do
    %{ a: { b, c}, d: [ e, f]} <~ %{ a: { { :b, 1}, { :c, 2}}, d: [ e: 3, f: 4]}
    assert b == 1
    assert c == 2
    assert e == 3
    assert f == 4
  end

  test "failed variable pattern match" do
    assert_raise MatchError, fn ->
      %{ a, b: %{ d}} <~ %{ a: 1, b: %{ c: 3}}
      assert a == 1
      assert d == nil
    end
  end

  test "optional variable in a map" do
    %{ _a, b: %{ c}} <~ %{ b: %{ c: 3}}
    assert a == nil
    assert c == 3
  end

  test "optional variable with a key" do
    %{ a: _a} <~ %{ c: 3}
    assert a == nil
  end

  test "optional variable in a list" do
    [ _e, f, g] <~ [ e: 1, f: 2, g: 3]
    assert e == 1
    assert f == 2
    assert g == 3
  end

  test "named key" do
    %{ a, b: %{ c: x}} <~ %{ a: 1, b: %{ c: 3}}
    assert a == 1
    assert x == 3
  end

  test "sole variable" do
    x <~ %{ a: 1}
    assert x == %{ a: 1}
  end

  test "sole variable match" do
    %{ a: a} = x <~ %{ a: 1}
    assert a == 1
    assert x == %{ a: 1}
  end

  test "sole variable assignment" do
    x = %{ a} <~ %{ a: 1}
    assert a == 1
    assert x == %{ a: 1}
  end

  test "sole variable destructure" do
    ( %{ a} = x) <~ %{ a: 1}
    assert a == 1
    assert x == %{ a: 1}
  end

  test "variable assignment within the match on the left" do
    x = %{ a: a = %{ b: b}} <~ %{ a: %{ b: 1}}
    assert b == 1
    assert a == %{ b: 1}
    assert x == %{ a: %{ b: 1}}
  end

  test "default values" do
    %{ a( 5), _b, _c( 7), d(), _e(), f: [ _x( 3), y]} <~ %{ c: 10, f: [ y: 7]}
    assert a == 5
    assert b == nil
    assert c == 10
    assert d == nil
    assert e == nil
    assert x == 3
    assert y == 7
  end

  test "map as a prevailing right side value" do
    %{ a( %{ a: 1})} <~ %{ a: %{ c: 1}}
    assert a == %{ c: 1}
  end

  test "map as a prevailing default value" do
    %{ a( %{ a: 1})} <~ %{}
    assert a == %{ a: 1}
  end

  test "list as a prevailing right side value" do
    %{ a( [ a: 1])} <~ %{ a: %{ c: 1}}
    assert a == %{ c: 1}
  end

  test "list as a prevailing default value" do
    %{ a( [ a: 1])} <~ %{}
    assert a == [ a: 1]
  end

  test "tuple as a prevailing right side value" do
    %{ a( { 1, 2, 3})} <~ %{ a: %{ c: 1}}
    assert a == %{ c: 1}
  end

  test "tuple as a prevailing default value" do
    %{ a( { 1, 2, 3})} <~ %{}
    assert a == { 1, 2, 3}
  end

  test "loose list size and order of elements 1" do
    [ c, _a, b] <~ [ b: 2, c: 3]
    assert a == nil
    assert b == 2
    assert c == 3
  end

  test "loose list size and order of elements 2" do
    [ d, b] <~ [ a: 1, b: 2, c: 3, d: 4, e: 5]
    assert d == 4
    assert b == 2
  end

  test "different tuple size and order of elements" do
    { c, a( 5), b} <~ { { :b, 2}, { :c, 3}}
    assert a == 5
    assert b == 2
    assert c == 3
  end

  test "implicit structural transformation" do
    %{ a, b: b = [ c, d, e: x = { f, g} = e]} <~ [ a: 1, b: %{ c: 3, d: 4, e: %{ f: 6, g: 7}, h: 10}]
    assert a == 1
    assert b == [ c: 3, d: 4, e: { { :f, 6}, { :g, 7}}]
    assert c == 3
    assert d == 4
    assert f == 6
    assert e == { { :f, 6}, { :g, 7}}
    assert g == 7
    assert x == { { :f, 6}, { :g, 7}}
  end

  test "matching other than assignment" do
    %{ a: %{ b: x} = %{ b}} <~ %{ a: [ b: 2]}
    assert b == 2
    assert x == 2
  end

  test "structure matching from loose to rigid and back" do
    %{ a, b: b = ^{ c, d, ^%{ e}}} <~ [ a: 1, b: { 3, 4, [ e: 5]}]
    assert a == 1
    assert b == { 3, 4, %{ e: 5}}
    assert c == 3
    assert d == 4
    assert e == 5
  end

  test "nested rigid two element tuple assigned to var" do
    [ a: a = ^{ b, c}] <~ %{ a: { 2, 3}}
    assert a == { 2, 3}
    assert b == 2
    assert c == 3
  end

  test "nested rigid two element tuple" do
    [ a: ^{ b, c}] <~ %{ a: { 2, 3}}
    assert b == 2
    assert c == 3
  end

  test "nested rigid other than two elements tuple" do
    [ a: ^{ b, c, d}] <~ %{ a: { 2, 3, 4}}
    assert b == 2
    assert c == 3
    assert d == 4
  end

  test "rigid list" do
    ^[ a, b] <~ [ a: 1, b: 2]
    assert a == 1
    assert b == 2
  end

  test "fail rigid different size list" do
    assert_raise MatchError, fn ->
      ^[ a, b] <~ [ a: 1, b: 2, c: 3]
      assert a == 1
      assert b == 2
    end
  end

  test "fail rigid different element order list" do
    assert_raise MatchError, fn ->
      ^[ b, a] <~ [ a: 1, b: 2]
      assert b == 2
      assert a == 1
    end
  end

  test "fail rigid map from list" do
    assert_raise BadMapError, fn ->
      ^%{ a, b} <~ [ a: 1, b: 2]
      assert a == 1
      assert b == 2
    end
  end

  test "fail rigid map from tuple of pairs" do
    assert_raise BadMapError, fn ->
      ^%{ a, b} <~ { { :a, 1}, { :b, 2}}
      assert a == 1
      assert b == 2
    end
  end

  test "fail rigid list from map" do
    assert_raise FunctionClauseError, fn ->
      ^[ a, b] <~ %{ a: 1, b: 2}
      assert a == 1
      assert b == 2
    end
  end

  test "fail rigid list from tuple" do
    assert_raise FunctionClauseError, fn ->
      ^[ a, b] <~ { { :a, 1}, { :b, 2}}
      assert a == 1
      assert b == 2
    end
  end

  test "rigid two element tuple from tuple" do
    ^{ a, b} <~ { 1, 2}
    assert a == 1
    assert b == 2
  end

  test "rigid other than two element tuple from tuple" do
    ^{ a, b, _c} <~ { 1, 2, 3}
    assert a == 1
    assert b == 2
    assert c == 3
  end

  test "rigid tuple from tuple of pairs" do
    ^{ a, b} <~ { { :a, 1}, { :b, 2}}
    assert a == { :a, 1}
    assert b == { :b, 2}
  end

  test "fail rigid tuple from map" do
    assert_raise MatchError, fn ->
      ^{ a, b} <~ %{ a: 1, b: 1}
      assert a == 1
      assert b == 2
    end
  end

  test "fail rigid tuple from list" do
    assert_raise MatchError, fn ->
      ^{ a, b} <~ [ a: 1, b: 1]
      assert a == 1
      assert b == 2
    end
  end

  test "fail loose tuple from standard tuple" do
    assert_raise ArgumentError, fn ->
      { a, b} <~ { 1, 2}
      assert a == 1
      assert b == 2
    end
  end

  test "keyword list head and tail in loose mode" do
    [ a | rest] <~ [ a: 1, b: 2, c: 3]
    assert a == 1
    assert rest == [ b: 2, c: 3]
  end

  test "keyword list head and tail arbitrary var loose mode" do
    [ b | rest] <~ [ a: 1, b: 2, c: 3]
    assert b == 2
    assert rest == [ a: 1, c: 3]
  end

  test "keyword list head and tail from map" do
    [ b | rest] <~ %{ a: 1, b: 2, c: 3}
    assert b == 2
    assert rest[ :a] == 1
    assert rest[ :c] == 3
  end

  test "keyword list head and tail from key-pair tuple" do
    [ b | [ a, c]] <~ { { :a, 1}, { :b, 2}, { :c, 3}}
    assert b == 2
    assert a == 1
    assert c == 3
  end

  test "keyword list head and structured tail" do
    [ b | [ a, c]] <~ { { :a, 1}, { :b, 2}, { :c, 3}}
    assert b == 2
    assert a == 1
    assert c == 3
  end

  test "keyword list head and structured tail with inside head and tail" do
    [ b | [ a | c]] <~ { { :a, 1}, { :b, 2}, { :c, 3}}
    assert b == 2
    assert a == 1
    assert c == [ c: 3]
  end

  test "list head and tail rigid mode" do
  end
end
