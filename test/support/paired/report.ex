defmodule Mx.Paired.Report do
  @moduledoc """
  The page `mix bench.paired --report` writes: each paired instrument's defsynth form timed against its Rust form, for a person to read.
  """

  @doc "The page for `rows`, as `Mix.Tasks.Bench.Paired` measures them, and `context`, the machine, commit and mxs version they were measured on."
  def html(rows, context) do
    [head(), body(rows, context)]
  end

  defp head do
    """
    <meta charset="utf-8">
    <title>Defsynth vs Rust</title>
    <meta name="claude:viewport-fit-sides" content="cover">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&display=swap">
    <style>
    /* One reading column: summary, the chart of every instrument, the table, each case, then the method. */
    :root {
      --bg: #f7f8f9; --panel: #ffffff; --ink: #14171a; --muted: #5a626b; --rule: #dde1e5;
      --slower: #eb6834; --faster: #2a78d6; --even: #9aa1a8;
      --sans: "IBM Plex Sans", system-ui, sans-serif; --mono: "IBM Plex Mono", ui-monospace, monospace;
    }
    @media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
      --bg: #121417; --panel: #1a1d21; --ink: #eceef0; --muted: #a2a9b1; --rule: #2c3137;
      --slower: #d95926; --faster: #3987e5; --even: #6c737b; color-scheme: dark } }
    :root[data-theme="dark"] {
      --bg: #121417; --panel: #1a1d21; --ink: #eceef0; --muted: #a2a9b1; --rule: #2c3137;
      --slower: #d95926; --faster: #3987e5; --even: #6c737b; color-scheme: dark }
    body { background: var(--bg); color: var(--ink); font: 15px/1.55 var(--sans);
      padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); padding-block: 32px 64px }
    main { max-width: 880px; margin: 0 auto; display: grid; gap: 40px }
    h1 { font-size: 30px; line-height: 1.2; margin: 0; font-weight: 600; text-wrap: balance }
    h2 { font-size: 19px; margin: 0 0 6px; font-weight: 600; text-wrap: balance }
    p { margin: 0; max-width: 68ch }
    section { display: grid; gap: 12px; min-width: 0 }
    .context { color: var(--muted); font: 13px/1.6 var(--mono) }
    .tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 12px }
    .tile { background: var(--panel); border: 1px solid var(--rule); border-radius: 6px; padding: 14px 16px; display: grid; gap: 2px }
    .tile b { font: 500 26px/1.2 var(--mono); font-variant-numeric: tabular-nums }
    .tile span { color: var(--muted); font-size: 13px }
    .legend { display: flex; flex-wrap: wrap; gap: 16px; color: var(--muted); font-size: 13px }
    .legend i { display: inline-block; width: 10px; height: 10px; border-radius: 2px; margin-right: 6px; vertical-align: -1px }
    .scroll { overflow-x: auto; min-width: 0 }
    svg { display: block; width: 100%; min-width: 560px; height: auto }
    svg text { fill: var(--muted); font: 11px var(--mono) }
    svg .name { fill: var(--ink) }
    svg .grid { stroke: var(--rule); stroke-width: 1 }
    svg .one { stroke: var(--muted); stroke-width: 1 }
    svg .slower { fill: var(--slower) } svg .faster { fill: var(--faster) } svg .even { fill: var(--even) }
    svg .row:hover .hit { fill: var(--rule) } svg .hit { fill: transparent }
    table { border-collapse: collapse; width: 100%; font: 13px/1.4 var(--mono); font-variant-numeric: tabular-nums }
    th, td { padding: 6px 10px; text-align: right; border-bottom: 1px solid var(--rule); white-space: nowrap }
    th { color: var(--muted); font-weight: 500; position: sticky; top: 0; background: var(--bg) }
    th:first-child, td:first-child { text-align: left }
    .pill { display: inline-block; padding: 0 6px; border-radius: 9px; font-size: 12px; border: 1px solid currentColor }
    .pill.slower { color: var(--slower) } .pill.faster { color: var(--faster) } .pill.even { color: var(--muted) }
    details { background: var(--panel); border: 1px solid var(--rule); border-radius: 6px; padding: 8px 14px }
    details + details { margin-top: 8px }
    summary { cursor: pointer; font: 500 14px var(--mono) }
    summary:focus-visible { outline: 2px solid var(--faster); outline-offset: 2px }
    details table { margin-top: 8px }
    td.options { text-align: left; white-space: normal; color: var(--muted) }
    div#tip { position: fixed; pointer-events: none; background: var(--panel); color: var(--ink); border: 1px solid var(--rule);
      border-radius: 6px; padding: 8px 10px; font: 12px/1.5 var(--mono); box-shadow: 0 4px 16px rgb(0 0 0 / 0.12) }
    </style>
    """
  end

  defp body(rows, context) do
    [
      "<main>",
      header(rows, context),
      chart(rows),
      table(rows),
      cases(rows),
      method(context),
      "</main><div id=\"tip\" hidden></div>",
      script(),
      "\n"
    ]
  end

  defp header(rows, context) do
    count = length(rows)
    even = Enum.count(rows, &(kind(&1.times) == "even"))
    slow = Enum.count(rows, &(&1.times >= 1.5))
    noisiest = Enum.max_by(rows, & &1.spread_percent)
    changed = if context.changed, do: " with uncommitted changes", else: ""

    """
    <header style="display:grid;gap:10px">
      <h1>Defsynth vs Rust</h1>
      <p>How much longer each paired instrument takes to render when written with defsynth than in mxs's Rust, measured on the same engine with the same options.</p>
      <p class="context">#{context.date} · mx #{context.commit}#{changed} · mxs #{context.mxs} · #{escape(context.machine)} · #{context.runs} runs</p>
    </header>
    <div class="tiles">
      <div class="tile"><b>#{number(geometric_mean(rows))}×</b><span>geometric mean of defsynth over Rust</span></div>
      <div class="tile"><b>#{even} of #{count}</b><span>instruments within 10% of Rust</span></div>
      <div class="tile"><b>#{slow}</b><span>instruments 1.5× or slower</span></div>
      <div class="tile"><b>#{noisiest.spread_percent}%</b><span>widest spread between runs, #{noisiest.synth}</span></div>
    </div>
    """
  end

  @label 150
  @plot 560
  @row 18
  @top 30

  defp chart(rows) do
    clamped = for row <- rows, do: max(row.times, 0.1)
    low = :math.pow(2, Float.floor(:math.log2(Enum.min([0.5 | clamped]))))
    high = :math.pow(2, Float.ceil(:math.log2(Enum.max([2.0 | clamped]))))

    position = fn times ->
      @label + (:math.log2(times) - :math.log2(low)) / :math.log2(high / low) * @plot
    end

    height = @top + length(rows) * @row + 8
    width = @label + @plot + 70
    ticks = for power <- round(:math.log2(low))..round(:math.log2(high)), do: :math.pow(2, power)

    grid =
      for tick <- ticks do
        at = position.(tick)
        line = if tick == 1, do: "one", else: "grid"

        ~s(<line class="#{line}" x1="#{at}" x2="#{at}" y1="#{@top - 8}" y2="#{height - 4}"/><text x="#{at}" y="#{@top - 14}" text-anchor="middle">#{tick(tick)}×</text>)
      end

    bars =
      for {row, index} <- Enum.with_index(rows) do
        top = @top + index * @row
        one = position.(1)
        end_at = position.(max(row.times, 0.1))
        {left, right} = if end_at >= one, do: {one, end_at}, else: {end_at, one}
        kind = kind(row.times)

        labelled = row.times >= 1.5 or row.times <= 0.67
        label = if labelled, do: value_label(row, end_at, one, top), else: ""

        tip =
          "#{row.synth}|#{number(row.times)}× · #{label(kind)}|Rust #{number(row.rust_ms_per_second)} ms per second|defsynth #{number(row.defsynth_ms_per_second)} ms per second|spread #{row.spread_percent}%"

        ~s(<g class="row" data-tip="#{escape(tip)}"><rect class="hit" x="0" y="#{top}" width="#{width}" height="#{@row}"/><text class="name" x="#{@label - 10}" y="#{top + 13}" text-anchor="end">#{row.synth}</text><rect class="#{kind}" x="#{left}" y="#{top + 4}" width="#{max(right - left, 2)}" height="10" rx="2"/>#{label}</g>)
      end

    """
    <section>
      <h2>Render time, defsynth over Rust</h2>
      <p>Each bar runs from 1×, where both forms take the same time, to the defsynth form's render time as a multiple of the Rust form's, on a scale that doubles at each line.</p>
      <div class="legend"><span><i style="background:var(--slower)"></i>defsynth slower by more than 10%</span><span><i style="background:var(--even)"></i>within 10%</span><span><i style="background:var(--faster)"></i>defsynth faster by more than 10%</span></div>
      <div class="scroll"><svg viewBox="0 0 #{width} #{height}" role="img" aria-label="Render time of each instrument's defsynth form as a multiple of its Rust form">#{grid}#{bars}</svg></div>
    </section>
    """
  end

  defp value_label(row, end_at, one, top) do
    {at, anchor} = if end_at >= one, do: {end_at + 6, "start"}, else: {end_at - 6, "end"}
    ~s(<text x="#{at}" y="#{top + 13}" text-anchor="#{anchor}">#{number(row.times)}×</text>)
  end

  defp table(rows) do
    body =
      for row <- rows do
        """
        <tr><td>#{row.synth}</td><td>#{length(row.cases)}</td><td>#{row.rust_build_us}</td><td>#{row.defsynth_build_us}</td><td>#{number(row.rust_ms_per_second)}</td><td>#{number(row.defsynth_ms_per_second)}</td><td><span class="pill #{kind(row.times)}">#{number(row.times)}×</span></td><td>#{number(row.register_ms)}</td><td>#{row.spread_percent}</td></tr>
        """
      end

    """
    <section>
      <h2>Every instrument</h2>
      <p>Build is the microseconds handing a note to the engine takes, which builds its voice. Render is the milliseconds the engine takes for each second of the note, less what an engine without notes takes. Both are means over the instrument's cases. Register is the milliseconds registering the defsynth form takes, once for an engine. Spread is how far apart the runs' render times were, at worst.</p>
      <div class="scroll"><table>
        <thead><tr><th>instrument</th><th>cases</th><th>Rust build µs</th><th>defsynth build µs</th><th>Rust render ms/s</th><th>defsynth render ms/s</th><th>defsynth ÷ Rust</th><th>register ms</th><th>spread %</th></tr></thead>
        <tbody>#{body}</tbody>
      </table></div>
    </section>
    """
  end

  defp cases(rows) do
    blocks =
      for row <- rows do
        open = if row.times >= 1.5, do: " open", else: ""

        lines =
          for case <- row.cases do
            """
            <tr><td class="options">#{escape(inspect(case.options))}</td><td>#{case.rust_build_us}</td><td>#{case.defsynth_build_us}</td><td>#{number(case.rust_ms_per_second)}</td><td>#{number(case.defsynth_ms_per_second)}</td><td><span class="pill #{kind(case.times)}">#{number(case.times)}×</span></td><td>#{case.spread_percent}</td></tr>
            """
          end

        """
        <details#{open}><summary>#{row.synth} · #{number(row.times)}×</summary><div class="scroll"><table>
          <thead><tr><th>options</th><th>Rust build µs</th><th>defsynth build µs</th><th>Rust ms/s</th><th>defsynth ms/s</th><th>÷</th><th>spread %</th></tr></thead>
          <tbody>#{lines}</tbody>
        </table></div></details>
        """
      end

    """
    <section>
      <h2>Each case</h2>
      <p>The options each instrument is played with, as the paired test checks them, with each one's figures. The instruments 1.5× or slower are open.</p>
      <div>#{blocks}</div>
    </section>
    """
  end

  defp method(context) do
    """
    <section>
      <h2>How it is measured</h2>
      <p>Each case is played on a fresh offline engine #{context.runs} times in each form, the two forms taking turns, and each figure is the median of the runs. Render time comes from the engine's own meter around its mixer, so calls from Elixir into the engine do not count in it. Build time is measured around the call that hands the note over, with the VM's schedulers waiting busy, since a sleeping one can take 10 ms to wake.</p>
      <p>The figures mean something only on a machine doing nothing else. A spread above 20% says the machine was busy while that instrument was measured.</p>
      <p class="context">ERL_FLAGS="+sbwt very_long +sbwtdcpu very_long +sbwtdio very_long" mix bench.paired --report FILE</p>
    </section>
    """
  end

  defp script do
    """
    <script>
    (() => {
      const tip = document.getElementById("tip");
      for (const row of document.querySelectorAll("[data-tip]")) {
        row.addEventListener("mousemove", (event) => {
          const [name, ...lines] = row.dataset.tip.split("|");
          tip.replaceChildren(Object.assign(document.createElement("b"), { textContent: name }));
          for (const line of lines) tip.append(document.createElement("br"), line);
          tip.hidden = false;
          const x = Math.min(event.clientX + 14, window.innerWidth - tip.offsetWidth - 8);
          tip.style.left = x + "px";
          tip.style.top = (event.clientY + 14) + "px";
        });
        row.addEventListener("mouseleave", () => { tip.hidden = true; });
      }
    })();
    </script>
    """
  end

  defp kind(times) when times > 1.1, do: "slower"
  defp kind(times) when times < 0.9, do: "faster"
  defp kind(_times), do: "even"

  defp label("slower"), do: "defsynth slower"
  defp label("faster"), do: "defsynth faster"
  defp label("even"), do: "within 10%"

  defp geometric_mean(rows) do
    logs = for row <- rows, do: :math.log(max(row.times, 0.1))
    :math.exp(Enum.sum(logs) / length(logs))
  end

  defp tick(value) when value >= 1, do: Integer.to_string(round(value))
  defp tick(value), do: Float.to_string(value)

  defp number(value) when is_integer(value), do: Integer.to_string(value)
  defp number(value) when value >= 10, do: :erlang.float_to_binary(value / 1, decimals: 1)
  defp number(value), do: :erlang.float_to_binary(value / 1, decimals: 2)

  defp escape(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
