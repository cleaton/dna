defmodule PhoenixIotWeb.IotLive do
  use Phoenix.LiveView
  alias PhoenixIot.Actors.City.API, as: City
  alias Phoenix.LiveView.JS
  alias PhoenixIot.Actors.City.Attraction

  @cities [
    "Paris, France",
    "London, United Kingdom",
    "Rome, Italy",
    "New York City, USA",
    "Barcelona, Spain",
    "Tokyo, Japan",
    "Amsterdam, Netherlands",
    "Sydney, Australia",
    "Istanbul, Turkey",
    "Rio de Janeiro, Brazil"
  ]

  @max_attractions 10

  def mount(params, _session, socket) do
    city = Map.get(params, "city", "")

    if not city in @cities do
      city = Enum.at(@cities, 0)
      {:ok, redirect(socket, to: "/city/#{city}")}
    else
      City.subscribe_attractions(city)
      attractions = City.list_attractions(city)

      socket =
        socket
        |> stream(:attractions, attractions)
        |> assign(:count, length(attractions))
        |> assign(:city, city)
        |> assign(:to_edit, nil)
        |> assign(:error, nil)

      {:ok, socket, temporary_assigns: [error: nil]}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 flex items-center justify-center">
    <div class="w-full max-w-md">
      <div class="bg-white shadow-md rounded p-8">
        <div class="relative mb-6">
        <form phx-submit="select_city">
        <input list="cities" type="text" name="city" placeholder="Select City" class="form-input w-full" value={@city}>
        <datalist id="cities">
          <%= for city <- cities() do %>
            <option value={city}></option>
          <% end %>
        </datalist>
        <button class="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded">Select</button>
        </form>
        </div>

        <div class="mb-6">
        <%= if @count < max_attractions() do %>
          <button class="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded" phx-click="new_attraction">Add Attraction</button>
        <% else %>
        <div class="inline-block relative group cursor-not-allowed">
        <button class="bg-gray-500 text-white font-bold py-2 px-4 rounded" disabled>
          Add Attraction
        </button>
        <span class="absolute -bottom-8 left-1/2 transform -translate-x-1/2 bg-gray-200 text-gray-700 p-1 rounded whitespace-nowrap opacity-0 group-hover:opacity-100" style="font-size: 0.7rem;">Max attractions reached</span>
      </div>
        <% end %>
      </div>


        <%= if @to_edit != nil do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-10">
        <div class="bg-gray-200 p-4 rounded-lg shadow-lg">
          <form phx-submit="save_attraction" class="space-y-4">
            <div>
              <label for="name" class="block">Name</label>
              <input value={@to_edit.name} type="text" name="name" class="form-input w-full" />
            </div>
            <div>
              <label for="cap" class="block">Cap</label>
              <input value={@to_edit.cap} type="text" name="cap" class="form-input w-full" />
            </div>
            <div>
              <label for="current" class="block">Current</label>
              <input value={@to_edit.current} type="text" name="current" class="form-input w-full" />
            </div>
            <input value={@to_edit.id} type="hidden" name="id" />
            <div class="flex justify-end">
            <button type="button" class="bg-red-500 hover:bg-red-600 text-white font-bold py-2 px-4 rounded mr-2" phx-click="cancel_edit">Cancel</button>
            <button class="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded" phx-disable-with="Saving...">Save</button>
          </div>
          </form>
          </div>
          </div>
        <% end %>
      </div>

      <div id="attractions" phx-update="stream" class="mt-8 space-y-4">
        <div :for={{id, attraction} <- @streams.attractions} id={id} class="bg-white shadow-md rounded p-4">
          <%= attraction.id %>
          <%= attraction.name %>
          <%= attraction.cap %>
          <%= attraction.current %>
          <button id={"edit" <> attraction.id} class="bg-blue-500 text-white px-4 py-2 rounded ml-4" phx-disable-with="Loading..." phx-click="to_edit" phx-value-id={attraction.id} phx-value-name={attraction.name} phx-value-cap={attraction.cap} phx-value-current={attraction.current}>Edit</button>
          <button id={"delete" <> attraction.id} phx-disable-with="Deleting..." phx-click="delete_attraction" phx-value-id={attraction.id} class="bg-red-500 hover:bg-red-600 text-white font-bold py-2 px-4 rounded">Delete</button>
        </div>
      </div>
    </div>
    <%= if @error do %>
    <div id={@error.id} class="fixed top-0 left-0 w-full p-4 bg-red-100 text-red-500 text-sm z-50"
    phx-click-away={JS.hide(transition: "fade-out-scale")}
    phx-window-keydown={JS.hide(transition: "fade-out-scale")}
    phx-mounted={JS.show(transition: "fade-in-scale")}
    >
    <%= @error.msg %>
    </div>
    <% end %>
    </div>
    """
  end

  def handle_info({{:put_attraction, attraction}, count}, socket) do
    socket =
      socket
      |> stream_insert(:attractions, attraction)
      |> assign(:count, count)

    {:noreply, socket}
  end

  def handle_info({{:delete_attraction, id}, count}, socket) do
    attraction = Attraction.new(id, "", 0, 0)

    socket =
      socket
      |> stream_delete(:attractions, attraction)
      |> assign(:count, count)

    {:noreply, socket}
  end

  def handle_info({:error, msg}, socket) do
    {:noreply, uierror(socket, msg)}
  end

  def handle_event("delete_attraction", %{"id" => id}, socket) do
    with :ok <- City.delete_attraction(socket.assigns.city, id) do
      {:noreply, socket}
    else
      _ -> {:noreply, uierror(socket, "Failed to delete attraction")}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, to_edit: nil)}
  end

  def handle_event("new_attraction", _, socket) do
    {:noreply, assign(socket, to_edit: Attraction.new("", 1000, 0))}
  end

  def handle_event("select_city", %{"city" => city}, socket) do
    cond do
      city in @cities ->
        # Process the selected city, e.g., filtering attractions or other actions
        {:noreply, redirect(socket, to: "/city/#{city}")}

      true ->
        # If the city is not in the list, don't update the assign and show an error message
        {:noreply, uierror(socket, "Please select a valid city from the list")}
    end
  end

  def handle_event(
        "to_edit",
        %{"id" => id, "name" => name, "cap" => cap, "current" => current},
        socket
      ) do
    attraction = Attraction.new(id, name, cap, current)

    socket =
      socket
      # show edit form
      |> assign(:to_edit, attraction)
      # Force rerender to make the edit button work...
      |> stream_insert(:attractions, attraction)

    {:noreply, socket}
  end

  def handle_event(
        "save_attraction",
        %{"id" => id, "name" => name, "cap" => cap, "current" => current},
        socket
      ) do
    cap = String.to_integer(cap)
    current = String.to_integer(current)
    attraction = Attraction.new(id, name, cap, current)

    with :ok <-
           Attraction.validate(attraction),
         :ok <- City.put_attraction(socket.assigns.city, attraction) do
      # Update the socket's assigns to reflect the updated attraction

      socket =
        socket
        |> assign(:to_edit, nil)

      {:noreply, socket}
    else
      {:error, msg} ->
        {:noreply, socket |> uierror(msg)}
    end
  end

  defp cities(), do: @cities
  defp max_attractions(), do: @max_attractions

  defp uierror(socket, msg),
    do: assign(socket, :error, %{id: to_string(System.unique_integer()), msg: msg})

  defp js_exec(socket, attr, to), do: push_event(socket, "js-exec", %{to: to, attr: attr})
end
