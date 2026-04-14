defmodule PrawnEx.Layout.Markup do
  @moduledoc """
  Minimal line-oriented markup → `PrawnEx.Layout` flow blocks (Phase D).

  Syntax (intentionally small):

  - `# title` — level-1 heading (single line).
  - `## title` — level-2 heading (smaller font).
  - `- item` — bullet line; consecutive `-` lines form one paragraph with `• ` prefixes.
  - Blank line — ends the current paragraph or bullet group.
  - Other lines — accumulate into a plain paragraph until blank or heading.

  Lines are split on `\\n` only; each line is `String.trim/1`’d.

  ## Example

      markup = \"\"\"
      # Report

      First line.
      Second line.

      ## Details
      - Point A
      - Point B
      \"\"\"

      layout |> PrawnEx.Layout.Markup.apply(markup) |> PrawnEx.Layout.to_doc()
  """

  alias PrawnEx.Layout

  @doc """
  Parses `source` into flow tuples for `PrawnEx.Layout.vstack/3`:

  - `{:heading, text, opts}` — `:level` 1 or 2
  - `{:paragraph, text, opts}`
  """
  @spec parse(String.t()) :: [Layout.flow_block()]
  def parse(source) when is_binary(source) do
    lines =
      source
      |> String.split("\n")
      |> Enum.map(&String.trim/1)

    parse_lines(lines, [], :idle, [])
  end

  @doc "Parses markup and runs `Layout.vstack/3` (optional `vstack_opts`: `:gap`)."
  @spec apply(Layout.t(), String.t(), keyword()) :: Layout.t()
  def apply(%Layout{} = layout, source, vstack_opts \\ []) when is_binary(source) do
    Layout.vstack(layout, parse(source), vstack_opts)
  end

  defp parse_lines([], acc, :idle, _), do: Enum.reverse(acc)

  defp parse_lines([], acc, mode, buf) when mode != :idle do
    Enum.reverse(flush_buf(acc, mode, buf))
  end

  defp parse_lines(["" | rest], acc, :idle, _) do
    parse_lines(rest, acc, :idle, [])
  end

  defp parse_lines(["" | rest], acc, mode, buf) when mode in [:text_buf, :bullet_buf] do
    acc = flush_buf(acc, mode, buf)
    parse_lines(rest, acc, :idle, [])
  end

  defp parse_lines([line | rest], acc, :idle, _) do
    cond do
      String.starts_with?(line, "## ") ->
        title = line |> String.trim_leading("## ") |> String.trim()
        parse_lines(rest, [{:heading, title, [level: 2]} | acc], :idle, [])

      String.starts_with?(line, "# ") ->
        title = line |> String.trim_leading("# ") |> String.trim()
        parse_lines(rest, [{:heading, title, [level: 1]} | acc], :idle, [])

      String.starts_with?(line, "- ") ->
        item = line |> String.trim_leading("- ") |> String.trim()
        parse_lines(rest, acc, :bullet_buf, [item])

      true ->
        parse_lines(rest, acc, :text_buf, [line])
    end
  end

  defp parse_lines([line | rest], acc, :text_buf, buf) do
    cond do
      String.starts_with?(line, "## ") ->
        acc = flush_buf(acc, :text_buf, buf)
        title = line |> String.trim_leading("## ") |> String.trim()
        parse_lines(rest, [{:heading, title, [level: 2]} | acc], :idle, [])

      String.starts_with?(line, "# ") ->
        acc = flush_buf(acc, :text_buf, buf)
        title = line |> String.trim_leading("# ") |> String.trim()
        parse_lines(rest, [{:heading, title, [level: 1]} | acc], :idle, [])

      String.starts_with?(line, "- ") ->
        acc = flush_buf(acc, :text_buf, buf)
        item = line |> String.trim_leading("- ") |> String.trim()
        parse_lines(rest, acc, :bullet_buf, [item])

      line == "" ->
        acc = flush_buf(acc, :text_buf, buf)
        parse_lines(rest, acc, :idle, [])

      true ->
        parse_lines(rest, acc, :text_buf, [line | buf])
    end
  end

  defp parse_lines([line | rest], acc, :bullet_buf, buf) do
    cond do
      String.starts_with?(line, "## ") ->
        acc = flush_buf(acc, :bullet_buf, buf)
        title = line |> String.trim_leading("## ") |> String.trim()
        parse_lines(rest, [{:heading, title, [level: 2]} | acc], :idle, [])

      String.starts_with?(line, "# ") ->
        acc = flush_buf(acc, :bullet_buf, buf)
        title = line |> String.trim_leading("# ") |> String.trim()
        parse_lines(rest, [{:heading, title, [level: 1]} | acc], :idle, [])

      String.starts_with?(line, "- ") ->
        item = line |> String.trim_leading("- ") |> String.trim()
        parse_lines(rest, acc, :bullet_buf, [item | buf])

      line == "" ->
        acc = flush_buf(acc, :bullet_buf, buf)
        parse_lines(rest, acc, :idle, [])

      true ->
        acc = flush_buf(acc, :bullet_buf, buf)
        parse_lines(rest, acc, :text_buf, [line])
    end
  end

  defp flush_buf(acc, :idle, _), do: acc

  defp flush_buf(acc, :text_buf, []) do
    acc
  end

  defp flush_buf(acc, :text_buf, buf) do
    text =
      buf
      |> Enum.reverse()
      |> Enum.join("\n")

    if text == "", do: acc, else: [{:paragraph, text, []} | acc]
  end

  defp flush_buf(acc, :bullet_buf, []) do
    acc
  end

  defp flush_buf(acc, :bullet_buf, buf) do
    text =
      buf
      |> Enum.reverse()
      |> Enum.map_join("\n", &("• " <> &1))

    [{:paragraph, text, []} | acc]
  end
end
