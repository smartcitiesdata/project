defmodule AndiWeb.EditController do
  use AndiWeb, :controller
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Organizations

  def show_dataset(conn, %{"id" => id}) do
    %{"user_id" => user_id, "is_curator" => is_curator} = AndiWeb.Auth.TokenHandler.Plug.current_resource(conn)

    case get_dataset_if_accessible(id, is_curator, user_id) do
      nil ->
        conn
        |> put_view(AndiWeb.ErrorView)
        |> put_status(404)
        |> render("404.html")

      dataset ->
        if is_curator do
          live_render(conn, AndiWeb.EditLiveView, session: %{"dataset" => dataset, "user_id" => user_id, "is_curator" => is_curator})
        else
          live_render(conn, AndiWeb.SubmitLiveView, session: %{"dataset" => dataset, "user_id" => user_id, "is_curator" => is_curator})
        end
    end
  end

  defp get_dataset_if_accessible(_id, _is_curator, nil), do: nil

  defp get_dataset_if_accessible(id, true, _user_id) do
    Datasets.get(id)
  end

  defp get_dataset_if_accessible(id, false, current_user_id) do
    case Datasets.get(id) do
      nil -> nil
      %{user_id: user_id} = dataset when user_id == current_user_id -> dataset
      _dataset -> nil
    end
  end

  def show_organization(conn, %{"id" => id}) do
    case Organizations.get(id) do
      nil ->
        conn
        |> put_view(AndiWeb.ErrorView)
        |> put_status(404)
        |> render("404.html")

      org ->
        live_render(conn, AndiWeb.EditOrganizationLiveView, session: %{"organization" => org})
    end
  end
end
