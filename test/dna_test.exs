defmodule DnaTest do
  use ExUnit.Case
  doctest Dna

  test "greets the world" do
    assert Dna.hello() == :world
  end
end
