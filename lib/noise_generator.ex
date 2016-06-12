defmodule NoiseGenerator do
  use GenServer

  def start_link(state) do
    GenServer.start_link __MODULE__, state, name: __MODULE__
  end

  def handle_call(:settings, _from, config) do
    {:reply, config, config}
  end

  def handle_call(:get, _from, config) do
    result = for x <- 0..config.width, y <- 0..config.height do
      noise = round(255 * Noise.Simplex.get(config, {x, y}))
      << noise, noise, noise >>
    end |> :erlang.list_to_binary

    {:reply, result, config}
  end

  def handle_cast({:set, :seed, seed}, config) do
    {:noreply, %{ config | seed: seed }}
  end
  def handle_cast({:set, :amplitude, amplitude}, config) do
    {:noreply, %{ config | amplitude: amplitude }}
  end
  def handle_cast({:set, :frequency, frequency}, config) do
    {:noreply, %{ config | frequency: frequency }}
  end
  def handle_cast({:set, :persistence, persistence}, config) do
    {:noreply, %{ config | persistence: persistence }}
  end
  def handle_cast({:set, :octaves, octaves}, config) do
    {:noreply, %{ config | octaves: octaves }}
  end
  def handle_cast({:set, :size, {w, h}}, config) do
    {:noreply, %{ config | width: w, height: h }}
  end
end
