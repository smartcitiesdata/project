defmodule DiscoveryApiWeb.VisualizationView do
  use DiscoveryApiWeb, :view

  def accepted_formats() do
    ["json"]
  end

  def render("visualization.json", %{visualization: visualization, allowed_actions: actions}), do: visualization_response(visualization, actions)
  def render("visualization.json", %{visualization: visualization}), do: visualization_response(visualization, nil)

  def render("visualizations.json", %{visualizations: visualizations}) do
    Enum.map(visualizations, &visualization_response(&1, []))
  end

  defp visualization_response(visualization, allowed_actions) do
    %{
      id: visualization.public_id,
      title: visualization.title,
      query: visualization.query,
      chart: safely_decode(visualization.chart),
      created: visualization.inserted_at,
      updated: visualization.updated_at,
      allowed_actions: allowed_actions
    }
  end

  defp safely_decode(nil), do: %{}

  defp safely_decode(chart) do
    case Jason.decode(chart) do
      {:ok, decoded} -> decoded
      _ -> %{}
    end
  end
end
