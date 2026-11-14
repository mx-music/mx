defmodule Mx.SamplesTest do
  use ExUnit.Case, async: true

  alias Mx.Samples

  describe "path/2" do
    @dir "test/support/samples"

    test "finds a downloaded sample of the pack by name" do
      assert Samples.path(:bd_haus, @dir) == {:ok, Path.expand("bd_haus.flac", @dir)}
    end

    test "refuses a name the pack does not have" do
      assert Samples.path(:bd_hause, @dir) == {:error, "unknown sample bd_hause"}
    end

    test "says to run mix mx.samples.download sonic_pi for a sample of the pack not downloaded yet" do
      assert {:error, message} = Samples.path(:ambi_choir, @dir)
      assert message =~ "ambi_choir"
      assert message =~ "run mix mx.samples.download sonic_pi"
    end

    test "finds a file by path, and refuses a path that does not exist" do
      assert Samples.path("test/support/samples/sn_dolf.flac", @dir) ==
               {:ok, Path.expand("test/support/samples/sn_dolf.flac")}

      assert Samples.path("/missing.wav", @dir) ==
               {:error, "sample file /missing.wav does not exist"}
    end
  end

  test "keeps the pack outside the repository by default" do
    refute String.starts_with?(Samples.default_dir(), File.cwd!())
  end

  describe "download/1" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp} do
      served = Path.join(tmp, "served")
      File.mkdir_p!(served)

      for name <- ~w(a.flac b.flac c.flac README.md),
          do: File.write!(Path.join(served, name), name)

      :inets.start()

      {:ok, server} =
        :inets.start(:httpd,
          port: 0,
          server_name: ~c"mx-test",
          server_root: String.to_charlist(tmp),
          document_root: String.to_charlist(served),
          bind_address: {127, 0, 0, 1}
        )

      on_exit(fn -> :inets.stop(:httpd, server) end)
      port = :httpd.info(server)[:port]

      opts = [
        dir: Path.join(tmp, "pack"),
        base_url: "http://127.0.0.1:#{port}",
        names: ~w(a.flac b.flac c.flac)
      ]

      %{served: served, opts: opts}
    end

    test "downloads every sample and the licence, then nothing the second time", %{opts: opts} do
      assert Samples.download(opts) == {:ok, 4}
      assert File.read!(Path.join(opts[:dir], "b.flac")) == "b.flac"
      assert File.read!(Path.join(opts[:dir], "README.md")) == "README.md"
      assert Samples.download(opts) == {:ok, 0}
    end

    test "names the sample that failed, keeps the others, and a second run finishes", ctx do
      File.rm!(Path.join(ctx.served, "b.flac"))

      assert {:error, "b.flac", _reason, 1} = Samples.download(ctx.opts)
      assert File.exists?(Path.join(ctx.opts[:dir], "a.flac"))
      refute File.exists?(Path.join(ctx.opts[:dir], "b.flac"))

      File.write!(Path.join(ctx.served, "b.flac"), "b.flac")
      assert Samples.download(ctx.opts) == {:ok, 3}
    end
  end
end
