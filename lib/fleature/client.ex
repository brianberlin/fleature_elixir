defmodule Fleature.Client do
  @moduledoc false
  require Logger
  alias Phoenix.Channels.GenSocketClient
  @behaviour GenSocketClient

  def send_usage_data(usage_data) do
    pid = GenServer.whereis(__MODULE__)
    send(pid, {:send_usage_data, usage_data})
  end

  @spec child_spec(any) :: %{
          id: Fleature.Client,
          restart: :permanent,
          shutdown: 500,
          start: {Fleature.Client, :start_link, [...]},
          type: :worker
        }
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(_) do
    GenSocketClient.start_link(
      __MODULE__,
      Phoenix.Channels.GenSocketClient.Transport.WebSocketClient,
      url(),
      [],
      name: __MODULE__
    )
  end

  def init(url) do
    {:connect, url, connect_params(), nil}
  end

  def handle_connected(transport, state) do
    log("connected")
    GenSocketClient.join(transport, topic())
    {:ok, state}
  end

  def handle_message(_topic, "update_all", feature_flags, _transport, state) do
    Fleature.Store.update_all(feature_flags)
    {:ok, state}
  end

  def handle_message(_topic, "update_one", feature_flag, _transport, state) do
    Fleature.Store.update_one(feature_flag["name"], feature_flag["status"])
    {:ok, state}
  end

  def handle_message(topic, event, payload, _transport, state) do
    log("message on topic", topic: topic, event: event, payload: payload)
    {:ok, state}
  end

  def handle_info({:join, topic}, transport, state) do
    log("joining the topic", topic: topic)

    case GenSocketClient.join(transport, topic) do
      {:error, reason} ->
        Process.send_after(self(), {:join, topic}, :timer.seconds(1))
        log("error joining the topic", topic: topic, reason: reason)

      {:ok, _ref} ->
        :ok
    end

    {:ok, state}
  end

  def handle_info(:connect, _transport, state) do
    log("connecting")
    {:connect, state}
  end

  def handle_info({:send_usage_data, usage_data}, transport, state) do
    client_id = Application.get_env(:fleature, :client_id)
    GenSocketClient.push(transport, "client:" <> client_id, "usage", usage_data)

    {:ok, state}
  end

  def handle_info(message, _transport, state) do
    log("Unhandled message", message: message)
    {:ok, state}
  end

  def handle_disconnected(reason, state) do
    log("disconnected", reason: reason)
    Process.send_after(self(), :connect, :timer.seconds(1))
    {:ok, state}
  end

  def handle_joined(topic, _payload, _transport, state) do
    log("joined", topic: topic)
    {:ok, state}
  end

  def handle_join_error(topic, payload, _transport, state) do
    log("join error", topic: topic, payload: payload)
    {:ok, state}
  end

  def handle_channel_closed(topic, payload, _transport, state) do
    log("disconnected", topic: topic, payload: payload)
    Process.send_after(self(), {:join, topic}, :timer.seconds(1))
    {:ok, state}
  end

  def handle_reply(topic, _ref, payload, _transport, state) do
    log("reply", topic: topic, payload: payload)
    {:ok, state}
  end

  def handle_call(message, _from, _transport, state) do
    log("unexpected message", message: message)
    {:reply, {:error, :unexpected_message}, state}
  end

  def terminate(reason, _state) do
    log("terminating", reason: reason)
  end

  defp url do
    protocol = Application.get_env(:fleature, :protocol, "wss")
    host = Application.get_env(:fleature, :host, "fleature-web.fly.dev")
    port = Application.get_env(:fleature, :port, 443)
    "#{protocol}://#{host}:#{port}/clients/websocket"
  end

  defp connect_params do
    client_id = Application.get_env(:fleature, :client_id)
    client_secret = Application.get_env(:fleature, :client_secret)
    [{"client_id", client_id}, {"client_secret", client_secret}]
  end

  defp topic do
    client_id = Application.get_env(:fleature, :client_id)
    "client:" <> client_id
  end

  defp log(message, opts \\ []) do
    Logger.debug("FLEATURE: #{message} - #{inspect(opts)}")
  end
end
