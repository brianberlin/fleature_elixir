# Fleature

## Installation

Add the package to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fleature, github: "brianberlin/fleature_elixir"}
  ]
end
```

Add the configuration to your project. 

```elixir
config :fleature,
  client_id: "XXXX",
  client_secret: "XXXX",
  feature_flags: %{
    "test" => false
  }
```
You can also configure the host and port.
### Example usage in a LiveView

```elixir
defmodule FleatureTestWeb.HomeLive do
  use FleatureTestWeb, :live_view

  def mount(_arg1, _session, socket) do
    Fleature.subscribe("test_feature_flag")

    {:ok, assign(socket, :test_feature_flag, Fleature.enabled?("test_feature_flag"))}
  end

  def render(assigns) do
    ~H"""
    <%= if @test_feature_flag do %>
      <p>Feature Enabled</p>
    <% else %>
      <p>Feature Disabled</p>
    <% end %>
    """
  end

  def handle_info({:feature_flag, "test_feature_flag", status}, socket) do
    {:noreply, assign(socket, :test_feature_flag, status)}
  end
end
```