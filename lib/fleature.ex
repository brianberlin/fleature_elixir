defmodule Fleature do
  def enabled?(name) do
    Fleature.Store.enabled?(name)
  end

  def list do
    Fleature.Store.list()
  end

  def subscribe do
    Registry.register(Fleature.Registry, "fleature:feature_flags", [])
  end

  def subscribe(name) do
    Registry.register(Fleature.Registry, "fleature:feature_flags:" <> name, [])
  end
end
