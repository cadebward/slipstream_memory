defmodule Slip.RoomServer do
  use Slipstream

  require Logger

  def start_link(_config) do
    config = [uri: "ws://localhost:4000/socket/websocket"]

    Slipstream.start_link(__MODULE__, config,
      name: __MODULE__,
      hibernate_after: 10_000,
      spawn_opt: [fullsweep_after: 200]
    )
  end

  @impl Slipstream
  def init(config) do
    case connect(config) do
      {:ok, socket} ->
        uri = Keyword.get(config, :uri, "NIL")
        Logger.info("Connecting to #{uri}")

        {:ok,
         socket
         |> assign(:config, config)
         |> assign(:connected, false)}

      {:error, reason} ->
        Logger.error("Could not start because of config validation failure: #{inspect(reason)}")

        :ignore
    end
  end

  @doc """
  Join all active chat channels on connect
  """
  @impl Slipstream
  def handle_connect(socket) do
    uri = Keyword.get(socket.assigns.config, :uri)
    Logger.info("Socket is connected to #{uri}")

    channels = Enum.map(1..50, &"room:#{&1}")

    channels
    |> Enum.with_index()
    |> Enum.each(fn {topic, _index} ->
      # Our hack: Process.send_after(self(), {:join, topic}, index * 1000)
      send(self(), {:join, topic})
    end)

    {:ok, assign(socket, connected: true)}
  end

  def handle_info({:join, topic}, socket) do
    Logger.info("Joining #{topic}...")
    {:noreply, join(socket, topic)}
  end

  @impl Slipstream
  def handle_join(topic, _payload, socket) do
    Logger.info("Joined channel #{topic}")
    {:ok, socket}
  end

  @impl Slipstream
  def handle_disconnect(reason, socket) do
    Logger.info("Disconnected #{reason}")
    reconnect(socket)
  end
end
