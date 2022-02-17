defmodule Fleature.Client do
  @moduledoc false
  require Logger
  use GenServer

  def send_usage_data(usage_data) do
    pid = GenServer.whereis(__MODULE__)
    send(pid, {:send_usage_data, usage_data})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(state) do
    send(self(), :setup_server_sent_events)
    send(self(), :fetch_all_flags)
    {:ok, state}
  end

  def handle_info(:fetch_all_flags, state) do
    {:ok, %{status_code: 200, body: body}} = HTTPoison.get(url("/feature_flags"))

    body
    |> Jason.decode!()
    |> Enum.each(&Fleature.Store.update(&1["name"], &1["status"]))

    {:noreply, state}
  end

  def handle_info(:setup_server_sent_events, state) do
    opts = [recv_timeout: :infinity, stream_to: self()]
    {:ok, _response} = HTTPoison.get(url("/feature_flags/events"), [], opts)
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: "data: " <> data}, state) do
    [name, status] =
      data
      |> String.trim()
      |> String.split("=")

    Fleature.Store.update(name, status === "true")

    {:noreply, state}
  end

  def handle_info({:send_usage_data, usage_data}, state) do
    HTTPoison.post(url("/feature_flags/usage"), usage_data)

    {:ok, state}
  end

  def handle_info(msg, state) do
    IO.inspect(msg)

    {:noreply, state}
  end



  defp url(path) do
    client_id = Application.get_env(:fleature, :client_id)
    client_secret = Application.get_env(:fleature, :client_secret)
    protocol = Application.get_env(:fleature, :protocol, "https")
    host = Application.get_env(:fleature, :host, "fleature-web.fly.dev")
    port = Application.get_env(:fleature, :port, 443)

    "#{protocol}://#{host}:#{port}/api/#{path}?client_id=#{client_id}&client_secret=#{client_secret}"
  end

end
