defmodule Mx.Collections do
  @moduledoc """
  The collections of recordings mx knows by name, so a song names a recording as
  `{collection, name}`.

  `:sonic_pi` is Sonic Pi's sample pack, whose samples are named by atoms:
  `{:sonic_pi, :loop_amen}`.
  Every other collection is a public GitHub repository pinned to a commit, whose files and folders
  are named by their path in it: `{:vcsl, "Idiophones/Struck Idiophones/Agogo Bells"}`.
  Karoryfer's and FreePats' instruments are a repository each, so each is a collection of its own,
  named after its family.
  """

  @github [
    freepats_button_accordion:
      {"freepats/button-accordion-HN", "d70d16456fd99305d1c24c612b205ab38846eb0f"},
    freepats_electric_guitar:
      {"freepats/electric-guitar-FSBS-clean", "192cf0d9bf2c4ba6ead8e3524ba3f78818e4fe91"},
    freepats_fm_piano: {"freepats/fm-piano1", "89a92d10b47aea841597408f5cf2e9c8164ecb00"},
    freepats_lately_bass: {"freepats/lately-bass", "e27530dec05161ec3b661e86f4feb2065e0675aa"},
    freepats_spanish_guitar:
      {"freepats/spanish-classical-guitar", "6f4eb1b092acc88f5448cea1a0001bd07b971af8"},
    freepats_synth_brass: {"freepats/synth-brass-1", "a2d2111daae3e45761c5cabd480f4c60258bd645"},
    freepats_synth_choir:
      {"freepats/synth-pad-choir", "b801f7fc3eee44f575cd480750aea4f6a16a07a9"},
    freepats_synth_percussion:
      {"freepats/synthesizer-percussion", "39bbabce8e0e10aa259d5d94fca329f668733185"},
    freepats_synth_square: {"freepats/synth-square", "6d204b085af42f023770a3add2eeea9f9dbc5f14"},
    freepats_synth_strings:
      {"freepats/synth-strings-1", "c0ecbfd69cc242703c6342fcb3a7ffe8cd493ec7"},
    freepats_upright_piano:
      {"freepats/upright-piano-KW", "570f6c60ed2eff67accad3b85d5b452e57a3ad28"},
    karoryfer_big_rusty_drums:
      {"sfzinstruments/karoryfer.big-rusty-drums", "f07ce00df34a46b6b08375be56fe116cf15782bc"},
    karoryfer_bigcat_cello:
      {"sfzinstruments/karoryfer-bigcat.cello", "6fd75fbfc1dbb3109bf26220ba1adea46188a18b"},
    karoryfer_black_and_green_guitars:
      {"sfzinstruments/karoryfer.black-and-green-guitars",
       "b3b3249d37dc977a1a297bd2dc053e6d9b6b805c"},
    karoryfer_caveman_cosmonaut:
      {"sfzinstruments/karoryfer.caveman-cosmonaut", "9de9bcfcbc6d2b20bea5c1116cd07a310febc339"},
    karoryfer_gogodze_phu:
      {"sfzinstruments/karoryfer.gogodze-phu-vol-i", "7452f62060cd3a468c78bc361d96a4dfb30879c9"},
    karoryfer_growly_bass:
      {"sfzinstruments/karoryfer.growlybass", "4f483268fc66b5a6d5781d421c0d11b8d08d3fc6"},
    karoryfer_horse_pulse:
      {"sfzinstruments/Karoryfer.HorsePulse", "6f4749d54512d762098ca726a3cbd13444562904"},
    karoryfer_merry_orks:
      {"sfzinstruments/karoryfer.272-merry-orks", "a437e2c02014e02710a104a6692193eab8672d0a"},
    karoryfer_shiny_guitar:
      {"sfzinstruments/karoryfer.shinyguitar", "57243cca85277dbcc120ce17c6178032f93c80f3"},
    karoryfer_sneaky_bass:
      {"sfzinstruments/karoryfer.sneakybass", "cc1a67e5c913678b85eaad1a3b5cb180d3be3e2d"},
    karoryfer_squid_pipes:
      {"sfzinstruments/karoryfer.squidpipes", "b258528c8f49d6389ec2b4ec04a8b10013169dd9"},
    karoryfer_swag_bass:
      {"sfzinstruments/karoryfer.swagbass", "9d10fcae71af1975988ddecd5af1c95d372c7355"},
    karoryfer_swirly_drums:
      {"sfzinstruments/karoryfer.swirly-drums", "c40dafe0011cb2e54c0c220ff0fa308a11fc60f5"},
    karoryfer_unruly_drums:
      {"sfzinstruments/karoryfer.unruly-drums", "9bf75c2a1392f190cd1c264645653629f0b3a097"},
    karoryfer_war_tuba:
      {"sfzinstruments/karoryfer.war-tuba", "5b62dd6ef6b00281bb734769e44a63f5e013018a"},
    karoryfer_weresax:
      {"sfzinstruments/karoryfer.weresax", "a4d756b21d2a573aca0d840cce7e71ba5effd4c6"},
    mridangam: {"yaxu/mrid", "5ba409cabb2893e6e8a52a15a2812c35585cdadb"},
    salamander:
      {"sfzinstruments/SalamanderGrandPiano", "3382bf9496bba2486f5ab0de55a264d1dfc38404"},
    vcsl: {"sgossner/VCSL", "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"},
    virtuosity_drums:
      {"sfzinstruments/virtuosity_drums", "9f04cf9a734527edfbb0a4eee1f674e45bbf71bc"},
    vsco: {"sgossner/VSCO-2-CE", "440300901dfe9275fd84e0b7763af1f8443ae62e"}
  ]

  @doc "The names of the collections, in alphabetical order."
  def names, do: Enum.sort([:sonic_pi | Keyword.keys(@github)])

  @doc """
  The repository and commit of a collection kept on GitHub, as `{repo, commit}`, or nil for Sonic
  Pi's pack and for a name that is no collection.
  """
  def github(name) when is_atom(name), do: @github[name]

  @doc "Whether a reference is written as `{collection, name}`, whatever the collection."
  def ref?({collection, name}) when is_atom(collection) and collection != :github do
    is_atom(name) or is_binary(name)
  end

  def ref?(_ref), do: false

  @doc """
  A reference to a file or folder of a collection kept on GitHub as
  `{:ok, {:github, repo, commit, path}}`, or `{:error, message}` for a collection mx does not have
  or a path that is no text.
  """
  def expand({:sonic_pi, _name}) do
    {:error, "Sonic Pi's pack has no files or folders; its samples are {:sonic_pi, name}"}
  end

  def expand({collection, path}) when is_atom(collection) do
    case @github[collection] do
      {repo, commit} when is_binary(path) and path != "" ->
        {:ok, {:github, repo, commit, path}}

      {_repo, _commit} ->
        path = inspect(path)
        {:error, "a file or folder of #{collection} is named by its path, not #{path}"}

      nil ->
        {:error, unknown(collection)}
    end
  end

  @doc "The message refusing a collection mx does not have."
  def unknown(collection) do
    names = Enum.join(names(), ", ")
    "mx has no collection #{collection}; its collections are #{names}"
  end
end
