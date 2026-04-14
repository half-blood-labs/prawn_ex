defmodule PrawnEx.Image.PNG do
  @moduledoc """
  Decodes PNG (8-bit truecolor RGB or RGBA, non-interlaced) to raw RGB bytes
  for PDF embedding (`/DeviceRGB`, `/FlateDecode`).

  RGBA pixels are composited on white. Indexed, grayscale, and interlaced PNGs
  return `{:error, {:unsupported_png, _}}`.
  """

  import Bitwise, only: [band: 2]

  @png_sig <<137, 80, 78, 71, 13, 10, 26, 10>>

  @doc """
  Loads PNG from path (string) or raw PNG binary.

  Returns `{:ok, %{data: rgb_binary, width: w, height: h, filter: :flate}}` or
  `{:error, reason}`.
  """
  @spec load(String.t() | binary()) :: {:ok, map()} | {:error, term()}
  def load(data) when is_binary(data) do
    if byte_size(data) >= 8 and binary_part(data, 0, 8) == @png_sig do
      decode(data)
    else
      case File.read(data) do
        {:ok, file_data} -> decode(file_data)
        err -> err
      end
    end
  end

  defp decode(<<@png_sig, rest::binary>>) do
    case read_chunks(rest, nil, []) do
      {:ok, ihdr, idat_parts} ->
        with {:ok, inflated} <- inflate_idat(idat_parts),
             {:ok, rgb} <- pixels_to_rgb(inflated, ihdr) do
          {:ok,
           %{
             data: rgb,
             width: ihdr.width,
             height: ihdr.height,
             filter: :flate
           }}
        end

      {:error, _} = e ->
        e
    end
  end

  defp decode(_), do: {:error, :not_png}

  defp read_chunks(<<len::32, typ::binary-size(4), rest::binary>>, ihdr, idats) do
    total = len + 4

    if byte_size(rest) < total do
      {:error, :truncated_png}
    else
      <<data::binary-size(len), _crc::32, tail::binary>> = rest

      case typ do
        "IHDR" ->
          case parse_ihdr(data) do
            {:ok, h} -> read_chunks(tail, h, idats)
            e -> e
          end

        "IDAT" ->
          read_chunks(tail, ihdr, [data | idats])

        "IEND" ->
          if ihdr do
            {:ok, ihdr, idats}
          else
            {:error, :missing_ihdr}
          end

        _ ->
          read_chunks(tail, ihdr, idats)
      end
    end
  end

  defp read_chunks(_, _, _), do: {:error, :truncated_png}

  defp parse_ihdr(<<w::32, h::32, bit_depth, color_type, compression, filter_method, interlace>>) do
    cond do
      compression != 0 or filter_method != 0 ->
        {:error, :invalid_png}

      interlace != 0 ->
        {:error, {:unsupported_png, :interlaced}}

      bit_depth != 8 ->
        {:error, {:unsupported_png, {:bit_depth, bit_depth}}}

      color_type not in [2, 6] ->
        {:error, {:unsupported_png, {:color_type, color_type}}}

      true ->
        {:ok,
         %{
           width: w,
           height: h,
           bit_depth: bit_depth,
           color_type: color_type,
           interlace: interlace
         }}
    end
  end

  defp parse_ihdr(_), do: {:error, :invalid_ihdr}

  defp inflate_idat(idat_parts) do
    compressed = idat_parts |> Enum.reverse() |> IO.iodata_to_binary()

    try do
      {:ok, :zlib.uncompress(compressed)}
    rescue
      _ -> {:error, :zlib_png}
    end
  end

  defp pixels_to_rgb(inflated, %{width: w, height: h, color_type: ct}) do
    bpp = if(ct == 2, do: 3, else: 4)
    row_len = w * bpp
    expected = h * (1 + row_len)

    if byte_size(inflated) != expected do
      {:error, {:png_inflate_size, byte_size(inflated), expected}}
    else
      {:ok, decode_scanlines(inflated, w, h, bpp, ct, row_len)}
    end
  end

  defp decode_scanlines(data, w, h, bpp, color_type, row_len) do
    Enum.reduce(0..(h - 1), {<<>>, nil}, fn row_idx, {rgb_acc, prior_recon} ->
      offset = row_idx * (1 + row_len)
      <<ftype, scan::binary-size(row_len), _::binary>> = binary_part(data, offset, 1 + row_len)
      recon = recon_row(ftype, scan, prior_recon, row_len, bpp)
      rgb_row = row_to_rgb(recon, w, bpp, color_type)
      {rgb_acc <> rgb_row, recon}
    end)
    |> elem(0)
  end

  defp row_to_rgb(recon, _w, 3, 2), do: recon

  defp row_to_rgb(recon, _w, 4, 6) do
    for <<r::8, g::8, b::8, a::8 <- recon>>, into: <<>> do
      <<blend(r, a), blend(g, a), blend(b, a)>>
    end
  end

  defp blend(c, a), do: band(div(c * a + 255 * (255 - a), 255), 0xFF)

  defp recon_row(ftype, scan, prior, row_len, bpp) do
    prior = prior || :binary.copy(<<0>>, row_len)

    Enum.reduce(0..(row_len - 1), <<>>, fn i, recon ->
      x = :binary.at(scan, i)
      pr = :binary.at(prior, i)
      left = if i < bpp, do: 0, else: :binary.at(recon, i - bpp)
      up_left = if i < bpp, do: 0, else: :binary.at(prior, i - bpp)

      r =
        case ftype do
          0 ->
            x

          1 ->
            band(x + left, 0xFF)

          2 ->
            band(x + pr, 0xFF)

          3 ->
            band(x + div(left + pr, 2), 0xFF)

          4 ->
            band(x + paeth(left, pr, up_left), 0xFF)
        end

      <<recon::binary, r>>
    end)
  end

  defp paeth(a, b, c) do
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)

    cond do
      pa <= pb and pa <= pc -> a
      pb <= pc -> b
      true -> c
    end
  end
end
