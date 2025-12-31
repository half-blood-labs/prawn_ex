defmodule PrawnEx.Document do
  @moduledoc """
  Document spec: immutable struct holding options and a list of pages.

  Options:
  - `:page_size` - `:a4`, `:letter`, etc. (default `:a4`)
  - `:margins` - optional `%{left: pt, right: pt, top: pt, bottom: pt}`

  The last page in `pages` is the "current" page for appending content.
  """

  defstruct [:opts, :pages]

  @type opts :: keyword()

  @type t :: %__MODULE__{
          opts: keyword(),
          pages: [PrawnEx.Page.t()]
        }

  @doc """
  Creates a new document with optional options.

  ## Examples

      iex> doc = PrawnEx.Document.new()
      iex> doc.pages
      []
      iex> doc = PrawnEx.Document.new(page_size: :letter)
      iex> doc.opts[:page_size]
      :letter
  """
  @spec new(opts()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      opts: Keyword.new(opts),
      pages: []
    }
  end

  @doc """
  Appends a new page and returns the updated document. The new page becomes current.
  """
  @spec add_page(t()) :: t()
  def add_page(%__MODULE__{pages: pages} = doc) do
    %{doc | pages: pages ++ [PrawnEx.Page.new()]}
  end

  @doc """
  Returns the current page (last in the list), or nil if no pages.
  """
  @spec current_page(t()) :: PrawnEx.Page.t() | nil
  def current_page(%__MODULE__{pages: []}), do: nil
  def current_page(%__MODULE__{pages: pages}), do: List.last(pages)

  @doc """
  Appends a content op to the current page. If there is no page, adds one first.
  Returns the updated document.
  """
  @spec append_op(t(), PrawnEx.Page.content_op()) :: t()
  def append_op(doc, op) do
    doc = ensure_current_page(doc)
    current = current_page(doc)
    updated_page = PrawnEx.Page.add_op(current, op)
    replace_current_page(doc, updated_page)
  end

  defp ensure_current_page(%__MODULE__{pages: []} = doc), do: add_page(doc)
  defp ensure_current_page(doc), do: doc

  defp replace_current_page(%__MODULE__{pages: pages} = doc, updated_page) do
    idx = length(pages) - 1
    new_pages = List.replace_at(pages, idx, updated_page)
    %{doc | pages: new_pages}
  end

  @doc """
  Injects ops at the start and/or end of a page's content. Used for headers/footers.

  `page_index` is 0-based. Returns the document with that page's content_ops
  set to `prepend_ops ++ current_ops ++ append_ops`.
  """
  @spec inject_page_ops(t(), non_neg_integer(), [PrawnEx.Page.content_op()], [
          PrawnEx.Page.content_op()
        ]) :: t()
  def inject_page_ops(doc, page_index, prepend_ops, append_ops) do
    page = Enum.at(doc.pages, page_index)
    new_ops = prepend_ops ++ page.content_ops ++ append_ops
    updated_page = %{page | content_ops: new_ops}
    new_pages = List.replace_at(doc.pages, page_index, updated_page)
    %{doc | pages: new_pages}
  end
end
