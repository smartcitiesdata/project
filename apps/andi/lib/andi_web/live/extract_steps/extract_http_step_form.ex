defmodule AndiWeb.ExtractSteps.ExtractHttpStepForm do
  @moduledoc """
  LiveComponent for an extract step with type HTTP
  """
  use Phoenix.LiveView
  import Phoenix.HTML
  import Phoenix.HTML.Form
  require Logger

  alias Andi.InputSchemas.Datasets.ExtractHttpStep
  alias AndiWeb.EditLiveView.KeyValueEditor
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.Options
  alias AndiWeb.Views.DisplayNames
  alias Andi.InputSchemas.StructTools
  alias AndiWeb.Views.HttpStatusDescriptions
  alias Andi.InputSchemas.ExtractHttpSteps
  alias AndiWeb.Helpers.FormTools

  def mount(_, %{"extract_step" => extract_step, "dataset_id" => dataset_id, "technical_id" => technical_id}, socket) do
    new_changeset =
      extract_step
      |> Andi.InputSchemas.StructTools.to_map()
      |> ExtractHttpStep.changeset_from_andi_step(technical_id)

    AndiWeb.Endpoint.subscribe("toggle-visibility")
    AndiWeb.Endpoint.subscribe("form-save")

    {:ok,
     assign(socket,
       extract_step_id: extract_step.id,
       changeset: new_changeset,
       testing: false,
       test_results: nil,
       visibility: "expanded",
       validation_status: "collapsed",
       dataset_id: dataset_id,
       technical_id: technical_id
     )}
  end

  def render(assigns) do
    ~L"""
        <div class="form-section extract-step-container extract-http-step-form">
          <%= f = form_for @changeset, "#", [phx_change: :validate, as: :form_data] %>
            <%= hidden_input(f, :id) %>
            <%= hidden_input(f, :type) %>
            <%= hidden_input(f, :technical_id) %>

            <div class="component-edit-section--<%= @visibility %>">
              <div class="extract-step-form-edit-section form-grid">
                <div class="extract-step-form__type">
                  <%= label(f, :type, DisplayNames.get(:type), class: "label") %>
                  <%= select(f, :type, get_extract_step_types(), id: "step_type", class: "extract-step-form__type select") %>
                </div>

                <div class="extract-step-form__method">
                  <%= label(f, :action, DisplayNames.get(:method), class: "label label--required") %>
                  <%= select(f, :action, get_http_methods(), id: "http_method", class: "extract-step-form__method select") %>
                  <%= ErrorHelpers.error_tag(f, :action) %>
                </div>

                <div class="extract-step-form__url">
                  <%= label(f, :url, DisplayNames.get(:url), class: "label label--required") %>
                  <%= text_input(f, :url, class: "input full-width", disabled: @testing) %>
                  <%= ErrorHelpers.error_tag(f, :url, bind_to_input: false) %>
                </div>

                <%= live_component(@socket, KeyValueEditor, id: "key_value_editor_queryParams" <> @extract_step_id, css_label: "source-query-params", form: f, field: :queryParams ) %>

                <%= live_component(@socket, KeyValueEditor, id: "key_value_editor_headers" <> @extract_step_id, css_label: "source-headers", form: f, field: :headers ) %>

                <%= if input_value(f, :action) == "POST" do %>
                  <div class="extract-step-form__body">
                    <%= label(f, :body, DisplayNames.get(:body), class: "label") %>
                    <%= textarea(f, :body, class: "input full-width", disabled: @testing) %>
                    <%= ErrorHelpers.error_tag(f, :body, bind_to_input: false) %>
                  </div>
                <% end %>

                <div class="extract-step-form__test-section">
                  <button type="button" class="extract_step__test-btn btn--test btn btn--large btn--action" phx-click="test_url" <%= disabled?(@testing) %>>Test</button>
                  <%= if @test_results do %>
                    <div class="test-status">
                    Status: <span class="test-status__code <%= status_class(@test_results) %>"><%= @test_results |> Map.get(:status) |> HttpStatusDescriptions.simple() %></span>
                    <%= status_tooltip(@test_results) %>
                    Time: <span class="test-status__time"><%= @test_results |> Map.get(:time) %></span> ms
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </form>
        </div>
    """
  end

  def handle_event("validate", %{"form_data" => form_data, "_target" => ["form_data", "url"]}, socket) do
    form_data
    |> FormTools.adjust_extract_query_params_for_url()
    |> ExtractHttpStep.changeset_from_form_data()
    |> complete_validation(socket)
  end

  def handle_event("validate", %{"form_data" => form_data, "_target" => ["form_data", "queryParams" | _]}, socket) do
    form_data
    |> FormTools.adjust_extract_url_for_query_params()
    |> ExtractHttpStep.changeset_from_form_data()
    |> complete_validation(socket)
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data
    |> AtomicMap.convert(safe: false, underscore: false)
    |> ExtractHttpStep.changeset()
    |> complete_validation(socket)
  end

  def handle_event("validate", _, socket) do
    send(socket.parent_pid, :page_error)

    {:noreply, socket}
  end

  def handle_event("add", %{"field" => "queryParams"}, socket) do
    current_changes =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes()

    ExtractHttpSteps.update(current_changes)

    current_step_id = current_changes.id
    {:ok, _dataset} = ExtractHttpSteps.add_extract_query_param(current_step_id)

    new_changes =
      current_step_id
      |> ExtractHttpSteps.get()
      |> StructTools.to_map()

    changeset = ExtractHttpStep.changeset(%ExtractHttpStep{}, new_changes)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("add", %{"field" => "headers"}, socket) do
    current_changes =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes()

    ExtractHttpSteps.update(current_changes)

    current_step_id = current_changes.id
    {:ok, _dataset} = ExtractHttpSteps.add_extract_header(current_step_id)

    new_changes =
      current_step_id
      |> ExtractHttpSteps.get()
      |> StructTools.to_map()

    changeset = ExtractHttpStep.changeset(%ExtractHttpStep{}, new_changes)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("remove", %{"id" => id, "field" => "queryParams"}, socket) do
    current_step_id = Ecto.Changeset.get_field(socket.assigns.changeset, :id)
    save_draft(socket)

    {:ok, _dataset} = ExtractHttpSteps.remove_extract_query_param(current_step_id, id)

    new_changes =
      current_step_id
      |> ExtractHttpSteps.get()
      |> StructTools.to_map()

    changeset = ExtractHttpStep.changeset(%ExtractHttpStep{}, new_changes)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("remove", %{"id" => id, "field" => "headers"}, socket) do
    current_step_id = Ecto.Changeset.get_field(socket.assigns.changeset, :id)
    save_draft(socket)

    {:ok, _dataset} = ExtractHttpSteps.remove_extract_header(current_step_id, id)

    new_changes =
      current_step_id
      |> ExtractHttpSteps.get()
      |> StructTools.to_map()

    changeset = ExtractHttpStep.changeset(%ExtractHttpStep{}, new_changes)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("test_url", _, socket) do
    changes = Ecto.Changeset.apply_changes(socket.assigns.changeset)
    url = Map.get(changes, :url) |> Andi.URI.clear_query_params()
    query_params = key_values_to_keyword_list(changes, :queryParams)
    headers = key_values_to_keyword_list(changes, :headers)

    Task.async(fn ->
      {:test_results, Andi.Services.UrlTest.test(url, query_params: query_params, headers: headers)}
    end)

    {:noreply, assign(socket, testing: true)}
  end

  def handle_info(
        %{topic: "form-save", event: "save-all", payload: %{dataset_id: dataset_id}},
        %{assigns: %{dataset_id: dataset_id}} = socket
      ) do
    save_draft(socket)
  end

  def handle_info({_, {:test_results, results}}, socket) do
    send(socket.parent_pid, {:test_results, results})
    {:noreply, assign(socket, test_results: results, testing: false)}
  end

  # This handle_info takes care of all exceptions in a generic way.
  # Expected errors should be handled in specific handlers.
  # Flags should be reset here.
  def handle_info({:EXIT, _pid, {_error, _stacktrace}}, socket) do
    send(socket.parent_pid, :page_error)
    {:noreply, assign(socket, page_error: true, testing: false, save_success: false)}
  end

  def handle_info(message, socket) do
    Logger.debug(inspect(message))
    {:noreply, socket}
  end

  defp save_draft(socket) do
    new_validation_status = get_new_validation_status(socket.assigns.changeset)

    socket.assigns.changeset
    |> Andi.InputSchemas.InputConverter.form_changes_from_changeset()
    |> Map.put(:id, socket.assigns.extract_step_id)
    |> Andi.InputSchemas.ExtractHttpSteps.update()

    send(socket.parent_pid, {:validation_status, new_validation_status})

    {:noreply, assign(socket, validation_status: new_validation_status)}
  end

  defp disabled?(true), do: "disabled"
  defp disabled?(_), do: ""

  defp status_class(%{status: status}) when status in 200..399, do: "test-status__code--good"
  defp status_class(%{status: _}), do: "test-status__code--bad"
  defp status_tooltip(%{status: status}) when status in 200..399, do: status_tooltip(%{status: status}, "shown")

  defp status_tooltip(%{status: status}, modifier \\ "shown") do
    assigns = %{
      description: HttpStatusDescriptions.get(status),
      modifier: modifier
    }

    ~E(<sup class="test-status__tooltip-wrapper"><i phx-hook="addTooltip" data-tooltip-content="<%= @description %>" class="material-icons-outlined test-status__tooltip--<%= @modifier %>">info</i></sup>)
  end

  defp key_values_to_keyword_list(form_data, field) do
    form_data
    |> Map.get(field, [])
    |> Enum.map(fn %{key: key, value: value} -> {key, value} end)
  end

  defp get_extract_step_types(), do: map_to_dropdown_options(Options.extract_step_type())
  defp get_http_methods(), do: map_to_dropdown_options(Options.http_method())

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end

  defp update_validation_status(%{assigns: %{validation_status: validation_status, visibility: visibility}} = socket)
       when validation_status in ["valid", "invalid"] or visibility == "collapsed" do
    new_status = get_new_validation_status(socket.assigns.changeset)
    send(socket.parent_pid, {:validation_status, new_status})
    assign(socket, validation_status: new_status)
  end

  defp update_validation_status(%{assigns: %{visibility: visibility}} = socket), do: assign(socket, validation_status: visibility)

  defp get_new_validation_status(changeset) do
    case changeset.valid? do
      true -> "valid"
      false -> "invalid"
    end
  end

  defp complete_validation(changeset, socket) do
    new_changeset = Map.put(changeset, :action, :update)
    send(socket.parent_pid, :form_update)

    {:noreply, assign(socket, changeset: new_changeset) |> update_validation_status()}
  end
end
