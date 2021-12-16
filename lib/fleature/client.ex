defmodule Fleature.Client do
  @moduledoc false
  require Logger
  alias Phoenix.Channels.GenSocketClient
  @behaviour GenSocketClient

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
      url()
    )
  end

  def init(url) do
    {:connect, url, connect_params(), nil}
  end

  def handle_connected(transport, state) do
    Logger.info("connected")
    GenSocketClient.join(transport, topic())
    {:ok, state}
  end

  def handle_message(_topic, "update_all", feature_flags, _transport, state) do
    Fleature.Store.update_all(feature_flags)
    {:ok, state}
  end

  def handle_message(_topic, "update_one", feature_flag, _transport, state) do
    [{name, status}] = Enum.into(feature_flag, [])
    Fleature.Store.update_one(name, status)
    {:ok, state}
  end

  def handle_message(topic, event, payload, _transport, state) do
    Logger.warn("message on topic #{topic}: #{event} #{inspect(payload)}")
    {:ok, state}
  end

  def handle_info({:join, topic}, transport, state) do
    Logger.info("joining the topic #{topic}")

    case GenSocketClient.join(transport, topic) do
      {:error, reason} ->
        Logger.error("error joining the topic #{topic}: #{inspect(reason)}")

      {:ok, _ref} ->
        :ok
    end

    {:ok, state}
  end

  def handle_info(:connect, _transport, state) do
    Logger.info("connecting")
    {:connect, state}
  end

  def handle_info(message, _transport, state) do
    Logger.warn("Unhandled message #{inspect(message)}")
    {:ok, state}
  end

  def handle_disconnected(reason, state) do
    Logger.error("disconnected: #{inspect(reason)}")
    {:ok, state}
  end

  def handle_joined(topic, _payload, _transport, state) do
    Logger.info("joined the topic #{topic}")
    {:ok, state}
  end

  def handle_join_error(topic, payload, _transport, state) do
    Logger.error("join error on the topic #{topic}: #{inspect(payload)}")
    {:ok, state}
  end

  def handle_channel_closed(topic, payload, _transport, state) do
    Logger.error("disconnected from the topic #{topic}: #{inspect(payload)}")
    {:ok, state}
  end

  def handle_reply(topic, _ref, payload, _transport, state) do
    Logger.warn("reply on topic #{topic}: #{inspect(payload)}")
    {:ok, state}
  end

  def handle_call(message, _from, _transport, state) do
    Logger.warn("Did not expect to receive call with message: #{inspect(message)}")
    {:reply, {:error, :unexpected_message}, state}
  end

  def terminate(reason, _state) do
    Logger.info("Terminating and cleaning up state. Reason for termination: #{inspect(reason)}")
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
end
