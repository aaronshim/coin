defmodule CoinNetwork.DiscoveryService do
  @moduledoc """
  Documentation for CoinNetwork.DiscoveryService
  """

  use GenServer
  alias CoinNetwork.Node

  @name DS

  ## Client API

  @doc """
  Start a node
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts ++ [name: DS])
  end

  @doc """
  Ask for the address of a peer in the network
  """
  def get_peer do
    GenServer.call(@name, {:peer})
  end

  @doc """
  Ask for all the peers the discovery service knows about
  """
  def get_peers do
    GenServer.call(@name, {:peers})
  end

  @doc """
  Add a peer to the known list of peers in the discovery service
  """
  def set_peer(pid) do
    GenServer.cast(@name, {:set_peer, pid})
  end

  ## Server Callbacks

  def init(:ok) do
    IO.puts "Hello from the Peer Discovery Service running at #{Kernel.inspect(self())}"
    {:ok, %{peers: [], nodes_to_notify: []}}
  end

  def handle_call({:peer}, {from, _ref}, %{peers: peers, nodes_to_notify: nodes_to_notify} = state) do
    case find_random_peer_for(from, peers) do
      # We need to generate a failure condition if we don't know any peers
      nil ->
        new_peers = if Enum.empty?(peers), do: [from], else: peers # Avoid deadlock
        {:reply, {:error, "No known peers"}, %{peers: new_peers, nodes_to_notify: [from | nodes_to_notify]}}

      pid ->
        {:reply, {:ok, pid}, state}
    end
  end

  def handle_call({:peers}, _from, %{peers: peers, nodes_to_notify: _nodes_to_notify} = state) do
    {:reply, peers, state}
  end

  def handle_cast({:set_peer, pid}, %{peers: peers, nodes_to_notify: nodes_to_notify} = state) do
    if pid in state do
      {:noreply, state}
    else
      new_peers = [pid | peers]
      Enum.each(nodes_to_notify, &notify_random_peer_if_exists(&1, peers))
      {:noreply, %{peers: new_peers, nodes_to_notify: nodes_to_notify}}
    end
  end

  ## Helper functions

  defp find_random_peer_for(pid, peers) do
    # We don't want to tell the caller to connect to itself
    other_peers = List.delete(peers, pid)

    if Kernel.length(other_peers) > 0, do: Enum.random(other_peers), else: nil
  end

  defp notify_random_peer_if_exists(pid, peers) do
    case find_random_peer_for(pid, peers) do
      nil ->
        nil

      peer_pid ->
        Node.set_peer(pid, peer_pid)
    end
  end

end
