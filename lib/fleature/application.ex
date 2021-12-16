defmodule Fleature.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Fleature.Client,
      Fleature.Store,
      {Registry,
       keys: :duplicate, name: Fleature.Registry, partitions: System.schedulers_online()}
    ]

    opts = [strategy: :one_for_one, name: Fleature.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
