defmodule Mx.TablesTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mx.Engine.Mxs
  alias Mx.Engine.Mxs.Native

  @moduletag :tmp_dir

  setup do
    on_exit(fn ->
      for module <- [Mx.TablesTest.Mine, Mx.TablesTest.Nothing] do
        :code.purge(module)
        :code.delete(module)
      end
    end)
  end

  # Compiled as mix compiles, the module stays unknown, so other tests' engines never build it.
  defp compiled_file(file, source) do
    File.write!(file, source)
    {:ok, [module], _warnings} = Kernel.ParallelCompiler.compile([file])
    module
  end

  # A module that declares `table` at the path `at`, written beside `file`, and plays it.
  defp compiled(file, name, table, at) do
    source = """
    defmodule #{name} do
      use Mx.Instrument

      table #{inspect(table)}, #{inspect(at)}

      attr :note, :note, default: 60
      attr :vel, :float, default: 0.6, range: 0..1
      envelope_attrs sustain: 1000, release: 0.1
      attr :bend, :float, default: 0
      attr :brightness, :float, default: 0.5, range: 0..1

      defsynth plays_table(_o), do: figures(#{inspect(table)}, play: :fitted, level: 0.2, growth: 0.4)
    end
    """

    compiled_file(file, source)
  end

  # Fits a table to two struck recordings of C4, written as `out`.
  defp fitted(ctx, out) do
    dir = Path.join(ctx.tmp_dir, "struck")
    File.mkdir_p!(dir)
    rate = Mxs.render_rate()

    for velocity <- [64, 127] do
      sound =
        for index <- 0..(2 * rate - 1) do
          time = index / rate
          harmonics = Enum.map(1..4, &(:math.sin(2 * :math.pi() * 261.63 * &1 * time) / &1))
          wave = Enum.sum(harmonics)
          0.2 * wave * 10 ** (-1.5 * time)
        end

      data = for sample <- sound, into: <<>>, do: <<sample::float-little-32>>
      format = <<3::little-16, 1::little-16, rate::little-32, rate * 4::little-32, 4::little-16>>
      wav = "WAVE" <> "fmt " <> <<16::little-32>> <> format <> <<32::little-16>>
      body = wav <> "data" <> <<byte_size(data)::little-32>> <> data
      name = :io_lib.format("table-060-~3..0B.wav", [velocity]) |> to_string()
      File.write!(Path.join(dir, name), "RIFF" <> <<byte_size(body)::little-32>> <> body)
    end

    File.mkdir_p!(Path.dirname(out))
    args = ["electric_piano", "--struck", dir, "--notes", "C4:C4", "--out", out]
    capture_io(fn -> Mix.Tasks.Mx.Fit.run(args) end)
  end

  test "a module's table, declared at a path beside it, plays through figures by its name, sent once when it registers",
       ctx do
    fitted(ctx, Path.join([ctx.tmp_dir, "figures", "my_table.mxf"]))
    file = Path.join(ctx.tmp_dir, "instrument.ex")
    module = compiled(file, "Mx.TablesTest.Mine", :my_table, "figures/my_table.mxf")

    {:ok, engine} = Native.start(false, false)
    # A NIF sends no call trace, but its calls are counted.
    loads = {Native, :load_table, 2}
    :erlang.trace_pattern(loads, true, [:call_count])
    :ok = Mx.Instrument.register(engine, module)

    events =
      for index <- 0..99 do
        {index * 0.02, Mxs.event({:note, nil, :plays_table, nil, [vel: 0.5], nil})}
      end

    :ok = Native.play(engine, events)
    {:ok, {left, _right}} = Native.render(engine, 3)
    assert :erlang.trace_info(loads, :call_count) == {:call_count, 1}
    :erlang.trace_pattern(loads, false, [:call_count])

    assert Enum.any?(for <<x::float-32-native <- left>>, do: x != 0.0)
  end

  test "a module whose synth names a table mxs has not is refused, naming the table", ctx do
    file = Path.join(ctx.tmp_dir, "instrument.ex")

    module =
      compiled_file(file, """
      defmodule Mx.TablesTest.Nothing do
        use Mx.Instrument
        attr :note, :note, default: 60
        defsynth plays_nothing(_o), do: figures(:"nothing.mxh", play: :kept, level: 1)
      end
      """)

    refute module in Mx.Instrument.modules()
    {:ok, engine} = Native.start(false, false)
    assert {:error, reason} = Mx.Instrument.register(engine, module)
    assert reason =~ "nothing.mxh"
  end
end
