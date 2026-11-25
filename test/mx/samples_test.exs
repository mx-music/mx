defmodule Mx.SamplesTest do
  use ExUnit.Case, async: true

  alias Mx.Samples

  describe "path/2" do
    @dir "test/support/samples"

    test "finds a downloaded sample of the pack by name" do
      assert Samples.path({:sonic_pi, :bd_haus}, @dir) == {:ok, Path.expand("bd_haus.flac", @dir)}
    end

    test "refuses a name the pack does not have" do
      assert Samples.path({:sonic_pi, :bd_hause}, @dir) == {:error, "unknown sample bd_hause"}
    end

    test "says to run mix mx.samples.download sonic_pi for a sample of the pack not downloaded yet" do
      assert {:error, message} = Samples.path({:sonic_pi, :ambi_choir}, @dir)
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
          do: served |> Path.join(name) |> File.write!(name)

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
      assert opts |> Access.get(:dir) |> Path.join("b.flac") |> File.read!() == "b.flac"
      assert opts |> Access.get(:dir) |> Path.join("README.md") |> File.read!() == "README.md"
      assert Samples.download(opts) == {:ok, 0}
    end

    test "names the sample that failed, keeps the others, and a second run finishes", ctx do
      ctx.served |> Path.join("b.flac") |> File.rm!()

      assert {:error, "b.flac", _reason, 1} = Samples.download(ctx.opts)
      assert ctx.opts |> Access.get(:dir) |> Path.join("a.flac") |> File.exists?()
      refute ctx.opts |> Access.get(:dir) |> Path.join("b.flac") |> File.exists?()

      ctx.served |> Path.join("b.flac") |> File.write!("b.flac")
      assert Samples.download(ctx.opts) == {:ok, 3}
    end
  end
end
