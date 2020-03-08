defmodule Phoenix.LiveDashboard.Router do
  @moduledoc """
  Provides LiveView routing for LiveDashboard.
  """

  @doc """
  Defines a LiveDashboard route.

  It expects the `path` the dashboard will be mounted at
  and a set of options.

  ## Options

    * `:metrics` - Configures the module to retrieve metrics from.
      It can be a `module` or a `{module, function}`. If nothing is
      given, the metrics functionality will be disabled.

  ## Examples

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        import Phoenix.LiveDashboard.Router

        scope "/", MyAppWeb do
          pipe_through [:browser]
          live_dashboard "/dashboard", metrics: {MyAppWeb.Telemetry, :metrics}
        end
      end

  """
  defmacro live_dashboard(path, opts \\ []) do
    quote bind_quoted: binding() do
      scope path do
        import Phoenix.LiveView.Router, only: [live: 4]

        opts = Phoenix.LiveDashboard.Router.__options__(opts)
        live "/", Phoenix.LiveDashboard.HomeLive, :home, opts
        live "/:node", Phoenix.LiveDashboard.HomeLive, :home, opts
        live "/:node/metrics", Phoenix.LiveDashboard.MetricsLive, :metrics, opts
        live "/:node/metrics/:group", Phoenix.LiveDashboard.MetricsLive, :metrics, opts
        live "/:node/request_logger", Phoenix.LiveDashboard.LoggerLive, :request_logger, opts
        live "/:node/request_logger/:stream", Phoenix.LiveDashboard.LoggerLive, :request_logger, opts

        for {route, live_view, action, _title} <- Application.get_env(:phoenix_live_dashboard, :components, []) do
          live route, live_view, action, opts
        end
      end
    end
  end

  @doc false
  def __options__(options) do
    metrics =
      case options[:metrics] do
        nil ->
          nil

        mod when is_atom(mod) ->
          {mod, :metrics}

        {mod, fun} when is_atom(mod) and is_atom(fun) ->
          {mod, fun}

        other ->
          raise ":metrics must be a tuple with {Mod, fun}, " <>
                  "such as {MyAppWeb.Telemetry, :metrics}, got: #{inspect(other)}"
      end

    [
      session: {__MODULE__, :__session__, [metrics]},
      layout: {Phoenix.LiveDashboard.LayoutView, :dash},
      as: :live_dashboard
    ]
  end

  @doc false
  def __session__(conn, metrics) do
    %{
      "metrics" => metrics,
      "request_logger" => Phoenix.LiveDashboard.RequestLogger.param_key(conn)
    }
  end
end
