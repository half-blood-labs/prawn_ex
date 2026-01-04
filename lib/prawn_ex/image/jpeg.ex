defmodule PrawnEx.Image.JPEG do
  @moduledoc """
  Loads JPEG for PDF embedding. Reads dimensions from SOF0/SOF2 and returns
  raw JPEG bytes (embedded as /DCTDecode stream).
  """

  @sof_markers [0xC0, 0xC1, 0xC2]

  @doc """
  Loads JPEG from path (string) or raw binary. Returns {:ok, %{data: binary, width: w, height: h}}
  or {:error, reason}. Data is the full JPEG bytes (embedded as-is with /DCTDecode).
  """
  @spec load(String.t() | binary()) :: {:ok, map()} | {:error, term()}
  def load(data) when is_binary(data) do
    if binary_part(data, 0, min(2, byte_size(data))) == <<0xFF, 0xD8>> do
      parse(data)
    else
      case File.read(data) do
        {:ok, file_data} -> parse(file_data)
        err -> err
      end
    end
  end

  defp parse(<<0xFF, 0xD8, _rest::binary>> = data) do
    case find_sof(data) do
      {:ok, width, height} -> {:ok, %{data: data, width: width, height: height, filter: :dct}}
      :error -> {:error, :no_sof_segment}
    end
  end

  defp parse(_), do: {:error, :not_jpeg}

  defp find_sof(data), do: find_sof(data, 2)

  defp find_sof(<<0xFF, marker, rest::binary>>, _)
       when marker in @sof_markers and byte_size(rest) >= 7 do
    <<_len::16-big, _prec, height::16-big, width::16-big, _::binary>> = rest
    {:ok, width, height}
  end

  defp find_sof(<<0xFF, marker, rest::binary>>, _)
       when marker in [0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0x01, 0xFE] do
    # RST, SOI, EOI, TEM, COM - no length field, skip 2 bytes
    find_sof(rest, 0)
  end

  defp find_sof(<<0xFF, _marker, rest::binary>>, _) do
    # Segment with length (2 bytes big-endian, includes length field)
    if byte_size(rest) >= 2 do
      <<len::16-big, _::binary>> = rest

      if byte_size(rest) >= len do
        rest = binary_part(rest, len, byte_size(rest) - len)
        find_sof(rest, 0)
      else
        :error
      end
    else
      :error
    end
  end

  defp find_sof(<<_::8, rest::binary>>, _), do: find_sof(rest, 0)
  defp find_sof(<<>>, _), do: :error
end
