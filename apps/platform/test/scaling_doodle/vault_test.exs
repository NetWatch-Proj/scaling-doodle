defmodule ScalingDoodle.VaultTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Vault

  describe "Vault configuration" do
    test "module exists and exports required functions" do
      assert function_exported?(Vault, :encrypt, 1)
      assert function_exported?(Vault, :decrypt, 1)
    end

    test "can encrypt and decrypt a binary value" do
      plaintext = "sensitive-data-to-encrypt"

      assert {:ok, encrypted} = Vault.encrypt(plaintext)
      assert is_binary(encrypted)
      refute encrypted == plaintext

      assert {:ok, decrypted} = Vault.decrypt(encrypted)
      assert decrypted == plaintext
    end

    test "produces different ciphertexts for same plaintext" do
      plaintext = "same-plaintext"

      assert {:ok, encrypted1} = Vault.encrypt(plaintext)
      assert {:ok, encrypted2} = Vault.encrypt(plaintext)

      assert encrypted1 != encrypted2

      # But both decrypt to the same value
      assert {:ok, ^plaintext} = Vault.decrypt(encrypted1)
      assert {:ok, ^plaintext} = Vault.decrypt(encrypted2)
    end

    test "handles binary data" do
      binary_data = <<1, 2, 3, 4, 5, 255, 254, 253>>

      assert {:ok, encrypted} = Vault.encrypt(binary_data)
      assert {:ok, decrypted} = Vault.decrypt(encrypted)

      assert decrypted == binary_data
    end

    test "handles empty string" do
      assert {:ok, encrypted} = Vault.encrypt("")
      assert {:ok, decrypted} = Vault.decrypt(encrypted)

      assert decrypted == ""
    end

    test "handles unicode strings" do
      unicode_text = "Hello 世界 🌍"

      assert {:ok, encrypted} = Vault.encrypt(unicode_text)
      assert {:ok, decrypted} = Vault.decrypt(encrypted)

      assert decrypted == unicode_text
    end
  end
end
