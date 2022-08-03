defmodule AndiWeb.HeaderLiveView do
  @moduledoc """
  LiveView for the header bar
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <header class="page-header">
      <span class="page-header__primary" phx-click="show-datasets">
        <img id="header-logo" src="/images/UrbanOS.svg"></img>
        <span><%= header_text(@is_curator) %></span>
        <span class="log-out-link" phx-click="log-out">
          <span class="material-icons">person</span>
          <span class="log-out-link__text">Log Out</span>
        </span>
      </span>
      <span class="page-header__secondary">
        <%= if @is_curator do %>
          <span class="link" phx-click="show-datasets">
            <span class="material-icons">storage</span>
            <span>Datasets</span>
          </span>
          <span class="link" phx-click="show-ingestions">
            <span class="material-icons">input</span>
            <span>Ingestions</span>
          </span>
          <span class="link" phx-click="show-organizations">
            <span class="material-icons">settings</span>
            <span>Organizations</span>
          </span>
          <span class="link" phx-click="show-access-groups">
            <span class="material-icons">lock</span>
            <span>Access Groups</span>
          </span>
          <span class="link" phx-click="show-users">
            <span class="material-icons">people</span>
            <span>Users</span>
          </span>
        <% end %>
      </span>
    </header>
    """
  end

  defmacro __using__(_opts \\ []) do
    quote do
      import AndiWeb.HeaderLiveView

      def handle_event("show-datasets", _, socket) do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_datasets_path())
      end

      def handle_event("show-organizations", _, socket) do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_organizations_path())
      end

      def handle_event("show-users", _, socket) do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_users_path())
      end

      def handle_event("show-access-groups", _, socket) do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_access_groups_path())
      end

      def handle_event("show-ingestions", _, socket) do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_ingestions_path())
      end

      def handle_event("log-out", _, socket) do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_log_out_path())
      end
    end
  end

  defmacro header_datasets_path() do
    "/datasets"
  end

  defmacro header_organizations_path() do
    "/organizations"
  end

  defmacro header_users_path() do
    "/users"
  end

  defmacro header_access_groups_path() do
    "/access-groups"
  end

  defmacro header_ingestions_path() do
    "/ingestions"
  end

  defmacro header_log_out_path() do
    "/auth/auth0/logout"
  end

  def header_render(is_curator) do
    live_component(AndiWeb.HeaderLiveView, is_curator: is_curator)
  end

  def __redirect__(%{assigns: %{unsaved_changes: true}} = socket, location) do
    {:noreply, assign(socket, unsaved_changes_link: location, unsaved_changes_modal_visibility: "visible")}
  end

  def __redirect__(socket, location) do
    {:noreply, redirect(socket, to: location)}
  end

  defp header_text(true = _is_curator), do: "Data Management Tool"
  defp header_text(false = _is_curator), do: "Data Submission Tool"
end
