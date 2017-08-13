defmodule CoinNetwork.Keys do
  @moduledoc """
  Module to keep cryptographic functions.

  This module will end up being wrappers of Erlang's :crypto module since it has basically
  all of the cryptographic stuff we want already soundly implemented.
  """

  @address_prefix 0x00

  def generate_keys do
    private_key = generate_private_key()
    public_key = generate_public_key(private_key)
    address = generate_address(public_key)
    {private_key, public_key, address}
  end

  # Valid private keys are between 1 and n-1 where n = 1.158e77 (just below 2^256)
  # (Returns binary type -- you can either unpack that by :crypto.bytes_to_integer/1 or :binary.decode_unsigned/1)
  # (:binary.encode_unsigned/1 will take an integer representation back to the binary blob)
  defp generate_private_key do
    key = :crypto.strong_rand_bytes(1000) |> (&:crypto.hash(:sha256, &1)).()
    if :crypto.bytes_to_integer(key) < 1.158e77, do: key, else: generate_private_key()
  end

  # Elliptic curve multiplication generates the public key pair
  # (Returns binary type)
  defp generate_public_key(private_key) do
    {public, _private} = :crypto.generate_key(:ecdh, :secp256k1, private_key)
    public
  end

  # Bitcoin addresses are RIPEMD160(SHA256(K)) where K is the public key
  # (Returns Base58Check encoded public key hash)
  defp generate_address(public_key) do
    public_key |> (&:crypto.hash(:sha256, &1)).() |> (&:crypto.hash(:ripemd160, &1)).() |> (&Base58Check.encode58check(@address_prefix, &1)).()
  end
end