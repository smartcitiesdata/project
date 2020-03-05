defmodule Pipeline.Writer.TableWriterTest do
  use ExUnit.Case
  use Divo
  use Placebo

  alias Pipeline.Writer.TableWriter
  alias Pipeline.Writer.TableWriter.Compaction
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper, only: [eventually: 1]

  @expected_table_values [
    %{"Column" => "one", "Comment" => "", "Extra" => "", "Type" => "array(varchar)"},
    %{"Column" => "two", "Comment" => "", "Extra" => "", "Type" => "row(three decimal(18,3))"},
    %{
      "Column" => "four",
      "Comment" => "",
      "Extra" => "",
      "Type" => "array(row(five decimal(18,3)))"
    }
  ]

  @table_schema [
    %{name: "one", type: "list", itemType: "string"},
    %{name: "two", type: "map", subSchema: [%{name: "three", type: "decimal(18,3)"}]},
    %{
      name: "four",
      type: "list",
      itemType: "map",
      subSchema: [%{name: "five", type: "decimal(18,3)"}]
    }
  ]

  setup do
    session = PrestigeHelper.create_session()
    [session: session]
  end

  describe "init/1" do
    test "creates table with correct name and schema", %{session: session} do
      dataset =
        TDG.create_dataset(%{
          technical: %{systemName: "org_name_dataset_name", schema: @table_schema}
        })

      TableWriter.init(table: dataset.technical.systemName, schema: dataset.technical.schema)

      eventually(fn ->
        table = "describe hive.default.org_name_dataset_name"

        result =
          session
          |> Prestige.execute!(table)
          |> Prestige.Result.as_maps()

        assert result == @expected_table_values
      end)
    end

    test "handles prestige errors for invalid table names" do
      schema = [
        %{name: "one", type: "list", itemType: "string"},
        %{name: "two", type: "map", subSchema: [%{name: "three", type: "decimal(18,3)"}]},
        %{name: "four", type: "list", itemType: "map", subSchema: [%{name: "five", type: "integer"}]}
      ]

      dataset = TDG.create_dataset(%{technical: %{systemName: "this.is.invalid", schema: schema}})

      assert {:error, _} = TableWriter.init(table: dataset.technical.systemName, schema: dataset.technical.schema)
    end

    test "escapes invalid column names", %{session: session} do
      expected = [%{"Column" => "on", "Comment" => "", "Extra" => "", "Type" => "boolean"}]
      schema = [%{name: "on", type: "boolean"}]
      dataset = TDG.create_dataset(%{technical: %{systemName: "foo", schema: schema}})
      TableWriter.init(table: dataset.technical.systemName, schema: dataset.technical.schema)

      eventually(fn ->
        table = "describe hive.default.foo"

        result =
          session
          |> Prestige.execute!(table)
          |> Prestige.Result.as_maps()

        assert result == expected
      end)
    end
  end

  describe "write/2" do
    test "inserts records", %{session: session} do
      schema = [%{name: "one", type: "string"}, %{name: "two", type: "integer"}]
      dataset = TDG.create_dataset(%{technical: %{systemName: "foo__bar", schema: schema}})

      TableWriter.init(table: dataset.technical.systemName, schema: schema)

      datum1 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"one" => "hello", "two" => 42}})
      datum2 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"one" => "goodbye", "two" => 9001}})

      TableWriter.write([datum1, datum2], table: dataset.technical.systemName, schema: schema)

      eventually(fn ->
        query = "select * from foo__bar"

        result =
          session
          |> Prestige.query!(query)
          |> Prestige.Result.as_maps()

        assert result == [%{"one" => "hello", "two" => 42}, %{"one" => "goodbye", "two" => 9001}]
      end)
    end

    test "inserts heavily nested records", %{session: session} do
      schema = [
        %{name: "first_name", type: "string"},
        %{name: "age", type: "decimal"},
        %{name: "friend_names", type: "list", itemType: "string"},
        %{
          name: "friends",
          type: "list",
          itemType: "map",
          subSchema: [
            %{name: "first_name", type: "string"},
            %{name: "pet", type: "string"}
          ]
        },
        %{
          name: "spouse",
          type: "map",
          subSchema: [
            %{name: "first_name", type: "string"},
            %{name: "gender", type: "string"},
            %{
              name: "next_of_kin",
              type: "map",
              subSchema: [
                %{name: "first_name", type: "string"},
                %{name: "date_of_birth", type: "string"}
              ]
            }
          ]
        }
      ]

      payload = %{
        "first_name" => "Joe",
        "age" => 10,
        "friend_names" => ["bob", "sally"],
        "friends" => [
          %{"first_name" => "Bill", "pet" => "Bunco"},
          %{"first_name" => "Sally", "pet" => "Bosco"}
        ],
        "spouse" => %{
          "first_name" => "Susan",
          "gender" => "female",
          "next_of_kin" => %{
            "first_name" => "Joel",
            "date_of_birth" => "1941-07-12"
          }
        }
      }

      dataset = TDG.create_dataset(%{technical: %{systemName: "foo__baz", schema: schema}})
      TableWriter.init(table: dataset.technical.systemName, schema: schema)

      datum = TDG.create_data(dataset_id: dataset.id, payload: payload)

      expected = %{
        "age" => "10",
        "first_name" => "Joe",
        "friend_names" => ["bob", "sally"],
        "friends" => [%{"first_name" => "Bill", "pet" => "Bunco"}, %{"first_name" => "Sally", "pet" => "Bosco"}],
        "spouse" => %{
          "first_name" => "Susan",
          "gender" => "female",
          "next_of_kin" => %{"date_of_birth" => "1941-07-12", "first_name" => "Joel"}
        }
      }

      assert :ok = TableWriter.write([datum], table: dataset.technical.systemName, schema: schema)

      eventually(fn ->
        query = "select * from foo__baz"

        result =
          session
          |> Prestige.execute!(query)
          |> Prestige.Result.as_maps()

        assert result == [expected]
      end)
    end
  end

  describe "compact/1" do
    test "compacts a table without changing data", %{session: session} do
      sub = [%{name: "three", type: "boolean"}]
      schema = [%{name: "one", type: "list", itemType: "decimal"}, %{name: "two", type: "map", subSchema: sub}]
      dataset = TDG.create_dataset(%{technical: %{schema: schema, systemName: "a__b"}})

      TableWriter.init(table: dataset.technical.systemName, schema: schema)

      Enum.each(1..15, fn n ->
        payload = %{"one" => [n], "two" => %{"three" => false}}
        datum = TDG.create_data(%{dataset_id: dataset.id, payload: payload})
        TableWriter.write([datum], table: dataset.technical.systemName, schema: schema)
      end)

      eventually(fn ->
        query = "select count(1) from #{dataset.technical.systemName}"

        result =
          session
          |> Prestige.query!(query)

        assert result.rows == [[15]]
      end)

      assert :ok == TableWriter.compact(table: dataset.technical.systemName)

      eventually(fn ->
        query = "select count(1) from #{dataset.technical.systemName}"

        result =
          session
          |> Prestige.query!(query)

        assert result.rows == [[15]]
      end)
    end

    test "fails without altering state if it was going to change data", %{session: session} do
      allow Compaction.measure(any(), any()), return: {6, 10}, meck_options: [:passthrough]

      schema = [%{name: "abc", type: "string"}]
      dataset = TDG.create_dataset(%{technical: %{schema: schema, systemName: "xyz"}})

      TableWriter.init(table: dataset.technical.systemName, schema: schema)

      Enum.each(1..15, fn n ->
        payload = %{"abc" => "#{n}"}
        datum = TDG.create_data(%{dataset_id: dataset.id, payload: payload})
        TableWriter.write([datum], table: "xyz", schema: schema)
      end)

      assert {:error, _} = TableWriter.compact(table: "xyz")

      eventually(fn ->
        query = "select count(1) from xyz"

        result =
          session
          |> Prestige.query!(query)

        assert result.rows == [[15]]
      end)
    end
  end

  test "should delete and rename the table when delete table is called", %{session: session} do
    dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name", schema: @table_schema}
      })

    [table: dataset.technical.systemName, schema: dataset.technical.schema]
    |> TableWriter.init()

    eventually(fn ->
      assert @expected_table_values ==
               "DESCRIBE #{dataset.technical.systemName}"
               |> execute_query(session)
    end)

    [dataset: dataset]
    |> TableWriter.delete()

    eventually(fn ->
      expected_table_name =
        "SHOW TABLES LIKE '%#{dataset.technical.systemName}%'"
        |> execute_query(session)
        |> Enum.find(fn x ->
          x["Table"]
          |> String.ends_with?(dataset.technical.systemName)
        end)
        |> verify_deleted_table_name(dataset.technical.systemName)

      assert @expected_table_values ==
               "DESCRIBE #{expected_table_name}"
               |> execute_query(session)
    end)
  end

  defp execute_query(query, session) do
    session
    |> Prestige.execute!(query)
    |> Prestige.Result.as_maps()
  end

  defp verify_deleted_table_name(table, table_name) do
    case String.starts_with?(table["Table"], "deleted") do
      true -> table["Table"]
      _ -> nil
    end
  end
end
