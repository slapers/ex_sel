defmodule ExSel.AstTest do
  @moduledoc false
  use ExUnit.Case
  use ExUnitProperties
  doctest ExSel.Ast

  alias ExSel.Ast

  def generate_vals, do: one_of([binary(), boolean(), integer(), float()])
  def generate_nums, do: one_of([integer(), float()])
  def generate_varnames, do: string(:alphanumeric, min_length: 1)

  describe "value expressions" do
    property "return literals" do
      check all val <- generate_vals() do
        assert val === Ast.eval!(val)
      end
    end

    property "supports variable substitution" do
      check all val <- generate_vals(),
                name <- generate_varnames(),
                ctx = %{name => val} do
        assert val === Ast.eval!({:var, name}, ctx)
      end
    end

    test "return appropriate errors for non-existing variable substitution" do
      assert_raise RuntimeError, "variable a undefined or null", fn ->
        Ast.eval!({:var, "a"}, %{})
      end
    end

    test "return appropriate errors for null variable substitution" do
      assert_raise RuntimeError, "variable a undefined or null", fn ->
        Ast.eval!({:var, "a"}, %{"a" => nil})
      end
    end
  end

  describe "arithmetic expressions" do
    test "return appropriate errors for non-numbers" do
      for op <- ~w(+ - / *)a do
        assert_raise RuntimeError, ~r/expression is not a number/, fn ->
          Ast.eval!({op, [true, 1]})
        end
      end
    end

    test "perform variable substitution" do
      check all a <- generate_nums(),
                b <- generate_nums(),
                ctx = %{"a" => a, "b" => b},
                sum = a + b do
        assert sum === Ast.eval!({:+, [{:var, "a"}, {:var, "b"}]}, ctx)
      end
    end

    test "return appropriate errors for non-numeric variable substitution" do
      ctx = %{"a" => 1, "b" => false}
      expr = {:+, [{:var, "a"}, {:var, "b"}]}
      assert_raise RuntimeError, ~r/expression is not a number/, fn -> Ast.eval!(expr, ctx) end
    end

    test "return appropriate errors for non-existing variable substitution" do
      ctx = %{}
      expr = {:+, [1, {:var, "b"}]}
      assert_raise RuntimeError, ~r/variable b undefined or null/, fn -> Ast.eval!(expr, ctx) end
    end

    test "return appropriate errors for null variable substitution" do
      ctx = %{"b" => nil}
      expr = {:+, [1, {:var, "b"}]}
      assert_raise RuntimeError, ~r/variable b undefined or null/, fn -> Ast.eval!(expr, ctx) end
    end

    test "recurses eval on operands" do
      op_a = {:*, [2, 3]}
      op_b = {:+, [2, 3]}
      assert 2 * 3 / (2 + 3) === Ast.eval!({:/, [op_a, op_b]})
    end

    property "correctly evaluates addition" do
      check all a <- generate_nums(),
                b <- generate_nums(),
                expr = {:+, [a, b]},
                sum = a + b do
        assert sum === Ast.eval!(expr)
      end
    end

    property "correctly evaluates subtractions" do
      check all a <- generate_nums(),
                b <- generate_nums(),
                expr = {:-, [a, b]},
                sub = a - b do
        assert sub === Ast.eval!(expr)
      end
    end

    property "multiplication expression evaluation correctly multiplies numbers" do
      check all a <- generate_nums(),
                b <- generate_nums(),
                expr = {:*, [a, b]},
                mul = a * b do
        assert mul === Ast.eval!(expr)
      end
    end

    property "division expression evaluation correctly divides numbers" do
      check all a <- generate_nums(),
                b <- generate_nums(),
                b != 0,
                expr = {:/, [a, b]},
                divs = a / b do
        assert divs === Ast.eval!(expr)
      end
    end
  end

  describe "boolean logic expressions" do
    test "not evaluates as negation over a boolean expression" do
      for a <- [true, false] do
        assert not a == Ast.eval!({:!, [a]})
      end
    end

    test "or evaluates as a disjunction over boolean expressions" do
      for a <- [true, false],
          b <- [true, false] do
        assert (a || b) == Ast.eval!({:||, [a, b]})
      end
    end

    test "and evaluates as a conjunction over boolean expressions" do
      for a <- [true, false],
          b <- [true, false] do
        assert (a && b) == Ast.eval!({:&&, [a, b]})
      end
    end

    test "return appropriate errors for non-boolean operands" do
      ctx = %{"a" => 1, "b" => true}
      expr = {:&&, [{:var, "a"}, {:var, "b"}]}
      assert_raise RuntimeError, ~r/expression is not a boolean/, fn -> Ast.eval!(expr, ctx) end
    end
  end

  describe "relational expressions" do
    test "evaluate ordering of numbers" do
      check all a <- generate_nums(),
                b <- generate_nums() do
        assert a < b == Ast.eval!({:<, [a, b]})
        assert a <= b == Ast.eval!({:<=, [a, b]})
        assert a > b == Ast.eval!({:>, [a, b]})
        assert a >= b == Ast.eval!({:>=, [a, b]})
      end
    end

    test "return appropriate errors when ordering non-numeric operands" do
      ctx = %{"a" => 1, "b" => true}
      expr = {:>, [{:var, "a"}, {:var, "b"}]}
      assert_raise RuntimeError, ~r/expression is not a number/, fn -> Ast.eval!(expr, ctx) end
    end

    test "evaluates equality on numbers" do
      assert true == Ast.eval!({:==, [1, 1.0]})
      refute true == Ast.eval!({:!=, [1, 1.0]})
    end
  end
end
