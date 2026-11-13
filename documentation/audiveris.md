# Setting up Audiveris

`mix mx.scan` reads the music on a scanned page with Audiveris, an open source optical music recognition program under the AGPL v3.
mx runs it as a separate program and ships none of its code, so it is installed apart from mx.
This runbook sets up Audiveris 5.11.0 on macOS on Apple silicon, the setup the tests and the example were made with.

## Install Audiveris

Download the installer from the releases page, https://github.com/Audiveris/audiveris/releases, which also holds installers for Linux and Windows:

```sh
curl -L -o audiveris.dmg https://github.com/Audiveris/audiveris/releases/download/5.11.0/Audiveris-5.11.0-macosx-arm64.dmg
```

The disk image asks you to accept the AGPL before it mounts, so pipe `yes` into it from a terminal, or open it in Finder and click Agree:

```sh
mkdir audiveris-mnt
yes | hdiutil attach -nobrowse -quiet -mountpoint ./audiveris-mnt audiveris.dmg
cp -R audiveris-mnt/Audiveris.app /Applications/
hdiutil detach -quiet audiveris-mnt
```

The app carries its own Java runtime, so no Java needs installing.

## Check that mx finds it

mx looks for Audiveris in this order:

- the program named in the `AUDIVERIS` environment variable;
- `audiveris` on the path;
- `/Applications/Audiveris.app/Contents/MacOS/Audiveris`, where the macOS installer puts it.

Run it once from the terminal; it prints its command line options:

```sh
/Applications/Audiveris.app/Contents/MacOS/Audiveris -help
```

On Linux or Windows, or with the app somewhere else, set `AUDIVERIS` to the program, such as `export AUDIVERIS=/path/to/Audiveris`.

## Install the OCR languages

Audiveris reads part names, lyrics and tempo words with Tesseract, and ships no languages for it.
Without them it logs "No installed OCR languages", reads lyrics as dynamics, and names every part "Voice".
Download the languages your scores use, here English, German and Italian, into Audiveris's tessdata folder:

```sh
dir="$HOME/Library/Application Support/AudiverisLtd/audiveris/tessdata"
mkdir -p "$dir"
for lang in eng deu ita; do
  curl -L -o "$dir/$lang.traineddata" "https://github.com/tesseract-ocr/tessdata/raw/main/$lang.traineddata"
done
```

Audiveris logs "Installed OCR languages: deu,eng,ita" when it starts, which `mix mx.scan` keeps in `audiveris.log` beside the pages.
`TESSDATA_PREFIX` names another folder, if the languages live elsewhere.

## Install poppler, for PDFs

`mix mx.scan` renders PDF pages with poppler's `pdftoppm` and counts them with its `pdfinfo`:

```sh
brew install poppler
```

Pages given as PNG, JPEG or TIFF images need no poppler.
The image work itself is done with Vix, which mx installs as a Hex dependency with a prebuilt libvips.

## Run the tests

The tests that run Audiveris are tagged `audiveris` and left out of a plain `mix test`.
They take two to three minutes:

```sh
mix test --only audiveris
```

## When a scan goes wrong

`mix mx.scan score.pdf` leaves a folder `score-pages` beside `score.mxl`, holding each page as Audiveris was given it, the `.omr` book Audiveris made of it, and Audiveris's logs.

- "mix mx.scan needs Audiveris": mx found no program in the three places above.
- "No installed OCR languages" in the log: install the languages above.
- "No target duration for measures ... please check time signatures" in the log: Audiveris missed the time signature, and the rhythms on that page are unreliable.
- A page named as having no music: Audiveris found no staff lines, as on a page of text, or the scan is too faint or too small; look at its image in the pages folder.
- Wrong notes in one part: Audiveris often misses the key signature after an old C clef, such as a soprano clef, so that part plays naturals for sharps or flats; compare the part's notes with the page.
- Handwritten scores, such as Bach's autographs, are not read at all.

To correct a page by hand, open its `.omr` book in Audiveris, fix the notes, export it as MusicXML, and import that with `mix mx.import`.

## Sources

- Audiveris's handbook: https://audiveris.github.io/audiveris/_pages/handbook/
- Its command line: https://audiveris.github.io/audiveris/_pages/guides/advanced/cli/
- Its OCR languages: https://audiveris.github.io/audiveris/_pages/install/languages/
- Tesseract's language data: https://github.com/tesseract-ocr/tessdata
