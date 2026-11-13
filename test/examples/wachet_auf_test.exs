defmodule Mx.Examples.WachetAufTest do
  use ExUnit.Case, async: true

  test "the score's license is kept beside it" do
    assert File.read!("examples/wachet_auf/LICENSE.md") =~
             "Redistribution and use in source and binary forms"
  end
end
