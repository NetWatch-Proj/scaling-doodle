defmodule ScalingDoodle.Vault do
  @moduledoc """
  Cloak vault for encrypting sensitive fields in the database.

  Uses AES-GCM-256 encryption with a key derived from the
  CLOAK_KEY environment variable.
  """
  use Cloak.Vault, otp_app: :scaling_doodle

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers, default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: cloak_key()})

    {:ok, config}
  end

  defp cloak_key do
    key = System.get_env("CLOAK_KEY") || cloak_key_dev()

    if is_binary(key) and byte_size(key) == 32 do
      key
    else
      raise """
      CLOAK_KEY must be a 32-byte (256-bit) string.

      Generate a new key with:
        mix cloak.gen.key

      For development, a default key is used. Set CLOAK_KEY in production.
      """
    end
  end

  defp cloak_key_dev do
    # Development-only default key (exactly 32 bytes)
    # DO NOT USE IN PRODUCTION
    "development_only_key_32_bytes_!!"
  end
end
