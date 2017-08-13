defmodule CoinNetwork.CLI do
  @moduledoc """
  Documentation for CoinNetwork.CLI
  """

  alias CoinNetwork.DiscoveryService
  alias CoinNetwork.Node

  @doc """
  Entrypoint for our CLI app
  """
  def main(_args \\ []) do
    IO.puts "Starting network simulation"
    DiscoveryService.start_link

    nodes = 1..100 |> Stream.map(fn(_) -> Node.start_link end) |> Stream.filter_map(&match?({:ok, _},&1), fn({:ok, pid}) -> pid end) |> Enum.to_list

    message_loop(nodes)
  end

  defp message_loop(nodes, wait_time \\ 1000) do
    IO.puts "#{Enum.filter(nodes, &Process.alive?(&1)) |> Kernel.length |> Kernel.inspect} nodes alive"
    node_pid = Enum.random(nodes)
    Node.send_message(node_pid, {UUID.uuid4(), "Hello at #{:calendar.universal_time |> Kernel.inspect}"})
    :timer.sleep(wait_time)
    message_loop(nodes, wait_time)
  end
end
