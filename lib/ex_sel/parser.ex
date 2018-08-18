defmodule ExSel.Parser do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.PipeChainStart
  import NimbleParsec

  # Value expressions

  # <vexpr_bool> ::= "true" | "false"
  # <vexpr_num>  ::= <int> | <float>
  # <int>        ::= ["-"]<digit>{<digit>}
  # <float>      ::= ["-"]<digit>{<digit>}"."<digit>{<digit>}
  # <vexpr_str>  ::= """ any-utf8-except-escaped-doublequote """
  # <vexpr_var>  ::= <lc_letter> {<lc_letter> | <uc_letter> | <digit> | "_"}
  # <digit>      ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
  # <lc_letter>  ::= "a".."z"
  # <uc_letter>  ::= "A".."Z"

  @reserved_sym ["true", "false"]

  true_ = "true" |> string() |> replace(true)
  false_ = "false" |> string() |> replace(false)
  vexpr_bool = [true_, false_] |> choice() |> label("boolean")
  digits = [?0..?9] |> ascii_string(min: 1) |> label("digits")

  int =
    optional(string("-"))
    |> concat(digits)
    |> reduce(:to_integer)
    |> label("integer")

  defp to_integer(acc), do: acc |> Enum.join() |> String.to_integer(10)

  float =
    optional(string("-"))
    |> concat(digits)
    |> ascii_string([?.], 1)
    |> concat(digits)
    |> reduce(:to_float)
    |> label("float")

  defp to_float(acc), do: acc |> Enum.join() |> String.to_float()

  vexpr_num = [float, int] |> choice() |> label("number")

  vexpr_str =
    ignore(ascii_char([?"]))
    |> repeat_until(
      utf8_char([]),
      [ascii_char([?"])]
    )
    |> ignore(ascii_char([?"]))
    |> reduce({List, :to_string, []})
    |> label("string")

  vexpr_var =
    ascii_char([?a..?z])
    |> repeat(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
    |> traverse(:to_varname)
    |> unwrap_and_tag(:var)
    |> label("variable")

  defp to_varname(_rest, acc, context, _line, _offset) do
    name = acc |> Enum.reverse() |> List.to_string()

    if name in @reserved_sym do
      {:error, name <> " is a reserved symbol"}
    else
      {[name], context}
    end
  end

  defparsec(
    :vexpr,
    [vexpr_bool, vexpr_num, vexpr_str, vexpr_var]
    |> choice()
  )

  # Arithmetic expressions
  #
  # In order to follow operator precedence in math we should have the
  # parser work according to the following EBNF:
  #
  # <aexpr>  ::= <term> {+ | - <term>}
  # <term>   ::= <factor> {* | / <factor>}
  # <factor> ::= ( <aexpr> ) | <const>
  # <const>  ::= <vexpr_num> | <vexpr_var>

  plus = ascii_char([?+]) |> replace(:+) |> label("+")
  minus = ascii_char([?-]) |> replace(:-) |> label("-")
  times = ascii_char([?*]) |> replace(:*) |> label("*")
  divide = ascii_char([?/]) |> replace(:/) |> label("/")
  lparen = ascii_char([?(]) |> label("(")
  rparen = ascii_char([?)]) |> label(")")
  whitespace = ascii_char([?\s, ?\t]) |> times(min: 1)

  ignore_surrounding_whitespace = fn p ->
    ignore(optional(whitespace))
    |> concat(p)
    |> ignore(optional(whitespace))
  end

  defcombinatorp(
    :aexpr_factor,
    [
      ignore(lparen) |> parsec(:aexpr) |> ignore(rparen),
      vexpr_num,
      vexpr_var
    ]
    |> choice()
    |> ignore_surrounding_whitespace.()
  )

  defparsecp(
    :aexpr_term,
    parsec(:aexpr_factor)
    |> repeat([times, divide] |> choice() |> parsec(:aexpr_factor))
    |> reduce(:fold_infixl)
  )

  defparsec(
    :aexpr,
    parsec(:aexpr_term)
    |> repeat([plus, minus] |> choice() |> parsec(:aexpr_term))
    |> reduce(:fold_infixl)
  )

  defp fold_infixl(acc) do
    acc
    |> Enum.reverse()
    |> Enum.chunk_every(2)
    |> List.foldr([], fn
      [l], [] -> l
      [r, op], l -> {op, [l, r]}
    end)
  end

  #
  # Comparison expressions
  #
  # <cexpr>     ::= <factor> <eq_op> <factor> | <term>
  # <term>      ::= (<cexpr>) | <cexpr_ord>
  # <factor>    ::= (<bexpr>) | <term> | <aexpr> | <vexpr>
  # <cexpr_ord> ::= <aexpr> <ord_op> <aexpr>
  # <ord_op>    ::= > | >= | < | <=
  # <eq_op>     ::= != | ==

  gt = string(">") |> replace(:>)
  gte = string(">=") |> replace(:>=)
  lt = string("<") |> replace(:<)
  lte = string("<=") |> replace(:<=)
  eq = string("==") |> replace(:==)
  neq = string("!=") |> replace(:!=)

  # <aexpr> <ord_op> <aexpr>
  defcombinatorp(
    :cexpr_ord,
    parsec(:aexpr)
    |> choice([gte, lte, gt, lt])
    |> parsec(:aexpr)
    |> reduce(:fold_infixl)
  )

  # (<bexpr>) | <term> | <aexpr> | <vexpr>
  defcombinatorp(
    :cexpr_factor,
    [
      ignore(lparen) |> parsec(:bexpr) |> ignore(rparen),
      parsec(:cexpr_term),
      parsec(:aexpr),
      parsec(:vexpr)
    ]
    |> choice()
    |> ignore_surrounding_whitespace.()
  )

  # (<cexpr>) | <cexpr_ord>
  defcombinatorp(
    :cexpr_term,
    [
      ignore(lparen) |> parsec(:cexpr) |> ignore(rparen),
      parsec(:cexpr_ord)
    ]
    |> choice()
    |> ignore_surrounding_whitespace.()
  )

  # <factor> <eq_op> <factor> | <term>
  defparsec(
    :cexpr,
    choice([
      parsec(:cexpr_factor) |> choice([eq, neq]) |> parsec(:cexpr_factor) |> reduce(:fold_infixl),
      parsec(:cexpr_term)
    ])
  )

  # Boolean logic expressions
  #
  # Priority order (high to low):  NOT, AND, OR
  # expressions in parens are evaluated first
  #
  # <bexpr>  ::= <term> {<or> <term>}
  # <term>   ::= <factor> {<and> <factor>}
  # <factor> ::= <not> <factor> | ( <bexpr> ) | <cexpr> | <vexpr_bool>
  # <or>     ::= '||'
  # <and>    ::= '&&'
  # <not>    ::= '!'

  not_ = "!" |> string()
  and_ = "&&" |> string() |> replace(:&&)
  or_ = "||" |> string |> replace(:||)

  defparsecp(
    :bexpr_factor,
    choice([
      ignore(not_) |> parsec(:bexpr_factor) |> tag(:!),
      ignore(lparen) |> parsec(:bexpr) |> ignore(rparen),
      parsec(:cexpr),
      vexpr_bool
    ])
    |> ignore_surrounding_whitespace.()
    |> label("logic factor")
  )

  defparsecp(
    :bexpr_term,
    parsec(:bexpr_factor)
    |> repeat(and_ |> parsec(:bexpr_factor))
    |> reduce(:fold_infixl)
    |> label("logic term")
  )

  defparsec(
    :bexpr,
    parsec(:bexpr_term)
    |> repeat(or_ |> parsec(:bexpr_term))
    |> reduce(:fold_infixl)
    |> label("boolean logic expression")
  )
end
