defmodule Fleature.Store do
  use GenServer

  def list do
    GenServer.call(__MODULE__, :list)
  end

  def enabled?(name) do
    Fleature.Usage.used(name)
    GenServer.call(__MODULE__, {:enabled?, name})
  end

  def update(name, status) do
    GenServer.cast(__MODULE__, {:update, name, status})
  end

  def start_link(_) do
    feature_flags = Application.get_env(:fleature, :feature_flags)
    GenServer.start_link(__MODULE__, feature_flags, name: __MODULE__)
  end

  def init(feature_flags) do
    {:ok, feature_flags}
  end

  def handle_cast({:update, name, status}, feature_flags) do
    dispatch("fleature:feature_flags:" <> name, {:feature_flag, name, status})
    dispatch("fleature:feature_flags", {:feature_flag, name, status})
    {:noreply, Map.put(feature_flags, name, status)}
  end

  def handle_call({:enabled?, name}, _from, feature_flags) do
    {:reply, Map.get(feature_flags, name, false), feature_flags}
  end

  def handle_call(:list, _from, feature_flags) do
    {:reply, feature_flags, feature_flags}
  end

  defp dispatch(topic, message) do
    Registry.dispatch(Fleature.Registry, topic, fn entries ->
      for {pid, _} <- entries do
        send(pid, message)
      end
    end)
  end
end
