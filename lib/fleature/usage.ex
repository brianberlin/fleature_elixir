defmodule Fleature.Usage do
  use GenServer

  @interval 10_000

  def used(name) do
    GenServer.cast(__MODULE__, {:used, name})
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    Process.send_after(self(), :send_usage_data, @interval)
    {:ok, state}
  end

  def handle_cast({:used, name}, state) do
    count = Map.get(state, name, 0)
    state = Map.put(state, name, count + 1)
    {:noreply, state}
  end

  def handle_info(:send_usage_data, state) do
    Process.send_after(self(), :send_usage_data, @interval)

    if state !== %{} do
      Fleature.Client.send_usage_data(state)
    end

    {:noreply, %{}}
  end
end
