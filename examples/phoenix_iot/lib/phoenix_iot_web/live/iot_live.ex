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

    if city not in @cities do
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
    <div class="min-h-screen bg-indigo-100 flex items-center justify-center">
    <div class="w-full max-w-md p-6 bg-white shadow-md rounded">
      <div class="text-center mb-8">
        <h1 class="text-4xl font-bold text-indigo-800">Popular Attractions</h1>
        <%= if @city != "" do %>
          <h2 class="text-2xl text-indigo-600">in <%= @city %></h2>
        <% end %>
        <p class="text-gray-600">Real-time visitor insights</p>
      </div>
      <div class="bg-white shadow-md rounded p-8">
        <div class="mb-6">
          <form phx-change="select_city">
            <label for="city" class="block text-sm font-medium text-indigo-600">Select City</label>
            <select name="city" class="form-select block w-full mt-1 text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" value={@city}>
              <option value="">Choose a city</option>
              <%= for city <- cities() do %>
                <option value={city}><%= city %></option>
              <% end %>
            </select>
          </form>
        </div>

    <div class="mb-6">
      <%= if @count < max_attractions() do %>
        <button class="bg-indigo-500 hover:bg-indigo-600 text-white font-bold py-2 px-4 rounded transition duration-150 ease-in-out" phx-click="new_attraction">Add Attraction</button>
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
      <div class="bg-indigo-100 p-6 rounded-lg shadow-lg w-full max-w-md">
        <h2 class="text-2xl font-bold mb-6 text-center">Add or Edit Attraction</h2>
        <form phx-submit="save_attraction" class="space-y-6">
          <div>
            <label for="name" class="block text-indigo-800">Name</label>
            <input value={@to_edit.name} type="text" name="name" class="form-input w-full rounded border border-indigo-300" />
          </div>
          <div>
            <label for="current" class="block text-indigo-800">Current</label>
            <input value={@to_edit.current} type="text" name="current" class="form-input w-full rounded border border-indigo-300" />
          </div>
          <div>
            <label for="cap" class="block text-indigo-800">Cap</label>
            <input value={@to_edit.cap} type="text" name="cap" class="form-input w-full rounded border border-indigo-300" />
          </div>
          <input value={@to_edit.id} type="hidden" name="id" />
          <div class="flex justify-end">
            <button type="button" class="bg-indigo-500 hover:bg-indigo-600 text-white font-bold py-2 px-4 rounded mr-2" phx-click="cancel_edit">Cancel</button>
            <button class="bg-indigo-700 hover:bg-indigo-800 text-white font-bold py-2 px-4 rounded" phx-disable-with="Saving...">Save</button>
          </div>
        </form>
      </div>
    </div>
    <% end %>
      </div>
      <div id="attractions" phx-update="stream" class="mt-8 space-y-6">
        <div :for={{id, attraction} <- @streams.attractions} id={id} class="bg-white shadow-md rounded p-6 hover:bg-indigo-50 transition duration-150 ease-in-out">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-2xl font-semibold"><%= attraction.name %></h3>
          <div>
            <button id={"edit" <> attraction.id} class="bg-indigo-500 hover:bg-indigo-600 text-white px-4 py-2 rounded ml-4 transition duration-150 ease-in-out" phx-disable-with="Loading..." phx-click="to_edit" phx-value-id={attraction.id} phx-value-name={attraction.name} phx-value-cap={attraction.cap} phx-value-current={attraction.current}>Edit</button>
            <button id={"delete" <> attraction.id} phx-disable-with="Deleting..." phx-click="delete_attraction" phx-value-id={attraction.id} class="bg-pink-500 hover:bg-pink-600 text-white font-bold py-2 px-4 rounded transition duration-150 ease-in-out">Delete</button>
          </div>
        </div>
        <div class="w-full h-6 rounded-lg bg-gray-200 overflow-hidden">
          <div id={"hook" <> attraction.id} class={"h-full flex items-center justify-center text-sm font-semibold " <> crowd_bg_class(attraction)} phx-hook="ProgressBar">
            <%= crowd_percentage(attraction) %>%</div>
        </div>
        <div class="flex justify-between mt-4 text-sm font-medium">
          <div>Current: <%= attraction.current %></div>
          <div>Cap: <%= attraction.cap %></div>
        </div>
      </div>
      </div>
    </div>
    <%= if @error do %>
    <div id={@error.id} class="fixed top-0 left-0 w-full p-6 bg-red-200 text-red-700 text-sm z-50 rounded-lg shadow-md transition-all duration-300"
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
    prep =
      try do
        cap = String.to_integer(cap)
        current = String.to_integer(current)
        {:ok, cap, current}
      rescue
        _ -> {:error, "Value not an integer"}
      end

    with {:ok, cap, current} <- prep,
         attraction <- Attraction.new(id, name, cap, current),
         :ok <-
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

  def crowd_percentage(%{current: current, cap: cap}) do
    current = if is_binary(current), do: String.to_integer(current), else: current
    cap = if is_binary(cap), do: String.to_integer(cap), else: cap

    percent =
      cond do
        cap == 0 -> 100
        current == 0 -> 0
        true -> current / (cap * 1.0) * 100
      end

    round(percent)
  end

  def crowd_bg_class(attraction) do
    percent = crowd_percentage(attraction)

    case percent do
      x when x < 40 -> "bg-green-300"
      x when x < 70 -> "bg-yellow-300"
      x -> "bg-red-300"
    end
  end

  defp cities(), do: @cities
  defp max_attractions(), do: @max_attractions

  defp uierror(socket, msg),
    do: assign(socket, :error, %{id: to_string(System.unique_integer()), msg: msg})

  defp js_exec(socket, attr, to), do: push_event(socket, "js-exec", %{to: to, attr: attr})
end
