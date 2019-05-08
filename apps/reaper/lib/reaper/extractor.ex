defmodule Reaper.Extractor do
  @moduledoc false
  use Tesla

  @download_timeout Application.get_env(:reaper, :download_timeout, 600_000)

  plug(Tesla.Middleware.FollowRedirects)
  plug(Tesla.Middleware.Retry, delay: 500, max_retries: 10)

  def extract(url, "csv") do
    filename = determine_filename()
    file = File.open!(filename, [:write])

    url
    |> follow_redirect()
    |> Downstream.get!(file, timeout: @download_timeout)

    File.close(file)
    {:file, filename}
  end

  def extract(url, _format) do
    case get(url) do
      {:ok, response} ->
        response.body

      {:error, reason} ->
        target =
          url
          |> String.split("?")
          |> List.first()

        raise "Failed calling '" <> target <> "': " <> inspect(reason)
    end
  end

  defp determine_filename() do
    Application.get_env(:reaper, :download_dir, "") <> "#{inspect(self())}"
  end

  defp follow_redirect(url) do
    case HTTPoison.head(url) do
      {:ok, %HTTPoison.Response{status_code: status_code} = response} when status_code in [301, 302] ->
        response
        |> location()
        |> follow_redirect()

      _ ->
        url
    end
  end

  defp location(%HTTPoison.Response{headers: headers}) do
    {_location, url} =
      headers
      |> Enum.find(fn {key, _value} -> String.downcase(key) == "location" end)

    url
  end
end
