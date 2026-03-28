defmodule ScalingDoodleWeb.InstancesLive.Index do
  @moduledoc """
  LiveView for managing OpenClaw instances.

  Provides a dashboard for:
  - Listing all instances for the current user
  - Creating new instances
  - Deleting instances
  - Viewing instance details
  """
  use ScalingDoodleWeb, :live_view

  alias ScalingDoodle.Identity.User
  alias ScalingDoodle.Instances
  alias ScalingDoodle.Instances.Instance

  @providers [
    {"Z.AI", "zai"},
    {"Anthropic", "anthropic"},
    {"OpenAI", "openai"}
  ]

  @provider_models %{
    "zai" => [
      {"GLM-5", "glm-5"},
      {"GLM-4.7", "glm-4.7"},
      {"GLM-5-Turbo", "glm-5-turbo"}
    ],
    "anthropic" => [
      {"Claude Opus 4.6", "claude-opus-4-6"},
      {"Claude Sonnet 4.5", "claude-sonnet-4-5"},
      {"Claude Haiku 4.3", "claude-haiku-4-3"}
    ],
    "openai" => [
      {"GPT-4", "gpt-4"},
      {"GPT-4 Turbo", "gpt-4-turbo"},
      {"GPT-3.5 Turbo", "gpt-3.5-turbo"}
    ]
  }

  @default_models %{
    "zai" => "glm-5-turbo",
    "anthropic" => "claude-opus-4-6",
    "openai" => "gpt-4"
  }

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:page_title, "Instances")
      |> assign(:providers, @providers)
      |> assign(:provider_models, @provider_models)
      |> assign(:default_models, @default_models)
      |> assign(:current_provider, "zai")
      |> assign_instances(user)
      |> assign(:form, nil)
      |> assign(:current_scope, %{user: user})

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Instances")
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new, _params) do
    user = socket.assigns.current_user
    default_provider = "zai"
    default_model = Map.get(@default_models, default_provider)

    form =
      AshPhoenix.Form.for_create(Instance, :create,
        params: %{
          "user" => user,
          "model_provider" => default_provider,
          "default_model" => default_model
        },
        actor: user
      )

    socket
    |> assign(:page_title, "New Instance")
    |> assign(:form, form)
    |> assign(:current_provider, default_provider)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    user = socket.assigns.current_user

    case Instances.get_instance(id, actor: user) do
      {:ok, instance} ->
        socket
        |> assign(:page_title, instance.name)
        |> assign(:instance, instance)

      {:error, _error} ->
        socket
        |> put_flash(:error, "Instance not found")
        |> push_navigate(to: ~p"/instances")
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Instances.get_instance(id, actor: user) do
      {:ok, instance} ->
        case Ash.destroy(instance, actor: user) do
          :ok ->
            {:noreply,
             socket
             |> put_flash(:info, "Instance deleted successfully")
             |> assign_instances(user)}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Failed to delete instance")}
        end

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Instance not found")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"instance" => params} = _event, socket) do
    form =
      AshPhoenix.Form.update_params(socket.assigns.form, fn existing_params ->
        Map.merge(existing_params, params)
      end)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("validate", %{"form" => params} = _event, socket) do
    form =
      AshPhoenix.Form.update_params(socket.assigns.form, fn existing_params ->
        Map.merge(existing_params, params)
      end)

    {:noreply, assign(socket, :form, form)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"instance" => params} = _event, socket) do
    user = socket.assigns.current_user

    params =
      params
      |> Map.put("user", user)
      |> Map.put_new("default_model", @default_models[params["model_provider"]] || "glm-5-turbo")

    form =
      AshPhoenix.Form.for_create(Instance, :create,
        params: params,
        actor: user
      )

    case AshPhoenix.Form.submit(form) do
      {:ok, _instance} ->
        {:noreply,
         socket
         |> put_flash(:info, "Instance created successfully")
         |> push_navigate(to: ~p"/instances")
         |> assign_instances(user)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("save", %{"form" => params} = _event, socket) do
    user = socket.assigns.current_user

    params =
      params
      |> Map.put("user", user)
      |> Map.put_new("default_model", @default_models[params["model_provider"]] || "glm-5-turbo")

    form =
      AshPhoenix.Form.for_create(Instance, :create,
        params: params,
        actor: user
      )

    case AshPhoenix.Form.submit(form) do
      {:ok, _instance} ->
        {:noreply,
         socket
         |> put_flash(:info, "Instance created successfully")
         |> push_navigate(to: ~p"/instances")
         |> assign_instances(user)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("provider_changed", %{"model_provider" => provider} = _event, socket) do
    default_model = Map.get(@default_models, provider, "")

    form =
      AshPhoenix.Form.update_params(socket.assigns.form, fn params ->
        params
        |> Map.put("model_provider", provider)
        |> Map.put("default_model", default_model)
      end)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:current_provider, provider)}
  end

  def handle_event("provider_changed", %{"form" => %{"model_provider" => provider}} = _event, socket) do
    default_model = Map.get(@default_models, provider, "")

    form =
      AshPhoenix.Form.update_params(socket.assigns.form, fn params ->
        params
        |> Map.put("model_provider", provider)
        |> Map.put("default_model", default_model)
      end)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:current_provider, provider)}
  end

  @impl Phoenix.LiveView
  def handle_event("copy_token", %{"token" => _token}, socket) do
    {:noreply, put_flash(socket, :info, "Gateway token copied to clipboard!")}
  end

  defp assign_instances(socket, %User{} = user) do
    case Instances.list_instances_for_user(user.id, actor: user) do
      {:ok, instances} -> assign(socket, :instances, instances)
      _error -> assign(socket, :instances, [])
    end
  end

  defp status_badge_class("pending"), do: "badge-warning"
  defp status_badge_class("provisioning"), do: "badge-info"
  defp status_badge_class("running"), do: "badge-success"
  defp status_badge_class("error"), do: "badge-error"
  defp status_badge_class(_status), do: "badge-ghost"
end
