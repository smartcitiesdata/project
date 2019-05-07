defmodule DiscoveryApiWeb.DataJsonView do
  use DiscoveryApiWeb, :view
  alias DiscoveryApi.Data.Model

  def render("get_data_json.json", %{models: models, base_url: base_url}) do
    translate_to_open_data_schema(models, base_url)
  end

  defp translate_to_open_data_schema(models, base_url) do
    %{
      conformsTo: "https://project-open-data.cio.gov/v1.1/schema",
      "@context": "https://project-open-data.cio.gov/v1.1/schema/catalog.jsonld",
      dataset: Enum.map(models, &translate_to_dataset(&1, base_url))
    }
  end

  defp translate_to_dataset(%Model{} = model, base_url) do
    %{
      "@type" => "dcat:Dataset",
      "identifier" => model.id,
      "title" => model.title,
      "description" => model.description,
      "keyword" => val_or_optional(model.keywords),
      "modified" => model.modifiedDate,
      "publisher" => %{
        "@type" => "org:Organization",
        "name" => model.organization
      },
      "contactPoint" => %{
        "@type" => "vcard:Contact",
        "fn" => model.contactName,
        "hasEmail" => "mailto:" <> model.contactEmail
      },
      "accessLevel" => model.accessLevel,
      "license" => val_or_optional(model.license),
      "rights" => val_or_optional(model.rights),
      "spatial" => val_or_optional(model.spatial),
      "temporal" => val_or_optional(model.temporal),
      "distribution" => [
        %{
          "@type" => "dcat:Distribution",
          "accessURL" => "#{base_url}/api/v1/dataset/#{model.id}/download?_format=json",
          "mediaType" => "application/json"
        },
        %{
          "@type" => "dcat:Distribution",
          "accessURL" => "#{base_url}/api/v1/dataset/#{model.id}/download?_format=csv",
          "mediaType" => "text/csv"
        }
      ],
      "accrualPeriodicity" => val_or_optional(model.publishFrequency),
      "conformsTo" => val_or_optional(model.conformsToUri),
      "describedBy" => val_or_optional(model.describedByUrl),
      "describedByType" => val_or_optional(model.describedByMimeType),
      "isPartOf" => val_or_optional(model.parentDataset),
      "issued" => val_or_optional(model.issuedDate),
      "language" => val_or_optional(model.language),
      "landingPage" => val_or_optional(model.homepage),
      "references" => val_or_optional(model.referenceUrls),
      "theme" => val_or_optional(model.categories)
    }
    |> remove_optional_values()
  end

  defp remove_optional_values(map) do
    map
    |> Enum.filter(fn {_key, value} ->
      value != :optional
    end)
    |> Enum.into(Map.new())
  end

  defp val_or_optional(nil), do: :optional
  defp val_or_optional(val), do: val
end
