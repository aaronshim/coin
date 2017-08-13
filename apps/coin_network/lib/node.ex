defmodule CoinNetwork.Node do
  @moduledoc """
  Documentation for CoinNetwork.CLI
  """
  
  use GenServer
  alias CoinNetwork.DiscoveryService

  ## Client API

  @doc """
  Start a node
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Send a message to a particular node.

  It will then broadcast the message to the peers it knows about in the network
  """
  def send_message(server, msg) do
    GenServer.cast(server, {:broadcast, msg})
  end

  @doc """
  Get the peers of a particular node
  """
  def peers(server) do
    GenServer.call(server, {:peers})
  end

  @doc """
  A hook for the Discovery Service or other peers to notify of new peers in the network
  """
  def set_peer(server, pid) do
    GenServer.cast(server, {:set_peer, pid})
  end

  ## Server Callbacks

  def init(:ok) do
    IO.puts "Hello from a node running at #{Kernel.inspect(self())}"
    
    # Ask the discovery service some other peers to start connecting to
    case DiscoveryService.get_peer() do
      {:ok, pid} ->
        # Ask the already-a-member peer node to add me as a known peer
        __MODULE__.set_peer(pid, self())

        # Make myself known to the discovery service (but only after I'm a valid member of the network)
        DiscoveryService.set_peer(self())

        {:ok, %{messages: [], peers: [ pid ]}}
      {:error, _reason} ->
        {:ok, %{messages: [], peers: []}}
    end
  end

  def handle_cast({:broadcast, {uuid, text}}, %{messages: messages, peers: peers} = state) do
    if uuid in messages do
      # Stop propogating messages you've already seen
      {:noreply, state}
    else
      # Confirm that you've received the message
      IO.puts "#{Kernel.inspect(self())} received the message #{text} with the tag #{uuid}"

      # Notify all peers to propogate
      Enum.each peers, fn(pid) -> __MODULE__.send_message(pid, {uuid, text}) end

      # Store the UUID as a seen message in our state
      {:noreply, %{messages: [uuid | messages], peers: peers}}
    end
  end

  def handle_cast({:set_peer, peer_pid}, %{messages: messages, peers: peers} = state) do
    if peer_pid in peers do
      # Stop propogating messages you've already seen
      {:noreply, state}
    else
      # Confirm that you've received the message
      IO.puts "#{Kernel.inspect(self())} was notified about peer #{Kernel.inspect(peer_pid)}"

      # Notify all peers to propogate
      Enum.each peers, fn(pid) -> __MODULE__.set_peer(pid, peer_pid) end

      # Register the new peer
      {:noreply, %{messages: messages, peers: [peer_pid | peers]}}
    end
  end

  def handle_call({:peers}, _from, %{messages: _messages, peers: peers} = state) do
    {:reply, peers, state}
  end
end