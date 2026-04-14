# Run with: mix run scripts/swedish_characters.exs
# Writes a PDF with Swedish characters to output/swedish_characters.pdf
# Verifies that å, ä, ö (and uppercase Å, Ä, Ö) render correctly
# with WinAnsiEncoding on the built-in PDF fonts.

output_dir = Path.join(File.cwd!(), "output")
File.mkdir_p!(output_dir)
path = Path.join(output_dir, "swedish_characters.pdf")

page_w = 595
page_h = 842
margin = 50

:ok =
  PrawnEx.build(path, [], fn doc ->
    doc
    # —— Title ——
    |> PrawnEx.set_font("Helvetica", 22)
    |> PrawnEx.text_at({margin, page_h - 60}, "Svenska tecken — Swedish Characters")
    |> PrawnEx.set_stroking_gray(0.8)
    |> PrawnEx.line({margin, page_h - 75}, {page_w - margin, page_h - 75})
    |> PrawnEx.stroke()
    |> PrawnEx.set_stroking_gray(0)
    # —— Lowercase åäö ——
    |> PrawnEx.set_font("Helvetica", 14)
    |> PrawnEx.text_at({margin, page_h - 110}, "Lowercase: å ä ö")
    # —— Uppercase ÅÄÖ ——
    |> PrawnEx.text_at({margin, page_h - 135}, "Uppercase: Å Ä Ö")
    # —— Common Swedish words ——
    |> PrawnEx.set_font("Helvetica", 12)
    |> PrawnEx.text_at({margin, page_h - 175}, "Vanliga ord / Common words:")
    |> PrawnEx.set_font("Helvetica", 11)
    |> PrawnEx.text_at({margin + 10, page_h - 200}, "räksmörgås — shrimp sandwich")
    |> PrawnEx.text_at({margin + 10, page_h - 220}, "ärtsoppa — pea soup")
    |> PrawnEx.text_at({margin + 10, page_h - 240}, "sjuksköterska — nurse")
    |> PrawnEx.text_at({margin + 10, page_h - 260}, "Göteborg — Gothenburg")
    |> PrawnEx.text_at({margin + 10, page_h - 280}, "Malmö — Malmö")
    |> PrawnEx.text_at({margin + 10, page_h - 300}, "Söderström — a common surname")
    |> PrawnEx.text_at({margin + 10, page_h - 320}, "Ångström — unit of length")
    # —— Extended Latin-1 characters ——
    |> PrawnEx.set_font("Helvetica", 12)
    |> PrawnEx.text_at({margin, page_h - 360}, "Fler tecken / More characters:")
    |> PrawnEx.set_font("Helvetica", 11)
    |> PrawnEx.text_at({margin + 10, page_h - 385}, "é è ê ë — French accents")
    |> PrawnEx.text_at({margin + 10, page_h - 405}, "ü ß — German characters")
    |> PrawnEx.text_at({margin + 10, page_h - 425}, "ñ — Spanish tilde")
    |> PrawnEx.text_at({margin + 10, page_h - 445}, "© ® € £ ¥ — symbols")
    # —— Table with Swedish content ——
    |> PrawnEx.set_font("Helvetica", 12)
    |> PrawnEx.text_at({margin, page_h - 485}, "Tabell / Table:")
    |> PrawnEx.table(
      [
        ["Namn", "Stad", "Beskrivning"],
        ["Björk", "Malmö", "Sångare från nörden"],
        ["Åsa", "Göteborg", "Författare"],
        ["Örjan", "Västerås", "Möbelsnickare"]
      ],
      at: {margin, page_h - 510},
      column_widths: [120, 120, 240],
      header: true,
      cell_padding: 8
    )
    # —— text_box wrapping with Swedish text ——
    |> PrawnEx.set_font("Helvetica", 12)
    |> PrawnEx.text_at({margin, page_h - 630}, "Textbrytning / Text wrapping:")
    |> PrawnEx.set_font("Helvetica", 10)
    |> PrawnEx.text_box(
      "Räksmörgåsen är en klassisk svensk rätt som ofta serveras på julbordet. Den innehåller räkor, ägg, majonnäs och dill på en skiva bröd. Många svenskar äter även ärtsoppa på torsdagar, en tradition som går långt tillbaka i tiden.",
      at: {margin, page_h - 650},
      width: page_w - 2 * margin,
      font_size: 10,
      line_height: 14
    )
  end)

IO.puts("Swedish characters PDF written to: #{path}")
IO.puts("Open it and verify that å, ä, ö, Å, Ä, Ö all display correctly.")
