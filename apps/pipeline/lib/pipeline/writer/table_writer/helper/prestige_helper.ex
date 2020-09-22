defmodule Pipeline.Writer.TableWriter.Helper.PrestigeHelper do
  alias Pipeline.Writer.TableWriter.Statement
  @moduledoc false

  require Logger

  def execute_query(query) do
    create_session()
    |> Prestige.execute(query)
  rescue
    error -> error
  end

  def execute_async_query(statement) do
    Task.async(fn ->
      try do
        execute_query(statement)
      rescue
        e -> Logger.error("Failed to execute '#{statement}': #{inspect(e)}")
      end
    end)
  end

  def create_session() do
    Application.get_env(:prestige, :session_opts)
    |> Prestige.new_session()
  end

  def drop_table(table) do
    %{table: table}
    |> Statement.drop()
    |> execute_query()
  end

  def count(table) do
    execute_query("select count(1) from #{table}")
    |> extract_count()
  end

  def count_query(query) do
    execute_query(query)
    |> extract_count()
  end

  defp extract_count({:ok, results}) do
    [[new_row_count]] = results.rows
    new_row_count
  end

  defp extract_count(_), do: :error

  def table_exists?(table) do
    case execute_query("show create table #{table}") do
      {:ok, _} -> true
      _ -> false
    end
  end
end
