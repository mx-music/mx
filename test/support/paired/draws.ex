defmodule Mx.Paired.Draws do
  @moduledoc """
  mxs's numbers drawn from a seed, SplitMix64, so a twin draws the same numbers as the Rust voice it is written from.
  """

  import Bitwise

  @mask 0xFFFF_FFFF_FFFF_FFFF

  @doc "`count` numbers from 0 up to 1, drawn from `seed`."
  def draws(seed, count) do
    {numbers, _} =
      Enum.map_reduce(1..count//1, seed, fn _, state ->
        state = state + 0x9E37_79B9_7F4A_7C15 &&& @mask
        mixed = bxor(state, state >>> 30) * 0xBF58_476D_1CE4_E5B9 &&& @mask
        mixed = bxor(mixed, mixed >>> 27) * 0x94D0_49BB_1331_11EB &&& @mask
        {bxor(mixed, mixed >>> 31) / @mask, state}
      end)

    numbers
  end

  @doc "The frequencies of a cymbal's plate as mxs draws them: `count` from `low` to `high` Hz, as likely in each octave, sorted and in groups of 20."
  def plate(count, low, high) do
    draws(1956, count)
    |> Enum.map(&(low * :math.pow(high / low, &1)))
    |> Enum.sort()
    |> Enum.chunk_every(20)
  end

  @doc "FunDSP's `rnd1`: a number from 0 up to 1 hashed from the integer `x`."
  def rnd1(bits) do
    bits = bxor(bits, 0x5555_5555_5555_5555)
    bits = bits * 0x9E37_79B9_7F4A_7C15 &&& @mask
    bits = bxor(bits, bits >>> 30) * 0xBF58_476D_1CE4_E5B9 &&& @mask
    bits = bxor(bits, bits >>> 27) * 0x94D0_49BB_1331_11EB &&& @mask
    (bxor(bits, bits >>> 31) >>> 11) * (1 / (1 <<< 53))
  end
end
