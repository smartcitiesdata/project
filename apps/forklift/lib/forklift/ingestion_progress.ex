defmodule Forklift.IngestionProgress do
  @spec new_message(String.t(), Integer.t()) :: :in_progress | :ingestion_complete
  def new_message(ingestion_id, extract_time) do
    extract_id = get_extract_id(ingestion_id, extract_time)

    increment_ingestion_count(extract_id)

    case(is_extract_done(extract_id)) do
      false ->
        :in_progress

      true ->
        complete_extract(extract_id)
    end
  end

  @spec store_target(String.t(), Integer.t(), Integer.t()) :: :in_progress | :ingestion_complete
  def store_target(ingestion_id, extract_time, target) do
    extract_id = get_extract_id(ingestion_id, extract_time)

    set_extract_target(extract_id, target)

    case(is_extract_done(extract_id)) do
      false ->
        :in_progress

      true ->
        complete_extract(extract_id)
    end
  end

  @spec increment_ingestion_count(String.t()) :: integer()
  defp increment_ingestion_count(extract_id) do
    Redix.command!(:redix, ["INCR", get_count_key(extract_id)])
  end

  @spec set_extract_target(String.t(), Integer.t()) :: integer()
  defp set_extract_target(extract_id, target) do
    Redix.command!(:redix, ["SET", get_target_key(extract_id), target])
  end

  @spec is_extract_done(String.t()) :: boolean()
  defp is_extract_done(extract_id) do
    target = Redix.command!(:redix, ["GET", get_target_key(extract_id)])
    current = Redix.command!(:redix, ["GET", get_count_key(extract_id)])

    case target && current do
      nil ->
        false

      _ ->
        String.to_integer(current) >= String.to_integer(target)
    end
  end

  defp get_count_key(extract_id) do
    extract_id <> "_count"
  end

  defp get_target_key(extract_id) do
    extract_id <> "_target"
  end

  defp complete_extract(extract_id) do
    Redix.command!(:redix, ["GETDEL", get_count_key(extract_id)])
    Redix.command!(:redix, ["GETDEL", get_target_key(extract_id)])
    :ingestion_complete
  end

  @spec get_extract_id(String.t(), Integer.t()) :: String.t()
  defp get_extract_id(ingestion_id, extract_time) do
    ingestion_id <> "_" <> (extract_time |> Integer.to_string())
  end
end
