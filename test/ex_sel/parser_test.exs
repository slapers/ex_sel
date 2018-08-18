defmodule ExSel.ParserTest do
  @moduledoc false
  use ExUnit.Case

  alias ExSel.Parser

  defp vexpr(expr), do: expr |> Parser.vexpr() |> unwrap
  defp aexpr(expr), do: expr |> Parser.aexpr() |> unwrap
  defp cexpr(expr), do: expr |> Parser.cexpr() |> unwrap
  defp bexpr(expr), do: expr |> Parser.bexpr() |> unwrap

  defp unwrap({:ok, [acc], "", _, _, _}), do: acc
  defp unwrap({:ok, _, rest, _, _, _}), do: {:error, "could not parse", rest}
  defp unwrap({:error, reason, rest, _, _, _}), do: {:error, reason, rest}

  describe "value expressions" do
    # Seems like the last error comes out from a choice operator..
    @err "expected variable while processing boolean or number or string or variable"

    test "return ok/error for boolean literals" do
      assert true == vexpr("true")
      assert false == vexpr("false")
      assert {:error, @err, "False"} == vexpr("False")
    end

    test "return ok/error for integer literals" do
      assert -1 === vexpr("-1")
      assert 999 === vexpr("999")
    end

    test "return ok/error for float literals" do
      assert 0.0001 === vexpr("0.0001")
      assert -9.0 === vexpr("-9.0")
      assert {:error, @err, ".0001"} = vexpr(".0001")
    end

    test "return ok/error for variable names" do
      assert {:var, "a"} == vexpr("a")
      assert {:var, "aAAA9_"} == vexpr("aAAA9_")
      assert {:error, "could not parse", "-9"} == vexpr("a-9")
      assert {:error, @err, "A"} == vexpr("A")
      assert {:error, @err, "_A"} == vexpr("_A")
    end
  end

  describe "arithmetic expressions" do
    @err "expected variable while processing " <>
           "(, followed by aexpr, followed by ) or number or variable"

    @err_sym "false is a reserved symbol"

    test "return ok/error for consts" do
      assert -1 == aexpr("-1")
      assert {:var, "test"} == aexpr("test")
    end

    test "return ok/error for addition/subtraction terms" do
      assert {:+, [1, 2]} == aexpr("1 +2")
      assert {:-, [1, -2]} == aexpr("1--2")
      assert {:+, [1, {:+, [2, 3]}]} == aexpr("1+ (2+ 3)")
      assert {:error, @err, "!1+(2+3)"} == aexpr("!1+(2+3)")
      assert {:error, @err_sym, " + true"} == aexpr("false + true")
    end

    test "return ok/error for multiplication/division factors" do
      assert {:*, [1, 2]} == aexpr("1*2")
      assert {:/, [1, -2]} == aexpr("1/-2")
      assert {:*, [1, {:/, [2, 3]}]} == aexpr("1 * (2/ 3)")
      assert {:error, @err, "!1*(2/3)"} == aexpr("!1*(2/3)")
    end

    test "obey math precedence rules" do
      for [input, ast] <- [
            [
              "1+1",
              {:+, [1, 1]}
            ],
            [
              "1 *2*3",
              {:*, [{:*, [1, 2]}, 3]}
            ],
            [
              "1+ 2 *3",
              {:+, [1, {:*, [2, 3]}]}
            ],
            [
              "( 1   +2 )  *3",
              {:*, [{:+, [1, 2]}, 3]}
            ],
            [
              "(-1 +2 - -1 *3)/4",
              {:/, [{:-, [{:+, [-1, 2]}, {:*, [-1, 3]}]}, 4]}
            ],
            [
              "(1)/ 2+ 2*(3)",
              {:+, [{:/, [1, 2]}, {:*, [2, 3]}]}
            ],
            [
              "( 1/2+ 2*3/ (myvar))",
              {:+, [{:/, [1, 2]}, {:/, [{:*, [2, 3]}, {:var, "myvar"}]}]}
            ]
          ] do
        assert ast == aexpr(input)
      end
    end
  end

  describe "comparison expressions" do
    test "return ok/error for ordering comparisons" do
      assert {:>, [-1, 0]} == cexpr("-1 > 0")
      assert {:>=, [-1, 0]} == cexpr("-1  >= 0")
      assert {:<, [-1, 0]} == cexpr("-1 < 0")
      assert {:<=, [-1, 0]} == cexpr("-1 <= 0")
      assert {:<, [{:+, [{:*, [-1, 2]}, 1]}, 0]} == cexpr("-1 * 2 + 1 < 0")
    end
  end

  describe "boolean logic expressions" do
    test "parses negations" do
      assert {:!, [true]} == bexpr("!true")
      assert {:!, [true]} == bexpr("! true")
    end

    test "parses conjunctions" do
      expected = {:&&, [true, false]}
      assert expected == bexpr("true && false")
      assert expected == bexpr("true&&false")
      assert expected == bexpr("( (true ) && (false ) )")
    end

    test "parses disjunctions" do
      expected = {:||, [true, false]}
      assert expected == bexpr("true || false")
      assert expected == bexpr("true||false")
    end

    test "parses logical operations on comparison expressions" do
      for [input, ast] <- [
            [
              "1 + 2 > 5 * 3",
              {:>, [{:+, [1, 2]}, {:*, [5, 3]}]}
            ],
            [
              "! 1 + 2 > 1 + 5 * 3",
              {:!, [{:>, [{:+, [1, 2]}, {:+, [1, {:*, [5, 3]}]}]}]}
            ],
            [
              "!(1 <= 2 || 5 >= 3 && true)",
              {:!, [{:||, [{:<=, [1, 2]}, {:&&, [{:>=, [5, 3]}, true]}]}]}
            ],
            [
              "! a != 2 && b >= 3 && c + 1 < 0",
              {:&&,
               [
                 {:&&,
                  [
                    {:!, [{:!=, [{:var, "a"}, 2]}]},
                    {:>=, [{:var, "b"}, 3]}
                  ]},
                 {:<, [{:+, [{:var, "c"}, 1]}, 0]}
               ]}
            ],
            [
              "true == false || true",
              {:||, [{:==, [true, false]}, true]}
            ],
            [
              "a == false || b > c",
              {:||, [{:==, [{:var, "a"}, false]}, {:>, [{:var, "b"}, {:var, "c"}]}]}
            ],
            [
              ~S("a" == "false" && true),
              {:&&, [{:==, ["a", "false"]}, true]}
            ]
          ] do
        assert ast == bexpr(input)
      end
    end
  end
end
