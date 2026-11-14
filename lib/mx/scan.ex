defmodule Mx.Scan do
  @moduledoc """
  Prepares scanned score pages for optical music recognition by Audiveris.

  A page is turned to grayscale and cropped to the paper, its paper evened to white, the ink showing through from the other side faded, scaled so its staff lines stand about 20 pixels apart, the spacing Audiveris asks for, levelled, and cropped to the columns its staves span.
  """

  alias Vix.Vips.{Image, Operation}

  @compile {:no_warn_undefined, [Image, Operation, Vix.Vips.Interpolate]}

  @spacing 20

  @doc "Prepares a page, and returns it with its staff line spacing before and after, and the degrees it was turned."
  def prepare(page) when is_struct(page, Image) do
    clean = page |> gray() |> crop() |> flatten() |> clean()
    before = spacing(clean)
    scaled = if before, do: scale(clean, @spacing / before), else: clean
    {level, angle} = straighten(scaled)
    staves = staves(level)
    {staves, %{before: before, after: spacing(staves), angle: angle}}
  end

  @doc "A page as one band of 8-bit gray."
  def gray(page) when is_struct(page, Image) do
    page =
      if Image.has_alpha?(page) do
        Operation.flatten!(page, background: [255.0])
      else
        page
      end

    page
    |> Operation.colourspace!(:VIPS_INTERPRETATION_B_W)
    |> Operation.extract_band!(0)
    |> Operation.cast!(:VIPS_FORMAT_UCHAR)
  end

  # The paper without the scanner bed around it.
  defp crop(gray) do
    border = border_level(gray)

    {:ok, {left, top, width, height}} =
      Operation.find_trim(gray, background: [border * 1.0], threshold: 30.0)

    if width < Image.width(gray) / 4 or height < Image.height(gray) / 4 do
      gray
    else
      Operation.extract_area!(gray, left, top, width, height)
    end
  end

  defp border_level(gray) do
    width = Image.width(gray)
    height = Image.height(gray)
    size = max(div(min(width, height), 50), 2)

    corners =
      for {left, top} <- [
            {0, 0},
            {width - size, 0},
            {0, height - size},
            {width - size, height - size}
          ] do
        gray |> Operation.extract_area!(left, top, size, size) |> Operation.avg!()
      end

    corners |> Enum.sort() |> Enum.at(2)
  end

  # The columns the staff lines span, which leaves out a neighbouring page past the gutter.
  defp staves(page) do
    width = Image.width(page)
    ink = Operation.relational_const!(page, :VIPS_OPERATION_RELATIONAL_LESS, [230.0])

    {:ok, gap} =
      Image.new_matrix_from_array(div(@spacing, 2), 1, [List.duplicate(255, div(@spacing, 2))])

    {:ok, mask} =
      Image.new_matrix_from_array(2 * @spacing, 1, [List.duplicate(255, 2 * @spacing)])

    # Joins staff lines a noisy scan has broken into dashes, before keeping the long runs.
    lines =
      ink
      |> Operation.morph!(gap, :VIPS_OPERATION_MORPHOLOGY_DILATE)
      |> Operation.morph!(gap, :VIPS_OPERATION_MORPHOLOGY_ERODE)
      |> Operation.morph!(mask, :VIPS_OPERATION_MORPHOLOGY_ERODE)
      |> Operation.morph!(mask, :VIPS_OPERATION_MORPHOLOGY_DILATE)

    {:ok, {columns, _rows}} = Operation.project(lines)

    counts = sums(columns)

    case counts
         |> Enum.map(&if(&1 >= sparse(counts), do: &1, else: 0))
         |> spans(@spacing)
         |> Enum.max_by(fn {first, last} -> last - first end, fn -> nil end) do
      {first, last} when last - first > width / 2 ->
        left = max(first - 3 * @spacing, 0)
        right = min(last + 3 * @spacing, width - 1)
        Operation.extract_area!(page, left, 0, right - left + 1, Image.height(page))

      _none ->
        page
    end
  end

  @doc """
  Cuts a prepared page into its systems, top to bottom, each the full width of the page.

  A system is the staves joined by a bar line running from each staff to the next, or a single staff joined to none.
  Each reaches halfway to its neighbours, but no further than six staff line spacings from its outer staff lines.
  """
  def systems(page) when is_struct(page, Image) do
    height = Image.height(page)
    ink = Operation.relational_const!(page, :VIPS_OPERATION_RELATIONAL_LESS, [160.0])

    systems =
      page
      |> Operation.relational_const!(:VIPS_OPERATION_RELATIONAL_LESS, [230.0])
      |> staves_in()
      |> Enum.chunk_while(
        [],
        fn
          staff, [] ->
            {:cont, [staff]}

          staff, [last | _] = system ->
            if joined?(ink, last, staff) do
              {:cont, [staff | system]}
            else
              {:cont, Enum.reverse(system), [staff]}
            end
        end,
        fn
          [] -> {:cont, []}
          system -> {:cont, Enum.reverse(system), []}
        end
      )
      |> Enum.map(fn staves -> {staves |> hd() |> elem(0), staves |> List.last() |> elem(1)} end)

    reach = 6 * @spacing

    systems
    |> Enum.with_index()
    |> Enum.map(fn {{top, bottom}, index} ->
      above = if index == 0, do: 0, else: div(elem(Enum.at(systems, index - 1), 1) + top, 2)

      below =
        if index == length(systems) - 1 do
          height
        else
          div(bottom + elem(Enum.at(systems, index + 1), 0), 2)
        end

      upper = max(above, top - reach)
      lower = min(below, bottom + reach)
      Operation.extract_area!(page, 0, upper, Image.width(page), lower - upper)
    end)
  end

  # The staves on the page, as the rows of their top and bottom lines. Each row is scored by the
  # long thin horizontal lines at it and at the four rows a staff line spacing below, and the
  # staves
  # are the best scoring rows at least half as good as the best, six spacings or more apart.
  # Beams are taken out first, as they are half a spacing thick and lie against the lines.
  defp staves_in(ink) do
    thick = div(@spacing, 2)
    {:ok, column} = Image.new_matrix_from_array(1, thick, List.duplicate([255], thick))

    beams =
      ink
      |> Operation.morph!(column, :VIPS_OPERATION_MORPHOLOGY_ERODE)
      |> Operation.morph!(column, :VIPS_OPERATION_MORPHOLOGY_DILATE)

    ink = Operation.boolean!(ink, Operation.invert!(beams), :VIPS_OPERATION_BOOLEAN_AND)

    {:ok, gap} =
      Image.new_matrix_from_array(div(@spacing, 2), 1, [List.duplicate(255, div(@spacing, 2))])

    {:ok, mask} =
      Image.new_matrix_from_array(2 * @spacing, 1, [List.duplicate(255, 2 * @spacing)])

    {:ok, {_columns, rows}} =
      ink
      |> Operation.morph!(gap, :VIPS_OPERATION_MORPHOLOGY_DILATE)
      |> Operation.morph!(gap, :VIPS_OPERATION_MORPHOLOGY_ERODE)
      |> Operation.morph!(mask, :VIPS_OPERATION_MORPHOLOGY_ERODE)
      |> Operation.morph!(mask, :VIPS_OPERATION_MORPHOLOGY_DILATE)
      |> Operation.project()

    # A line a pixel or two off its row, as on a page not quite level, still counts.
    rows = rows |> sums() |> List.to_tuple()
    last = tuple_size(rows) - 1

    near =
      for row <- 0..last,
          do: Enum.max(for at <- max(row - 2, 0)..min(row + 2, last), do: elem(rows, at))

    near = List.to_tuple(near)

    {spacing, scores} =
      (@spacing - 3)..(@spacing + 3)
      |> Enum.map(fn spacing ->
        scores =
          for top <- 0..(last - 4 * spacing)//1 do
            {Enum.sum(for line <- 0..4, do: elem(near, top + line * spacing)), top}
          end

        {spacing, scores}
      end)
      |> Enum.max_by(fn {_spacing, scores} ->
        scores |> Enum.map(&elem(&1, 0)) |> Enum.max(fn -> 0 end)
      end)

    best = scores |> Enum.map(&elem(&1, 0)) |> Enum.max(fn -> 0 end)

    scores
    |> Enum.filter(fn {score, _top} -> score > 0 and score >= best / 2 end)
    |> Enum.sort_by(&elem(&1, 0), :desc)
    |> Enum.reduce([], fn {_score, top}, staves ->
      if Enum.any?(staves, &(abs(&1 - top) < 6 * spacing)), do: staves, else: [top | staves]
    end)
    |> Enum.sort()
    |> Enum.map(&{&1, &1 + 4 * spacing})
  end

  # Two staves are one system when some column is inked all the way from one to the other, as a
  # bar line through both is.
  defp joined?(ink, {_top, bottom}, {top, _bottom}) do
    gap = top - bottom - 1

    if gap <= 0 do
      true
    else
      {:ok, {columns, _rows}} =
        ink
        |> Operation.extract_area!(0, bottom + 1, Image.width(ink), gap)
        |> Operation.project()

      columns |> sums() |> Enum.any?(&(&1 / 255 >= gap * 0.95))
    end
  end

  # A column crossed by less staff line than this is a gutter or a margin, whose few stray lines
  # stay far below the page's median column.
  defp sparse(counts) do
    crossed = counts |> Enum.filter(&(&1 > 0)) |> Enum.sort()
    if crossed == [], do: 1, else: Enum.at(crossed, div(length(crossed), 2)) * 0.15
  end

  # The stretches of columns crossed by a staff line, as first and last column, bridging gaps
  # narrower than a staff line spacing.
  defp spans(columns, gap) do
    columns
    |> Enum.with_index()
    |> Enum.filter(fn {count, _column} -> count > 0 end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.chunk_while(
      nil,
      fn
        column, nil -> {:cont, {column, column}}
        column, {first, last} when column - last <= gap -> {:cont, {first, column}}
        column, span -> {:cont, span, {column, column}}
      end,
      fn
        nil -> {:cont, nil}
        span -> {:cont, span, nil}
      end
    )
  end

  # Divides the page by its paper, found as the brightest gray around each point once the ink is
  # filtered out, so yellowing and a side darker than the other become an even white.
  defp flatten(gray) do
    width = Image.width(gray)
    height = Image.height(gray)
    small = Operation.shrink!(gray, 8.0, 8.0)

    paper =
      small
      |> Operation.rank!(9, 9, 80)
      |> Operation.gaussblur!(2.0)
      |> Operation.resize!(width / Image.width(small), vscale: height / Image.height(small))

    gray
    |> Operation.divide!(paper)
    |> Operation.linear!([255.0], [0.0])
    |> Operation.cast!(:VIPS_FORMAT_UCHAR)
  end

  # On paper still grayed after flattening, as by ink showing through from the other side, fades
  # everything paler than the threshold between ink and paper, then brings back the thin sharp
  # strokes that took, such as faint staff lines, which show-through is too blurred to be.
  # A page whose paper is already even is left alone, since fading would thin its strokes.
  defp clean(flat) do
    histogram = histogram(flat)
    threshold = otsu(histogram)
    grayed = Enum.sum(Enum.slice(histogram, (threshold + 1)..239//1)) / Enum.sum(histogram)

    if grayed < 0.1 do
      flat
    else
      faded = fade(flat, histogram, threshold)

      sharp =
        flat
        |> Operation.gaussblur!(1.5)
        |> Operation.subtract!(flat)
        |> Operation.linear!([-5.0], [275.0])
        |> Operation.cast!(:VIPS_FORMAT_UCHAR)

      faded
      |> Operation.relational!(sharp, :VIPS_OPERATION_RELATIONAL_LESS)
      |> Operation.ifthenelse!(faded, sharp)
    end
  end

  # Stretches the grays so the ink reaches black and everything paler than the threshold becomes
  # white.
  defp fade(flat, histogram, threshold) do
    black = percentile(histogram, 0.005)
    white = max(threshold, black + 1)
    scale = 255 / (white - black)

    flat
    |> Operation.linear!([scale], [-black * scale])
    |> Operation.cast!(:VIPS_FORMAT_UCHAR)
  end

  defp sums(projection) do
    projection |> Operation.cast!(:VIPS_FORMAT_DOUBLE) |> pixels(:double)
  end

  defp histogram(gray) do
    gray |> Operation.hist_find!() |> Operation.cast!(:VIPS_FORMAT_DOUBLE) |> pixels(:double)
  end

  defp otsu(histogram) do
    total = Enum.sum(histogram)

    sum =
      histogram
      |> Enum.with_index()
      |> Enum.map(fn {count, level} -> count * level end)
      |> Enum.sum()

    {_, best, _, _} =
      histogram
      |> Enum.with_index()
      |> Enum.reduce({0, 0, 0.0, 0.0}, fn {count, level}, {best_score, best, weight, below} ->
        weight = weight + count
        below = below + count * level
        above = total - weight

        if weight == 0 or above == 0 do
          {best_score, best, weight, below}
        else
          mean_below = below / weight
          mean_above = (sum - below) / above
          score = weight * above * (mean_below - mean_above) ** 2

          if score > best_score do
            {score, level, weight, below}
          else
            {best_score, best, weight, below}
          end
        end
      end)

    best
  end

  defp percentile(histogram, fraction) do
    total = Enum.sum(histogram)

    histogram
    |> Enum.scan(&(&1 + &2))
    |> Enum.find_index(&(&1 >= total * fraction))
  end

  # Turns the page by the angle that lines its staff lines up with the rows best, the one whose
  # rows differ most in how much ink they hold.
  defp straighten(page) do
    small = Operation.resize!(page, min(1.0, 1000 / Image.width(page)))
    ink = Operation.relational_const!(small, :VIPS_OPERATION_RELATIONAL_LESS, [128.0])

    coarse = Enum.map(-12..12, &(&1 * 0.25))
    coarse = best_angle(ink, coarse)
    fine = Enum.map(-5..5, &Float.round(coarse + &1 * 0.05, 2))
    angle = best_angle(ink, fine)

    if abs(angle) < 0.05 do
      {page, 0.0}
    else
      {Operation.rotate!(page, angle,
         background: [255.0],
         interpolate: Vix.Vips.Interpolate.new!("bicubic")
       ), angle}
    end
  end

  defp best_angle(ink, angles) do
    Enum.max_by(angles, fn angle ->
      rotated = if angle == 0, do: ink, else: Operation.rotate!(ink, angle, background: [0.0])
      {:ok, {_columns, rows}} = Operation.project(rotated)
      rows |> sums() |> Enum.map(&(&1 * &1)) |> Enum.sum()
    end)
  end

  @doc "The distance in pixels from one staff line to the next, or nil on a page without staves."
  def spacing(page) when is_struct(page, Image) do
    width = Image.width(page)
    height = Image.height(page)

    ink =
      page
      |> Operation.relational_const!(:VIPS_OPERATION_RELATIONAL_LESS, [215.0])
      |> pixels(:uchar)

    pairs =
      for step <- 1..40,
          column = div(width * trunc(20 + step * 1.5), 100),
          column < width,
          pair <- column_pairs(ink, width, height, column),
          do: pair

    case pairs do
      [] -> nil
      pairs -> mode(pairs)
    end
  end

  # The most common value counting its neighbours, since hand-ruled staves vary by a pixel or two.
  defp mode(values) do
    counts = Enum.frequencies(values)

    Enum.max_by(Map.keys(counts), fn value ->
      Enum.sum(for near <- (value - 1)..(value + 1), do: Map.get(counts, near, 0))
    end)
  end

  # The length of each thin black run plus the white run after it, when another black run follows.
  defp column_pairs(ink, width, height, column) do
    runs =
      0..(height - 1)
      |> Enum.map(&:binary.at(ink, &1 * width + column))
      |> Enum.chunk_by(& &1)
      |> Enum.map(&{hd(&1) > 0, length(&1)})

    runs
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.flat_map(fn
      [{true, line}, {false, gap}, {true, _}] when line <= 12 and gap >= 3 and gap <= 120 ->
        [line + gap]

      _other ->
        []
    end)
  end

  defp scale(page, factor) when abs(factor - 1) < 0.05, do: page

  defp scale(page, factor) do
    page
    |> Operation.resize!(factor, kernel: :VIPS_KERNEL_LANCZOS3)
    |> Operation.cast!(:VIPS_FORMAT_UCHAR)
  end

  defp pixels(image, :uchar), do: Image.write_to_binary(image) |> elem(1)

  defp pixels(image, :double) do
    {:ok, binary} = Image.write_to_binary(image)
    for <<value::float-native-64 <- binary>>, do: value
  end
end
