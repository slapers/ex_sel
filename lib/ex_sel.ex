defmodule ExSel do
  @moduledoc """
  Simple runtime expression language for elixir.

  ## Variables

  A variable should start with a lowercase letter and is followed by mixed case letters, numbers or underscore
  `true` and `false` are reserved symbols

      # valid:
      a , myVar , my_Var, var1

      # invalid:
      Aaaa , true, false, _myVar, my-var, 9var


  ## Arithmetic expressions:
  The supported operators: `+` `-` `/` `*`

  Additionally grouping is supported to override normal precedence rules.

      # examples:
      (1 + 2) * 5 / 4 - 2
      var1 * 9 - varB

  ## Boolean expressions:
  The supported comparison operators: `>` `>=` `<` `<=` `==` `!=`

  The supported logic operators: `&&` `||` `!`

  The supported boolean consts: `true` `false`

  Additionally grouping is supported to override normal precedence rules.

      # examples:
      true
      varA > (1 + 2) || varB == true
      var1 * 9 - varB == varC

  """

  @doc """
  Parses the given arithmetic expression into an ExSel.Ast

  ## Example

      iex> ExSel.aexpr("8 + 2 / 4")
      {:ok, {:+, [8, {:/, [2, 4]}]}}
  """
  @spec aexpr(binary) :: {:ok, ExSel.Ast.t()} | {:error, term}
  def aexpr(expression) do
    expression
    |> prep_input
    |> ExSel.Parser.aexpr()
    |> unwrap_res
  end

  @doc """
  Parses the given boolean expression into an ExSel.Ast

  ## Example

      iex> ExSel.bexpr("8 + 2 > 4")
      {:ok, {:>, [{:+, [8, 2]}, 4]}}
  """
  @spec bexpr(binary) :: {:ok, ExSel.Ast.t()} | {:error, term}
  def bexpr(expression) do
    expression
    |> prep_input
    |> ExSel.Parser.bexpr()
    |> unwrap_res
  end

  defp prep_input(input), do: String.trim(input)

  defp unwrap_res(result) do
    case result do
      {:ok, [acc], "", _, _line, _offset} ->
        {:ok, acc}

      {:ok, _, rest, _, _line, _offset} ->
        {:error, "could not parse: " <> rest}

      {:error, reason, _rest, _context, _line, _offset} ->
        {:error, reason}
    end
  end

  @doc """
  Evaluates the expression ast.

  First build an ast using `aexpr/1` or `bexpr/1`.
  To specify variables that should be available during evaluation pass a map with their values.

  ## Example

      iex> {:ok, ast} = ExSel.aexpr("varA + varB / 4")
      iex> my_vars = %{"varA" => 8, "varB" => 2}
      iex> ExSel.eval!(ast, my_vars)
      8.5
  """
  @spec eval!(ExSel.Ast.t(), ExSel.Ast.eval_ctx()) :: ExSel.Ast.eval_result() | no_return
  def eval!(ast, variables \\ %{}), do: ExSel.Ast.eval!(ast, variables)
end
