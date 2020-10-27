defmodule AndiWeb.ExtractHttpStepTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo
  import Checkov

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_values: 2,
      get_text: 2,
      find_elements: 2
    ]

  alias Andi.Services.UrlTest
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias AndiWeb.Helpers.FormTools
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Datasets.ExtractHttpStep

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"

  describe "updating query params" do
    setup do
      dataset =
        TDG.create_dataset(%{
          technical: %{
            extractSteps: [
              %{
                type: "http",
                method: "GET",
                url: "test.com",
                queryParams: %{"bar" => "biz", "blah" => "dah"},
                headers: %{"barl" => "biz", "yar" => "har"}
              }
            ]
          }
        })

      {:ok, andi_dataset} = Datasets.update(dataset)
      extract_step_id = get_extract_step_id(andi_dataset, 0)

      [dataset: andi_dataset, extract_step_id: extract_step_id]
    end

    data_test "new key/value inputs are added when add button is pressed for #{field}", %{
      conn: conn,
      dataset: dataset,
      extract_step_id: extract_step_id
    } do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")
      extract_http_step_form_view = find_child(extract_step_form_view, extract_step_id)

      assert html |> find_elements(key_class) |> length() == 2
      assert html |> find_elements(value_class) |> length() == 2

      html = render_click(extract_http_step_form_view, "add", %{"field" => Atom.to_string(field)})

      assert html |> find_elements(key_class) |> length() == 3
      assert html |> find_elements(value_class) |> length() == 3

      where(
        field: [:queryParams, :headers],
        key_class: [".url-form__source-query-params-key-input", ".url-form__source-headers-key-input"],
        value_class: [".url-form__source-query-params-value-input", ".url-form__source-headers-value-input"]
      )
    end

    data_test "key/value inputs are deleted when delete button is pressed for #{field}", %{
      conn: conn,
      dataset: dataset,
      extract_step_id: extract_step_id
    } do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")
      extract_http_step_form_view = find_child(extract_step_form_view, extract_step_id)

      assert html |> find_elements(key_class) |> length() == 2
      assert html |> find_elements(value_class) |> length() == 2

      btn_id =
        get_attributes(html, btn_class, "phx-value-id")
        |> hd()

      html = render_click(extract_http_step_form_view, "remove", %{"id" => btn_id, "field" => Atom.to_string(field)})

      [key_input] = html |> get_attributes(key_class, "class")
      refute btn_id =~ key_input

      [value_input] = html |> get_attributes(value_class, "class")
      refute btn_id =~ value_input

      where(
        field: [:queryParams, :headers],
        btn_class: [".url-form__source-query-params-delete-btn", ".url-form__source-headers-delete-btn"],
        key_class: [".url-form__source-query-params-key-input", ".url-form__source-headers-key-input"],
        value_class: [".url-form__source-query-params-value-input", ".url-form__source-headers-value-input"]
      )
    end

    data_test "does not have key/value inputs when dataset extract step has no #{field}", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{extractSteps: [%{"type" => "http", field => %{}}]}})
      {:ok, andi_dataset} = Datasets.update(dataset)
      extract_step_id = get_extract_step_id(andi_dataset, 0)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")
      extract_http_step_form_view = find_child(extract_step_form_view, extract_step_id)

      html = render(extract_http_step_form_view)

      assert html |> find_elements(key_class) |> Enum.empty?()
      assert html |> find_elements(value_class) |> Enum.empty?()

      where(
        field: [:queryParams, :headers],
        key_class: [".url-form__source-query-params-key-input", ".url-form__source-headers-key-input"],
        value_class: [".url-form__source-query-params-value-input", ".url-form__source-headers-value-input"]
      )
    end

    test "url is updated when query params are removed", %{conn: conn, dataset: dataset, extract_step_id: extract_step_id} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")
      extract_http_step_form_view = find_child(extract_step_form_view, extract_step_id)

      html = render(extract_http_step_form_view)

      assert html |> find_elements(".url-form__source-query-params-delete-btn") |> length() == 2

      get_attributes(html, ".url-form__source-query-params-delete-btn", "phx-value-id")
      |> Enum.each(fn btn_id ->
        render_click(extract_http_step_form_view, "remove", %{
          "id" => btn_id,
          "field" => Atom.to_string(:queryParams)
        })
      end)

      url_with_no_query_params =
        dataset.technical.extractSteps
        |> hd()
        |> Map.get(:url)
        |> Andi.URI.clear_query_params()

      assert render(extract_step_form_view) |> get_values(".extract-step-form__url input") == [url_with_no_query_params]
    end
  end

  describe "url testing" do
    @tag capture_log: true
    test "uses provided query params and headers", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            extractSteps: [
              %{
                type: "http",
                method: "GET",
                url: "123.com",
                queryParams: %{"x" => "y"},
                headers: %{"api-key" => "to-my-heart"}
              }
            ]
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      allow(UrlTest.test(any(), any()), return: %{time: 1_000, status: 200})

      extract_step_id = get_extract_step_id(dataset, 0)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_steps_form_view = find_child(view, "extract_step_form_editor")
      extract_http_step_form_view = find_child(extract_steps_form_view, extract_step_id)
      render_change(extract_http_step_form_view, :test_url, %{})

      assert_called(UrlTest.test("123.com", query_params: [{"x", "y"}], headers: [{"api-key", "to-my-heart"}]))
    end

    data_test "queryParams are updated when query params are added to url", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{extractSteps: [%{type: "http"}]}})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      extract_step_id = get_extract_step_id(dataset, 0)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_steps_form_view = find_child(view, "extract_step_form_editor")
      extract_http_step_form_view = find_child(extract_steps_form_view, extract_step_id)

      form_data = %{"url" => url}

      html =
        render_change(extract_http_step_form_view, :validate, %{
          "form_data" => form_data,
          "_target" => ["form_data", "url"]
        })

      assert get_values(html, ".url-form__source-query-params-key-input") == keys
      assert get_values(html, ".url-form__source-query-params-value-input") == values

      where([
        [:url, :keys, :values],
        ["http://example.com?cat=dog", ["cat"], ["dog"]],
        ["http://example.com?cat=dog&foo=bar", ["cat", "foo"], ["dog", "bar"]],
        ["http://example.com?cat=dog&foo+biz=bar", ["cat", "foo biz"], ["dog", "bar"]],
        ["http://example.com?cat=", ["cat"], [""]],
        ["http://example.com?=dog", [""], ["dog"]]
      ])
    end

    data_test "url is updated when query params are added", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{extractSteps: [%{type: "http"}]}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      extract_step_id = get_extract_step_id(dataset, 0)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")
      extract_http_step_form_view = find_child(extract_step_form_view, extract_step_id)

      form_data = %{"queryParams" => queryParams, "url" => initialSourceUrl}

      html =
        render_change(extract_http_step_form_view, :validate, %{
          "form_data" => form_data,
          "_target" => ["form_data", "queryParams"]
        })

      assert get_values(html, ".extract-step-form__url input") == [updatedUrl]

      where([
        [:initialSourceUrl, :queryParams, :updatedUrl],
        [
          "http://example.com",
          %{"0" => %{"key" => "dog", "value" => "car"}, "1" => %{"key" => "new", "value" => "thing"}},
          "http://example.com?dog=car&new=thing"
        ],
        ["http://example.com?dog=cat&fish=water", %{"0" => %{"key" => "dog", "value" => "cat"}}, "http://example.com?dog=cat"],
        ["http://example.com?dog=cat&fish=water", %{}, "http://example.com"],
        [
          "http://example.com?dog=cat",
          %{"0" => %{"key" => "some space", "value" => "thing=whoa"}},
          "http://example.com?some+space=thing%3Dwhoa"
        ]
      ])
    end

    test "status and time are displayed when source url is tested", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            extractSteps: [
              %{
                type: "http",
                method: "GET",
                url: "123.com",
                queryParams: %{"x" => "y"},
                headers: %{"api-key" => "to-my-heart"}
              }
            ]
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      allow(UrlTest.test("123.com", any()), return: %{time: 1_000, status: 200})

      extract_step_id = get_extract_step_id(dataset, 0)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")
      extract_http_step_form_view = find_child(extract_step_form_view, extract_step_id)

      assert get_text(html, ".test-status__code") == ""
      assert get_text(html, ".test-status__time") == ""

      render_change(extract_http_step_form_view, :test_url, %{})

      eventually(fn ->
        html = render(extract_http_step_form_view)
        assert get_text(html, ".test-status__code") == "Success"
        assert get_text(html, ".test-status__time") == "1000"
      end)
    end

    test "status is displayed with an appropriate class when it is between 200 and 399", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            extractSteps: [
              %{
                type: "http",
                method: "GET",
                url: "123.com",
                queryParams: %{"x" => "y"},
                headers: %{"api-key" => "to-my-heart"}
              }
            ]
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      allow(UrlTest.test("123.com", any()), return: %{time: 1_000, status: 200})

      extract_step_id = get_extract_step_id(dataset, 0)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")
      extract_http_step_form_view = find_child(extract_step_form_view, extract_step_id)

      assert get_text(html, ".test-status__code--good") == ""

      render_change(extract_http_step_form_view, :test_url, %{})

      eventually(fn ->
        html = render(extract_http_step_form_view)
        assert get_text(html, ".test-status__code--good") == "Success"
      end)
    end

    test "status is displayed with an appropriate class when it is not between 200 and 399", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            extractSteps: [
              %{
                type: "http",
                method: "GET",
                url: "123.com",
                queryParams: %{"x" => "y"},
                headers: %{"api-key" => "to-my-heart"}
              }
            ]
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      allow(UrlTest.test("123.com", any()), return: %{time: 1_000, status: 400})

      extract_step_id = get_extract_step_id(dataset, 0)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")
      extract_http_step_form_view = find_child(extract_step_form_view, extract_step_id)

      assert get_text(html, ".test-status__code--bad") == ""

      render_change(extract_http_step_form_view, :test_url, %{})

      eventually(fn ->
        html = render(extract_http_step_form_view)
        assert get_text(html, ".test-status__code--bad") == "Error"
        assert get_text(html, ".test-status__code--good") != "Error"
      end)
    end
  end

  test "required url field displays proper error message", %{conn: conn} do
    smrt_dataset =
      TDG.create_dataset(%{
        technical: %{
          extractSteps: [
            %{
              type: "http",
              method: "GET",
              url: "123.com",
              queryParams: %{"x" => "y"},
              headers: %{"api-key" => "to-my-heart"}
            }
          ]
        }
      })

    {:ok, dataset} =
      InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
      |> Datasets.save()

    extract_step_id = get_extract_step_id(dataset, 0)

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    extract_steps_form_view = find_child(view, "extract_step_form_editor")
    extract_http_step_form_view = find_child(extract_steps_form_view, extract_step_id)

    form_data = %{"url" => ""}

    html = render_change(extract_http_step_form_view, :validate, %{"form_data" => form_data})

    assert get_text(html, "#url-error-msg") == "Please enter a valid url."
  end

  data_test "invalid #{field} displays proper error message", %{conn: conn} do
    smrt_dataset =
      TDG.create_dataset(%{
        technical: %{
          extractSteps: [
            %{
              type: "http",
              method: "GET",
              url: "123.com",
              queryParams: %{"x" => "y"},
              headers: %{"api-key" => "to-my-heart"}
            }
          ]
        }
      })

    {:ok, dataset} = Datasets.update(smrt_dataset)

    extract_step_id = get_extract_step_id(dataset, 0)

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    extract_steps_form_view = find_child(view, "extract_step_form_editor")
    extract_http_step_form_view = find_child(extract_steps_form_view, extract_step_id)

    form_data = %{field => %{"0" => %{"key" => "", "value" => "where's my key"}}}

    html = render_change(extract_step_form_view, :save)

    assert get_text(html, "##{field}-error-msg") == "Please enter valid key(s)."

    where(field: ["queryParams", "headers"])
  end

  test "given a url with at least one invalid query param it marks the dataset as invalid" do
    form_data = %{"url" => "https://source.url.example.com?=oops&a=b"} |> FormTools.adjust_extract_query_params_for_url()

    changeset = ExtractHttpStep.changeset_from_form_data(form_data)

    refute changeset.valid?

    assert {:queryParams, {"has invalid format", [validation: :format]}} in changeset.errors

    assert %{queryParams: [%{key: nil, value: "oops"}, %{key: "a", value: "b"}]} = Ecto.Changeset.apply_changes(changeset)
  end

  defp get_extract_step_id(dataset, index) do
    dataset
    |> Andi.InputSchemas.StructTools.to_map()
    |> get_in([:technical, :extractSteps])
    |> Enum.at(index)
    |> Map.get(:id)
  end
end
