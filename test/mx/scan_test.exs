defmodule Mx.ScanTest do
  use ExUnit.Case, async: true

  alias Mx.Scan
  alias Vix.Vips.{Image, Operation}

  @page "test/support/scans/chorale-150dpi.png"

  setup_all do
    {:ok, page} = Image.new_from_file(@page)
    %{page: Scan.gray(page)}
  end

  test "a page scanned at 150 DPI is enlarged so its staff lines stand 18 to 22 pixels apart", %{
    page: page
  } do
    {prepared, info} = Scan.prepare(page)

    assert info.before in 6..9
    assert info.after in 18..22
    assert Scan.spacing(prepared) in 18..22
  end

  test "a page rotated by 2 degrees is straightened by about 2 degrees", %{page: page} do
    {_prepared, info} = page |> Operation.rotate!(2.0, background: [255.0]) |> Scan.prepare()

    assert_in_delta abs(info.angle), 2.0, 0.2
  end

  test "a level page is not turned", %{page: page} do
    {_prepared, info} = Scan.prepare(page)

    assert info.angle == 0.0
  end

  test "a page with its right half darkened by a third comes out with even paper", %{page: page} do
    {prepared, _info} = page |> darken_right_half() |> Scan.prepare()

    assert_in_delta paper(prepared, :left), paper(prepared, :right), 3
    assert paper(prepared, :right) > 245
  end

  test "yellowed paper with ink showing through from the other side comes out white, with the staff lines kept",
       %{page: page} do
    {prepared, info} = page |> show_through() |> yellow() |> Scan.prepare()

    assert Image.bands(prepared) == 1
    assert paper(prepared, :left) > 245
    assert paper(prepared, :right) > 245
    assert info.after in 18..22
  end

  test "a prepared page is grayscale, keeping its shades", %{page: page} do
    {prepared, _info} = Scan.prepare(page)

    assert Image.bands(prepared) == 1
    assert Image.format(prepared) == :VIPS_FORMAT_UCHAR

    {:ok, histogram} = prepared |> Operation.hist_find!() |> Image.write_to_binary()

    shades =
      for <<count::unsigned-native-32 <- histogram>>,
        reduce: 0,
        do: (n -> if count > 0, do: n + 1, else: n)

    assert shades > 2
  end

  test "a chorale page is cut into its three systems of four staves", %{page: page} do
    {prepared, _info} = Scan.prepare(page)

    systems = Scan.systems(prepared)

    assert length(systems) == 3
    assert Enum.all?(systems, &(Image.height(&1) > 16 * 20))
  end

  test "a photocopied piano page is cut into its six systems of two staves" do
    assert "test/support/scans/rag-photocopy-2.png" |> heights() |> length() == 6
  end

  test "a photographed piano page is cut into its two systems, each holding both staves" do
    assert [first, second] = heights("test/support/scans/rag-photo-3.jpg")
    assert first > 20 * 20 and second > 20 * 20
  end

  defp heights(path) do
    {:ok, page} = Image.new_from_file(path)
    {prepared, _info} = Scan.prepare(page)
    prepared |> Scan.systems() |> Enum.map(&Image.height/1)
  end

  defp darken_right_half(page) do
    width = Image.width(page)

    factor =
      Operation.xyz!(width, Image.height(page))
      |> Operation.extract_band!(0)
      |> Operation.relational_const!(:VIPS_OPERATION_RELATIONAL_MORE, [width / 2])
      |> Operation.linear!([-1 / 3 / 255], [1.0])

    page |> Operation.multiply!(factor) |> Operation.cast!(:VIPS_FORMAT_UCHAR)
  end

  defp show_through(page) do
    back =
      page
      |> Operation.flip!(:VIPS_DIRECTION_HORIZONTAL)
      |> Operation.gaussblur!(1.5)
      |> Operation.linear!([0.35], [255 * 0.65])

    page
    |> Operation.multiply!(back)
    |> Operation.linear!([1 / 255], [0.0])
    |> Operation.cast!(:VIPS_FORMAT_UCHAR)
  end

  defp yellow(page) do
    [0.93, 0.82, 0.6]
    |> Enum.map(&Operation.linear!(page, [&1], [0.0]))
    |> Operation.bandjoin!()
    |> Operation.cast!(:VIPS_FORMAT_UCHAR)
    |> Operation.copy!(interpretation: :VIPS_INTERPRETATION_sRGB)
  end

  # The most common gray in a strip down one side, which on a page of music is its paper.
  defp paper(page, side) do
    width = div(Image.width(page), 4)
    left = if side == :left, do: width, else: 2 * width
    strip = Operation.extract_area!(page, left, 0, width, Image.height(page))
    {:ok, histogram} = strip |> Operation.hist_find!() |> Image.write_to_binary()
    counts = for <<count::unsigned-native-32 <- histogram>>, do: count
    counts |> Enum.with_index() |> Enum.max_by(&elem(&1, 0)) |> elem(1)
  end
end
