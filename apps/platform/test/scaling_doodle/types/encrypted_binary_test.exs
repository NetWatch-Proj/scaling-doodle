defmodule ScalingDoodle.Types.EncryptedBinaryTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Types.EncryptedBinary

  describe "Ash type implementation" do
    test "implements Ash.Type behaviour" do
      assert function_exported?(EncryptedBinary, :cast_input, 2)
      assert function_exported?(EncryptedBinary, :cast_stored, 2)
      assert function_exported?(EncryptedBinary, :dump_to_native, 2)
    end

    test "storage_type returns :binary" do
      assert EncryptedBinary.storage_type([]) == :binary
    end

    test "handles nil values" do
      assert {:ok, nil} = EncryptedBinary.cast_input(nil, [])
      assert {:ok, nil} = EncryptedBinary.cast_stored(nil, [])
      assert {:ok, nil} = EncryptedBinary.dump_to_native(nil, [])
    end

    test "cast_input accepts binary values" do
      assert {:ok, "hello"} = EncryptedBinary.cast_input("hello", [])
      assert {:ok, ""} = EncryptedBinary.cast_input("", [])
    end

    test "cast_input rejects non-binary values" do
      assert {:error, _} = EncryptedBinary.cast_input(123, [])
      assert {:error, _} = EncryptedBinary.cast_input(%{}, [])
      # Note: nil is accepted (returns {:ok, nil})
      assert {:ok, nil} = EncryptedBinary.cast_input(nil, [])
    end

    test "equal? compares values correctly" do
      assert EncryptedBinary.equal?("hello", "hello")
      refute EncryptedBinary.equal?("hello", "world")
      assert EncryptedBinary.equal?(nil, nil)
    end
  end
end
