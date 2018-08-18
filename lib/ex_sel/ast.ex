defmodule ExSel.Ast do
  @moduledoc """
  Simple expression language AST
  """

  #
  # Value expressions
  #
  @type vexpr_bool :: boolean
  @type vexpr_num :: number
  @type vexpr_str :: binary
  @type vexpr_var :: {:var, binary()}
  @type vexpr :: vexpr_bool | vexpr_num | vexpr_str | vexpr_var

  #
  # Arithmetic expressions
  #
  @type aexpr_binop ::
          {:+, [aexpr]}
          | {:-, [aexpr]}
          | {:*, [aexpr]}
          | {:/, [aexpr]}

  @type aexpr :: vexpr_num | vexpr_var | aexpr_binop

  #
  # Logic/Comparison/Ordering expressions
  #
  @type cexpr_ord ::
          {:>, [aexpr]}
          | {:<, [aexpr]}
          | {:>=, [aexpr]}
          | {:<=, [aexpr]}

  @type cexpr_eq ::
          {:==, [vexpr | aexpr | bexpr]}
          | {:!=, [vexpr | aexpr | bexpr]}

  @type cexpr :: cexpr_ord | cexpr_eq

  @type bexpr ::
          {:!, [bexpr]}
          | {:&&, [bexpr]}
          | {:||, [bexpr]}
          | vexpr_bool
          | vexpr_var
          | cexpr

  @type t :: bexpr | aexpr | vexpr
  @type eval_ctx :: %{binary => term}
  @type eval_result :: boolean | binary | number

  #   defguard is_vexpr(ast)
  #            when is_number(ast) or is_binary(ast) or is_boolean(ast) or
  #                   (is_tuple(ast) and elem(ast, 0) == :var)

  @doc """
  Evaluates the passed ast and variables

  ## Examples

      iex> alias ExSel.Ast
      iex> Ast.eval!(true, %{})
      true
      iex> Ast.eval!({:+,[1,{:var, "a"}]}, %{"a" => 1})
      2
      iex> Ast.eval!({:==,[1,1]}, %{})
      true
      iex> Ast.eval!({:/,[1,0]}, %{})
      ** (ArithmeticError) bad argument in arithmetic expression

  """
  @spec eval!(ast :: t, ctx :: eval_ctx) :: eval_result | none()
  def eval!(ast, ctx \\ %{})
  def eval!(ast, _ctx) when is_number(ast), do: ast
  def eval!(ast, _ctx) when is_binary(ast), do: ast
  def eval!(ast, _ctx) when is_boolean(ast), do: ast
  def eval!({:var, k}, ctx), do: get_var!(ctx, k)
  def eval!({:+, [a, b]}, ctx), do: eval!(a, ctx, :num) + eval!(b, ctx, :num)
  def eval!({:-, [a, b]}, ctx), do: eval!(a, ctx, :num) - eval!(b, ctx, :num)
  def eval!({:*, [a, b]}, ctx), do: eval!(a, ctx, :num) * eval!(b, ctx, :num)
  def eval!({:/, [a, b]}, ctx), do: eval!(a, ctx, :num) / eval!(b, ctx, :num)
  def eval!({:!, [a]}, ctx), do: not eval!(a, ctx, :bool)
  def eval!({:&&, [a, b]}, ctx), do: eval!(a, ctx, :bool) && eval!(b, ctx, :bool)
  def eval!({:||, [a, b]}, ctx), do: eval!(a, ctx, :bool) || eval!(b, ctx, :bool)
  def eval!({:>, [a, b]}, ctx), do: eval!(a, ctx, :num) > eval!(b, ctx, :num)
  def eval!({:>=, [a, b]}, ctx), do: eval!(a, ctx, :num) >= eval!(b, ctx, :num)
  def eval!({:<, [a, b]}, ctx), do: eval!(a, ctx, :num) < eval!(b, ctx, :num)
  def eval!({:<=, [a, b]}, ctx), do: eval!(a, ctx, :num) <= eval!(b, ctx, :num)
  def eval!({:==, [a, b]}, ctx), do: eval!(a, ctx) == eval!(b, ctx)
  def eval!({:!=, [a, b]}, ctx), do: eval!(a, ctx) != eval!(b, ctx)

  @spec eval!(ast :: t, ctx :: eval_ctx, type :: :bool | :num) :: eval_result | none()
  defp eval!(ast, ctx, type), do: ast |> eval!(ctx) |> guard_type!(type)

  defp get_var!(ctx, k), do: ctx |> Map.get(k) |> guard_nil!(k)
  defp guard_nil!(nil, k), do: raise("variable #{k} undefined or null")
  defp guard_nil!(v, _), do: v

  defp guard_type!(v, :bool) when is_boolean(v), do: v
  defp guard_type!(v, :bool), do: raise("expression is not a boolean: `#{inspect(v)}`")
  defp guard_type!(v, :num) when is_number(v), do: v
  defp guard_type!(v, :num), do: raise("expression is not a number: `#{inspect(v)}`")
end
