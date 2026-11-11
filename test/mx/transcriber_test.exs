defmodule Mx.TranscriberTest do
  use ExUnit.Case, async: true

  @moduletag :transcriber
  @moduletag timeout: 1_800_000

  @dir "test/support/scans/abc"

  test "a system of a rag is transcribed to the ABC the model wrote for it before" do
    image = Path.join(@dir, "system-01.png")

    assert Mx.Transcriber.transcribe([image]) ==
             {:ok, [File.read!(Path.join(@dir, "system-01.abc"))]}
  end
end
