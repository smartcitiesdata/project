defmodule AndiWeb.IngestionLiveView.EditIngestionLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView
  require Logger

  @instance_name Andi.instance_name()

  import SmartCity.Event, only: [ingestion_delete: 0]

  alias Andi.InputSchemas.Ingestions
  alias Andi.Services.IngestionStore
  alias Andi.Services.IngestionDelete
  alias Andi.InputSchemas.InputConverter

  access_levels(render: [:private])

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="edit-page" id="ingestions-edit-page">
      <div class="edit-ingestion-title">
        <h2 class="component-title-text">Define Data Ingestion</h2>
      </div>

      <div class="extract-steps-form-component">
        <%= live_render(@socket, AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepForm, id: :extract_step_form_editor, session: %{"ingestion" => @ingestion}) %>
      </div>

      <div class="edit-page__btn-group">
        <div class="btn-group__standard">
          <button type="button" class="btn btn--large btn--cancel" phx-click="cancel-edit">Cancel</button>
          <button id="save-button" name="save-button" class="btn btn--save btn--large" type="button" phx-click="save">Save Draft</button>
        </div>

        <hr></hr>

        <button id="ingestion-delete-button" class="btn btn--delete" phx-click="prompt-ingestion-delete" type="button">
          <span class="delete-icon material-icons">delete_outline</span>
            DELETE
        </button>

      </div>

      <%= live_component(@socket, AndiWeb.EditLiveView.UnsavedChangesModal, visibility: @unsaved_changes_modal_visibility) %>

      <%= live_component(@socket, AndiWeb.IngestionLiveView.DeleteIngestionModal, visibility: @delete_ingestion_modal_visibility) %>
    </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator, "ingestion" => ingestion, "user_id" => user_id} = _session, socket) do
    default_changeset = InputConverter.andi_ingestion_to_full_ui_changeset(ingestion)

    {:ok,
     assign(socket,
       changeset: default_changeset,
       click_id: nil,
       delete_ingestion_modal_visibility: "hidden",
       unsaved_changes_modal_visibility: "hidden",
       is_curator: is_curator,
       unsaved_changes: false,
       ingestion: ingestion,
       save_success: false,
       success_message: "",
       user_id: user_id
     )}
  end

  def handle_info(:form_update, socket) do
    {:noreply, assign(socket, unsaved_changes: true)}
  end

  def handle_info({:update_save_message, status}, socket) do
    message = save_message(status == "valid" && socket.assigns.changeset.valid?)

    {:noreply, assign(socket, click_id: UUID.uuid4(), save_success: true, success_message: message)}
  end

  def handle_event("prompt-ingestion-delete", _, socket) do
    {:noreply, assign(socket, delete_ingestion_modal_visibility: "visible")}
  end

  def handle_event("delete-confirmed", _, socket) do
    ingestion_id = socket.assigns.ingestion.id
    user_id = socket.assigns.user_id

    case IngestionStore.get(ingestion_id) do
      {:ok, nil} ->
        Ingestions.delete(ingestion_id)

      {:ok, smrt_ingestion} ->
        IngestionDelete.delete(smrt_ingestion.id, user_id)
    end

    {:noreply, redirect(socket, to: header_ingestions_path())}
  end

  def handle_event("delete-canceled", _, socket) do
    {:noreply, assign(socket, delete_ingestion_modal_visibility: "hidden")}
  end

  def handle_event("save", _, socket) do
    ingestion_id = socket.assigns.ingestion.id
    AndiWeb.Endpoint.broadcast_from(self(), "form-save", "save-all", %{ingestion_id: ingestion_id})

    andi_ingestion = Ingestions.get(ingestion_id)
    ingestion_changeset = InputConverter.andi_ingestion_to_full_ui_changeset(andi_ingestion)

    {:noreply,
     assign(socket,
       changeset: ingestion_changeset,
       save_success: true,
       click_id: UUID.uuid4(),
       success_message: save_message(ingestion_changeset.valid?)
     )}
  end

  def handle_event("cancel-edit", _, socket) do
    case socket.assigns.unsaved_changes do
      true -> {:noreply, assign(socket, unsaved_changes_link: header_ingestions_path(), unsaved_changes_modal_visibility: "visible")}
      false -> {:noreply, redirect(socket, to: header_ingestions_path())}
    end
  end

  def handle_event("unsaved-changes-canceled", _, socket) do
    {:noreply, assign(socket, unsaved_changes_modal_visibility: "hidden")}
  end

  def handle_event("force-cancel-edit", _, socket) do
    {:noreply, redirect(socket, to: socket.assigns.unsaved_changes_link)}
  end

  defp save_message(true = _valid?), do: "Saved successfully."
  defp save_message(false = _valid?), do: "Saved successfully. You may need to fix errors before publishing."
end
