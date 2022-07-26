defmodule ElectricTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  doctest Electric

  test "entrypoint runs without error" do
    assert {0, output} = with_io(fn -> Electric.main() end)

    assert output =~ "Electric SQL CLI"
  end
end
