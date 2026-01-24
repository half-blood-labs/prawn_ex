defmodule PrawnEx.Image.PNG do
  @moduledoc """
  Minimal PNG loader for PDF embedding. Supports RGB 8-bit, filter type 0 (None).
  Returns raw RGB bytes (compressed with FlateDecode for PDF).
  """
  @png_signature <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>

  @doc """
  Loads PNG from path or binary. Returns {:ok, %{data: binary, width: w, height: h, filter: :flate}}
  or {:error, reason}. Supports RGB 8-bit, filter 0 only.
  """
  @spec load(String.t() | binary()) :: {:ok, map()} | {:error, term()}
  def load(data) when is_binary(data) do
    if binary_part(data, 0, min(8, byte_size(data))) == @png_signature do
      parse(data)
    else
      case File.read(data) do
        {:ok, file_data} -> parse(file_data)
        err -> err
      end
    end
  end

  defp parse(<<@png_signature, rest::binary>>) do
    case parse_chunks(rest, %{}) do
      %{ihdr: ihdr, idat: idat} when is_binary(idat) ->
        {width, height, _depth, color_type} = ihdr

        if color_type != 2,
          do: {:error, :unsupported_color_type},
          else: decode_idat(idat, width, height, 1 + width * 3)

      _ ->
        {:error, :invalid_png}
    end
  end

  defp parse(_), do: {:error, :not_png}

  defp parse_chunks(<<_len::32-big, "IHDR", ihdr::binary-size(13), _crc::32, rest::binary>>, acc) do
    <<width::32-big, height::32-big, depth, color_type, _::binary>> = ihdr
    parse_chunks(rest, Map.put(acc, :ihdr, {width, height, depth, color_type}))
  end

  defp parse_chunks(<<len::32-big, "IDAT", data::binary-size(len), _crc::32, rest::binary>>, acc) do
    idat = Map.get(acc, :idat, <<>>) <> data
    parse_chunks(rest, Map.put(acc, :idat, idat))
  end

  defp parse_chunks(
         <<len::32-big, _type::binary-size(4), _::binary-size(len), _crc::32, rest::binary>>,
         acc
       ) do
    parse_chunks(rest, acc)
  end

  defp parse_chunks(_, acc), do: acc

  defp decode_idat(idat, width, height, bytes_per_row) do
    case :zlib.uncompress(idat) do
      raw when is_binary(raw) ->
        if byte_size(raw) != bytes_per_row * height,
          do: {:error, :invalid_idat},
          else: strip_filter_and_compress(raw, width, height, bytes_per_row)

      _ ->
        {:error, :decompress_failed}
    end
  end

  defp strip_filter_and_compress(raw, width, height, bytes_per_row) do
    rgb =
      for row <- 0..(height - 1),
          offset = row * bytes_per_row,
          <<_filter, row_data::binary-size(bytes_per_row - 1)>> =
            binary_part(raw, offset, bytes_per_row),
          into: <<>> do
        row_data
      end

    compressed = :zlib.compress(rgb)
    {:ok, %{data: compressed, width: width, height: height, filter: :flate}}
  end
end
