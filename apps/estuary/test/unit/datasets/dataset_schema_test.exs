defmodule Estuary.Datasets.DatasetSchemaTest do
  # , async: true
  use ExUnit.Case
  use Placebo

  alias Estuary.Datasets.DatasetSchema
  alias SmartCity.TestDataGenerator, as: TDG
  alias Estuary.DataWriterHelper
  import Mox

  @table_name Application.get_env(:estuary, :table_name)

  # @repo_name "intro-to-ruby"
  # @org_name "flatiron-labs"
  # @author_username "AuthorUsername"

  # setup :set_mox_from_context
  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    # reader_args = [instance: any(), connection: any(), endpoints: any(), topic: any(), handler: any()]
    DatasetSchema
    |> allow(:table_schema,
      return: [
        table: @table_name,
        schema: [
          %{description: "N/A", name: "author", type: "string"},
          %{description: "N/A", name: "create_ts", type: "long"},
          %{description: "N/A", name: "data", type: "string"},
          %{description: "N/A", name: "type", type: "string"}
        ]
      ]
    )

    # assert  MockTable.init(any()) == :ok
    # assert  MockData.init(any()) == :ok
    # assert  MockReader.init(any()) == :ok
    MockTable
    |> stub(:init, fn _ -> :ok end)

    MockData
    |> stub(:init, fn _ -> :ok end)

    MockReader
    |> stub(:init, fn _ -> :ok end)

    # MockTable
    # |> expect(:init, &init/1)
    # MockData
    # |> expect(:init, &init/1)
    # MockReader
    # |> expect(:init, &init/1)
  end

  test "should return table and schema" do
    expected_value = [
      table: @table_name,
      schema: [
        %{description: "N/A", name: "author", type: "string"},
        %{description: "N/A", name: "create_ts", type: "long"},
        %{description: "N/A", name: "data", type: "string"},
        %{description: "N/A", name: "type", type: "string"}
      ]
    ]

    actual_value = DatasetSchema.table_schema()
    assert expected_value == actual_value
  end

  test "should return table name" do
    expected_value = @table_name
    actual_value = DatasetSchema.table_name()
    assert expected_value == actual_value
  end

  test "should return schema" do
    expected_value = [
      %{description: "N/A", name: "author", type: "string"},
      %{description: "N/A", name: "create_ts", type: "long"},
      %{description: "N/A", name: "data", type: "string"},
      %{description: "N/A", name: "type", type: "string"}
    ]

    actual_value = DatasetSchema.schema()
    assert expected_value == actual_value
  end

  test "should return payload when given ingest SmartCity Dataset struct" do
    author = DataWriterHelper.make_author()
    time_stamp = DataWriterHelper.make_time_stamp()
    dataset = TDG.create_dataset(%{})

    expected_value = [
      %{
        payload: %{
          "author" => author,
          "create_ts" => time_stamp,
          "data" => Jason.encode!(dataset),
          "type" => "data:ingest:start"
        }
      }
    ]

    actual_value =
      %{
        author: author,
        create_ts: time_stamp,
        data: dataset,
        forwarded: false,
        type: "data:ingest:start"
      }
      |> DatasetSchema.make_datawriter_payload()

    assert expected_value == actual_value
  end
end
