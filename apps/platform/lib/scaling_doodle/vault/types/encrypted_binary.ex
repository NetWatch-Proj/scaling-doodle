defmodule ScalingDoodle.Vault.Types.EncryptedBinary do
  @moduledoc """
  Ash type for encrypted binary fields using Cloak.

  This type automatically encrypts values before storing them in the database
  and decrypts them when reading. The encryption is transparent to the rest
  of the application.
  """
  use Ash.Type

  alias ScalingDoodle.Vault

  @impl Ash.Type
  def storage_type(_constraints), do: :binary

  @impl Ash.Type
  def cast_input(nil, _constraints), do: {:ok, nil}

  def cast_input(value, _constraints) when is_binary(value) do
    {:ok, value}
  end

  def cast_input(_value, _constraints) do
    {:error, "must be a string"}
  end

  @impl Ash.Type
  def cast_stored(nil, _constraints), do: {:ok, nil}

  def cast_stored(value, _constraints) when is_binary(value) do
    case Vault.decrypt(value) do
      {:ok, decrypted} -> {:ok, decrypted}
      _error -> {:ok, value}
    end
  end

  def cast_stored(value, _constraints) do
    {:ok, value}
  end

  @impl Ash.Type
  def dump_to_native(nil, _constraints), do: {:ok, nil}

  def dump_to_native(value, _constraints) when is_binary(value) do
    case Vault.encrypt(value) do
      {:ok, encrypted} -> {:ok, encrypted}
      {:error, reason} -> {:error, "encryption failed: #{inspect(reason)}"}
    end
  end

  def dump_to_native(_value, _constraints) do
    {:error, "must be a string"}
  end

  @impl Ash.Type
  def equal?(left, right), do: left == right
end
