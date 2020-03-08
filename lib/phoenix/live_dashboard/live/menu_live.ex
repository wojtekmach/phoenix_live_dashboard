defmodule Phoenix.LiveDashboard.MenuLive do
  use Phoenix.LiveDashboard.Web, :live_view

  @default_refresh 5
  @supported_refresh [{"1s", 1}, {"2s", 2}, {"5s", 5}, {"15s", 15}, {"30s", 30}]

  @impl true
  def mount(_, %{"menu" => menu}, socket) do
    socket = assign(socket, menu: menu, node: menu.node, refresh: @default_refresh)
    socket = validate_nodes_or_redirect(socket)

    if connected?(socket) do
      :net_kernel.monitor_nodes(true, node_type: :all)
    end

    {:ok, init_schedule_refresh(socket)}
  end

  @impl true
  def render(assigns) do
    ~L"""
    <%= maybe_active_live_redirect @socket, "Home", :home, @node %> |
    <%= maybe_enabled_live_redirect @socket, "Metrics", :metrics, @node %> |
    <%= maybe_enabled_live_redirect @socket, "Request Logger", :request_logger, @node %>

    <%= for {_route, _live_view, action, title} <- Application.get_env(:phoenix_live_dashboard, :components, []) do %>
      <%= maybe_active_live_redirect @socket, title, action, @node %>
    <% end %>

    --

    <form phx-change="select_node" style="display:inline">
      Node: <%= select :node_selector, :node, @nodes, value: @node %> |
    </form>

    <%= if @menu.refresher? do %>
      <form phx-change="select_refresh" style="display:inline">
        Update every: <%= select :refresh_selector, :refresh, refresh_options(), value: @refresh %>
      </form>
    <% else %>
      Updates automatically
    <% end %>
    """
  end

  defp refresh_options() do
    @supported_refresh
  end

  defp maybe_active_live_redirect(socket, text, action, node) do
    if socket.assigns.menu.action == action do
      text
    else
      live_redirect(text, to: live_dashboard_path(socket, action, node))
    end
  end

  defp maybe_enabled_live_redirect(socket, text, action, node) do
    if socket.assigns.menu[action] do
      maybe_active_live_redirect(socket, text, action, node)
    else
      ~E"""
      <%= text %> (<%= link "enable", to: guide(action) %>)
      """
    end
  end

  defp guide(name), do: "https://hexdocs.pm/phoenix_live_dashboard/#{name}.html"

  @impl true
  def handle_info({:nodeup, _, _}, socket) do
    {:noreply, assign(socket, nodes: nodes())}
  end

  def handle_info({:nodedown, _, _}, socket) do
    {:noreply, validate_nodes_or_redirect(socket)}
  end

  def handle_info(:refresh, socket) do
    send(socket.root_pid, :refresh)
    {:noreply, schedule_refresh(socket)}
  end

  @impl true
  def handle_event("select_node", params, socket) do
    param_node = params["node_selector"]["node"]

    if node = Enum.find(nodes(), &(Atom.to_string(&1) == param_node)) do
      send(socket.root_pid, {:node_redirect, node})
      {:noreply, socket}
    else
      {:noreply, redirect_to_current_node(socket)}
    end
  end

  def handle_event("select_refresh", params, socket) do
    case Integer.parse(params["refresh_selector"]["refresh"]) do
      {refresh, ""} -> {:noreply, assign(socket, refresh: refresh)}
      _ -> {:noreply, socket}
    end
  end

  ## Refresh helpers

  defp init_schedule_refresh(socket) do
    if connected?(socket) and socket.assigns.menu.refresher? do
      schedule_refresh(socket)
    else
      assign(socket, timer: nil)
    end
  end

  defp schedule_refresh(socket) do
    assign(socket, timer: Process.send_after(self(), :refresh, socket.assigns.refresh * 1000))
  end

  ## Node helpers

  defp nodes(), do: [node() | Node.list()]

  defp validate_nodes_or_redirect(socket) do
    if socket.assigns.node not in nodes() do
      socket
      |> put_flash(:error, "Node #{socket.assigns.node} disconnected.")
      |> redirect_to_current_node()
    else
      assign(socket, nodes: nodes())
    end
  end

  defp redirect_to_current_node(socket) do
    push_redirect(socket, to: live_dashboard_path(socket, :home, node()))
  end
end
