defmodule ExSelTest do
  use ExUnit.Case
  doctest ExSel

  test "arithmetic expression integration" do
    [
      "true",
      "  true  ",
      " false  ",
      "!  false ",
      "!true ",
      "!true ",
      "true && true",
      "true&&false",
      "false && true && false",
      "(false && true) && false",
      "((false && true) && false)",
      "true && false || true",
      "true && (false || true)",
      "true || 1 == 5 && 1 != 2 || 2 > 1 || true",
      "(true || false && (true || false)) || true",
      "1 + (1 + 4 / 5) * 8 <= 10 && 1 > 10 || 1 > 2 * 0.5"
    ]
    |> Enum.each(fn exp ->
      assert {:ok, ast} = ExSel.bexpr(exp)
      result = ExSel.eval!(ast)
      assert {^result, _} = Code.eval_string(exp)
    end)
  end

  test "boolean expression integration" do
    [
      "1 + 1",
      "1 + 1 ",
      "1 / 2 / 5 / 6 / 7 / 8 ",
      "10 * 100 / 50",
      "10 * 100 / (50 - 10)",
      "1*1/9-98 * -1 - -2",
      "(1 * (4-5)/8 *10) -5 * 8"
    ]
    |> Enum.each(fn exp ->
      assert {:ok, ast} = ExSel.aexpr(exp)
      result = ExSel.eval!(ast)
      assert {^result, _} = Code.eval_string(exp)
    end)
  end
end
