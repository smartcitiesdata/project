defmodule AndiWeb.OrganizationLiveView do
  use Phoenix.LiveView
  import Ecto.Query, only: [from: 2]

  alias AndiWeb.Router.Helpers, as: Routes
  alias AndiWeb.OrganizationLiveView.Table
  alias Andi.InputSchemas.Organization

  def render(assigns) do
    ~L"""
    <div class="organizations-view">
      <div class="page-header">
        <a href="/datasets">Dataset Ingestion Interface</a>
        </div>

      <div class="organizations-index">
        <div class="organizations-index__header">
          <h1 class="organizations-index__title">All Organizations</h1>
        </div>

        <div class="organizations-index__search">
          <form phx-change="search" phx-submit="search">
            <div class="organizations-index__search-input-container">
              <label for="organizations-index__search-input">
                <i class="material-icons organizations-index__search-icon">search</i>
              </label>
              <input
                name="search-value"
                phx-debounce="250"
                id="organizations-index__search-input"
                class="organizations-index__search-input"
                type="text"
                value="<%= @search_text %>"
                placeholder="Search Organizations"
              >
            </div>
          </form>
        </div>

        <%= live_component(@socket, Table, id: :organizations_table, organizations: @organizations, order: @order) %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       organizations: nil,
       search_text: nil,
       order: {"org_title", "asc"},
       params: %{}
     )}
  end

  def handle_params(params, _uri, socket) do
    order_by = Map.get(params, "order-by", "org_title")
    order_dir = Map.get(params, "order-dir", "asc")
    search_text = Map.get(params, "search", "")

    view_models =
      filter_on_search_change(search_text, socket)
      |> sort_by_dir(order_by, order_dir)

    {:noreply,
     assign(socket,
       search_text: search_text,
       organizations: view_models,
       order: %{order_by => order_dir},
       params: params
     )}
  end

  def handle_event("search", %{"search-value" => value}, socket) do
    search_params = Map.merge(socket.assigns.params, %{"search" => value})
    {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, search_params))}
  end

  def handle_event("order-by", %{"field" => field}, socket) do
    order_dir =
      case socket.assigns.order do
        %{^field => "asc"} -> "desc"
        _ -> "asc"
      end

    params = Map.merge(socket.assigns.params, %{"order-by" => field, "order-dir" => order_dir})
    {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, params))}
  end

  defp filter_on_search_change(search_value, socket) do
    case search_value == socket.assigns.search_text do
      false -> refresh_orgs(search_value)
      _ -> socket.assigns.organizations
    end
  end

  defp refresh_orgs(search_value) do
    search_string = "%#{search_value}%"

    query =
      from(org in Organization,
        where: ilike(org.orgTitle, type(^search_string, :string)),
        select: org
      )

    Andi.Repo.all(query)
    |> Enum.map(&to_view_model/1)
  end

  defp sort_by_dir(models, order_by, order_dir) do
    case order_dir do
      "asc" -> Enum.sort_by(models, fn model -> Map.get(model, order_by) end)
      "desc" -> Enum.sort_by(models, fn model -> Map.get(model, order_by) end, &>=/2)
      _ -> models
    end
  end

  defp to_view_model(org) do
    %{
      "org_title" => org.orgTitle,
      "id" => org.id
    }
  end
end
