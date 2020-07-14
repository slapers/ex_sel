# ExSel

Simple expression language for elixir.

## Installation

The package can be installed by adding `ex_sel` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_sel, "~> 0.1.0"}
  ]
end
```

## Basic Usage

``` elixir
iex> ExSel.aexpr("8 + 2 / 4")
{:ok, {:+, [8, {:/, [2, 4]}]}}

iex> ExSel.bexpr("8 + 2 > 4")
{:ok, {:>, [{:+, [8, 2]}, 4]}}

iex> {:ok, ast} = ExSel.aexpr("varA + varB / 4")
iex> my_vars = %{"varA" => 8, "varB" => 2}
iex> ExSel.eval!(ast, my_vars)
8.5
```

Documentation can be found at [https://hexdocs.pm/ex_sel](https://hexdocs.pm/ex_sel).

## License

Copyright 2018 Stefan Lapers

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
