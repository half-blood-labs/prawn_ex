defmodule PrawnEx.LayoutTest do
  use ExUnit.Case, async: true

  alias PrawnEx.Layout
  alias PrawnEx.Layout.Markup

  test "attach sets cursor below top margin and content width" do
    doc = PrawnEx.Document.new(page_size: :a4) |> PrawnEx.add_page()
    l = Layout.attach(doc, margins: %{top: 60, left: 50, right: 50, bottom: 50})

    assert l.page_w == 595
    assert l.page_h == 842
    assert l.cursor_y == 842 - 60
    assert l.content_left == 50
    assert l.content_width == 595 - 50 - 50
  end

  test "heading moves cursor down" do
    doc = PrawnEx.Document.new() |> PrawnEx.add_page()
    l0 = Layout.attach(doc, margins: %{top: 60, left: 50, right: 50, bottom: 50})
    y0 = l0.cursor_y

    l1 = Layout.heading(l0, "Title", font_size: 24, lead: 1.0, gap_after: 6)
    assert l1.cursor_y == y0 - (24 * 1.0 + 6)
    assert l1.doc != l0.doc
  end

  test "paragraph advances cursor from last baseline" do
    doc = PrawnEx.Document.new() |> PrawnEx.add_page()
    l0 = Layout.attach(doc, margins: %{top: 60, left: 50, right: 50, bottom: 50})

    l1 =
      Layout.paragraph(l0, "A\nB\nC",
        font_size: 10,
        line_height: 15,
        gap_after: 4
      )

    # First baseline at y0, third at y0 - 30, then gap_after 4
    y0 = l0.cursor_y
    assert l1.cursor_y == y0 - 30 - 4
  end

  test "to_doc returns document for to_binary" do
    doc = PrawnEx.Document.new() |> PrawnEx.add_page()
    l = Layout.attach(doc, margins: 50) |> Layout.heading("Hi", font_size: 12)

    bin = l |> Layout.to_doc() |> PrawnEx.to_binary()
    assert bin =~ "%PDF-1.4"
    assert bin =~ "Hi"
  end

  test "escape updates doc and cursor" do
    doc = PrawnEx.Document.new() |> PrawnEx.add_page()

    l =
      Layout.attach(doc, margins: 50)
      |> Layout.escape(fn d, ctx ->
        d = PrawnEx.set_font(d, "Helvetica", 10)
        d = PrawnEx.text_at(d, {ctx.content_left, ctx.cursor_y}, "X")
        {d, ctx.cursor_y - 20}
      end)

    assert l.cursor_y == 842 - 50 - 20
    bin = Layout.to_doc(l) |> PrawnEx.to_binary()
    assert bin =~ "(X)"
  end

  test "vstack runs multiple flow blocks" do
    doc = PrawnEx.Document.new() |> PrawnEx.add_page()

    l =
      Layout.attach(doc, margins: %{top: 60, left: 50, right: 50, bottom: 50})
      |> Layout.vstack(
        [
          {:heading, "A", [font_size: 14]},
          {:paragraph, "Body", [font_size: 10, gap_after: 4]},
          {:spacer, 6},
          {:heading, "B", [font_size: 14]}
        ],
        gap: 4
      )

    bin = Layout.to_doc(l) |> PrawnEx.to_binary()
    assert bin =~ "(A)"
    assert bin =~ "(Body)"
    assert bin =~ "(B)"
  end

  test "hstack places text in two columns" do
    doc = PrawnEx.Document.new() |> PrawnEx.add_page()

    l =
      Layout.attach(doc, margins: %{top: 60, left: 50, right: 50, bottom: 50})
      |> Layout.hstack(
        [
          {120, fn col -> Layout.paragraph(col, "Left", font_size: 10, gap_after: 2) end},
          {120, fn col -> Layout.paragraph(col, "Right", font_size: 10, gap_after: 2) end}
        ],
        gap: 10
      )

    bin = Layout.to_doc(l) |> PrawnEx.to_binary()
    assert bin =~ "(Left)"
    assert bin =~ "(Right)"
  end

  test "region with new page adds a second page when paragraph crosses floor" do
    doc = PrawnEx.Document.new() |> PrawnEx.add_page()

    l =
      Layout.attach(doc,
        margins: %{top: 60, left: 50, right: 50, bottom: 50},
        region: %{floor_y: 120},
        on_overflow: :new_page
      )
      |> Layout.spacer(700)
      |> Layout.paragraph("After break", font_size: 12, line_height: 14, gap_after: 4)

    assert length(Layout.to_doc(l).pages) == 2
    bin = Layout.to_doc(l) |> PrawnEx.to_binary()
    assert bin =~ "After break"
  end

  test "Markup.parse builds heading and paragraph blocks" do
    blocks =
      Markup.parse("""
      # Title

      Hello world.
      """)

    assert Enum.any?(blocks, &match?({:heading, "Title", _}, &1))
    assert Enum.any?(blocks, &match?({:paragraph, "Hello world.", _}, &1))
  end

  test "Markup.apply renders into PDF" do
    doc = PrawnEx.Document.new() |> PrawnEx.add_page()

    bin =
      Layout.attach(doc, margins: %{top: 60, left: 50, right: 50, bottom: 50})
      |> Markup.apply("# Doc\n\nHi.", gap: 4)
      |> Layout.to_doc()
      |> PrawnEx.to_binary()

    assert bin =~ "(Doc)"
    assert bin =~ "(Hi.)"
  end
end
