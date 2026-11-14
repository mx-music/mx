#!/bin/bash

# Dependencies: rg
# Run from the root of the project: scripts/lint.sh
# Flags: -t prints timings, -r runs only the ripgrep checks, -p skips credo.

APP=$(sed -nE 's/^[[:space:]]*app: :([a-z0-9_]+),.*/\1/p' mix.exs | head -1)

if [ -z "$APP" ]; then
  echo "Can't find 'app: :name' in mix.exs; run from the root of a Mix project" >&2
  exit 2
fi

# A flag to track if any linting check has failed.
# We'll exit with 1 if this flag is set to 1 at the end.
LINT_FAILED=0
SHOW_TIMING=0
RG_ONLY=0

# Names of stages that failed, surfaced in a final summary so the cause
# isn't hidden by trailing output of subsequent stages.
FAILED_STAGES=()

mark_failed() {
  LINT_FAILED=1
  FAILED_STAGES+=("$1")
}

if [[ " $* " == *" -t "* ]]; then
  SHOW_TIMING=1
fi

# Skip credo + mix checks; run only the ripgrep checks. Useful for fast local iteration.
if [[ " $* " == *" -r "* ]]; then
  RG_ONLY=1
fi

# ANSI Color Codes
BRIGHT_RED='\033[1;31m'
UNDERLINE='\033[4m'
DIM='\033[2m'
RESET='\033[0m'

# Skip running credo when passing -p
if [[ ! " $* " == *" -p "* ]] && [ "$RG_ONLY" -eq 0 ]; then
  local_start=$SECONDS
  credo_output=$(elixir --erl "-elixir ansi_enabled true" -S mix credo --strict 2>&1)
  mix_exit_code=$?

  if [ "$SHOW_TIMING" -eq 1 ]; then
    echo -e "${DIM}  mix credo --strict: $((SECONDS - local_start))s${RESET}" >&2
  fi

  if [ "$mix_exit_code" -ne 0 ]; then
    echo "$credo_output" >&2
    mark_failed "mix credo --strict"
  fi
fi

# A helper function to run a single lint check.
# It takes an error message, followed by the pattern and options for ripgrep.
# If a match is found, it prints the error message and the findings,
# and sets the LINT_FAILED flag.
#
# Usage: run_check "Error message" [rg-opts...] <pattern>
# Example: run_check "Avoid `dbg/2` in committed code" "dbg"
run_check() {
  if [ $# -lt 2 ]; then
    echo "Usage: run_check <error-message> [rg-opts...] <pattern>" >&2
    return 2
  fi

  local message="$1"
  shift

  local -a args=("$@")
  local arg_count=${#args[@]}
  local pattern="${args[$((arg_count - 1))]}"
  local -a rg_opts=("${args[@]:0:$((arg_count - 1))}")

  # Run rg, letting its output go directly to standard error, and capture rg's own errors.
  # The explicit '.' matters: with no path, rg searches stdin whenever stdin isn't a terminal.
  local rg_errors
  rg_errors=$( { rg --color=always -telixir -n "${rg_opts[@]}" -- "$pattern" . 2>&1 1>&3; } 3>&2 )
  local rg_exit_code=$?

  # A glob that matches no file in this app is a pass, not an error.
  if [ $rg_exit_code -eq 2 ] && [[ "$rg_errors" == *"No files were searched"* ]]; then
    rg_exit_code=1
  fi

  if [ $rg_exit_code -eq 0 ]; then
    # Match found! rg has already printed its colored output above.
    # Now, we just print our custom explanation.
    echo "│" >&2
    echo -e "└─ ❌ ${BRIGHT_RED}LINT ERROR: ${UNDERLINE}$message${RESET}" >&2
    echo "" >&2
    echo "" >&2
    mark_failed "$message"
  elif [ $rg_exit_code -gt 1 ]; then
    # An actual error occurred with the rg command itself.
    echo "⚠️  COMMAND FAILED for check: '$message'" >&2
    echo "rg arguments: rg -telixir -n ${rg_opts[*]} -- \"$pattern\"" >&2
    mark_failed "$message"
  fi
  # If rg_exit_code is 1 (no match), we do nothing, which is the correct "pass" behavior.
}

# run_check_list <message> [rg-opts …] [--] <word1> [word2 …]
run_check_list() {
  if [ $# -lt 2 ]; then
    echo "Usage: run_check_list <message> [rg-opts …] [--] <word1> [word2 …]" >&2
    return 2
  fi

  local message="$1"; shift
  local -a rg_opts=()

  # Parse any ripgrep options
  while [ $# -gt 0 ]; do
    case "$1" in
      --) shift; break ;;             # explicit end of options
      -g|--glob)                      # flags that take an argument
        rg_opts+=( "$1" "$2" )
        shift 2
        ;;
      -*)                             # any other single-token flag
        rg_opts+=( "$1" )
        shift
        ;;
      *)                              # first non-flag → done with opts
        break
        ;;
    esac
  done

  # Now everything left is the list of words
  if [ $# -lt 1 ]; then
    echo "Error: no words provided to check" >&2
    return 2
  fi
  local -a list=( "$@" )

  # Build the alternation: word1|word2|...
  local joined
  joined=$(printf '%s|' "${list[@]}")
  joined=${joined%"|"}

  # PCRE2 regex with word boundaries
  local regex="\\b(?:${joined})\\b"

  # Finally invoke your run_check helper with -P
  run_check "$message" "${rg_opts[@]}" -P "$regex"
}

# --- Start of Linting Checks ---

RG_START=$SECONDS

# Debug
run_check "Avoid 'dbg/2'; it's a debugging tool and should not be committed." 'dbg'
run_check "Avoid 'IEx.pry/0' or 'IEx.break!/2'; they are for interactive debugging only." 'IEx\.(pry|break!)'
run_check "Avoid 'IO.inspect/2'; use a proper logger for application code." -g '!scripts/*.exs' -g '!notebooks/**/*.livemd' 'IO\.inspect'
run_check "Remove 'WIP' or 'wip' markers before committing." '\bwip\b'
run_check "Don't leave TODOs in the codebase; track them as tickets instead." 'TODO'
run_check "Avoid 'Kernel.binding/1' in application code; it is for debugging." -g "lib/**/*" 'binding\(\)'
run_check "No open browser calls" 'open_browser'

# Elixir
# lib/mx/synths.ex turns the names in the synthdef files mx ships into atoms.
run_check "Avoid unsafe atom interpolation" -g '!test/**/*' -g '!lib/mx/synths.ex' -P ":\".*#"
run_check "Avoid unsafe atom interpolation" -g '!test/**/*' -g '!lib/mx/synths.ex' "String\.to_atom"

run_check "Use do_ prefix for private functions only" "def do_"
run_check "Drop the '_of'/'_for'/'_with'/'_on' suffix: 'operators_for(data_type)' -> 'operators(data_type)'. Front the qualifier only if the bare name is ambiguous: 'rules_for(house)' -> 'house_rules(house)'" "defp?\s[a-z0-9_]+_(with|for|of|on)\("
# Mx.Definitions defines def itself, so it names Kernel.def with parentheses.
run_check "Do def function..., not def(function)..." -g '!lib/mx/definitions.ex' "defp?\([a-z]"
run_check "Use 'not' instead of '!' with boolean calls / values" "\!(is_|([A-Za-z]+\.)*[a-z_]+\?)"

run_check "Don't use parentheses" -U "\s+(attr|field|belongs_to|embeds_one|embeds_many|has_one|has_many|slot|add|modify|remove|config)\(\:"
run_check "Use '~r/.../' or '~r\"...\"' for regex sigils" '~r[\[\{\(\|''<]'
run_check "Don't use '~R'/'~W'; use lowercase '~r'/'~w'" '~[RW][\[\{\(\|/<"'"'"']'
run_check "Use '~s(...)' for string sigils, or simply use double quotes" '~s[\[\{\/\|''<"]'
run_check "Only use '~s(...)' when you have double quotes inside" -P '~s\((?![^)]*")[^)]*\)'
run_check "Don't use '~S', use '~s'" '~S[\[\{\/\|\(''<]'
run_check "Use '~D[...]', '~N[...]', '~U[...]', '~T[...]' for date/time sigils" '~[NDUT][\"\/\|(\{<]'
run_check "Use '~w(...)' for word list sigils" '~w[\[\{\/\|''<"]'
run_check "Use ~c\"...\" for charlists" '~c[\[\{\(\|''<\/]'
run_check "Write 'for x <- xs, do: ...', not 'for(...)'; bind the result to a variable first, or use a do/end block" '\bfor\('
run_check "Use 'in' operator instead of 'Enum.member?/2'" 'Enum\.member'
run_check "Use 'in' operator instead of 'MapSet.member?/2'" 'MapSet\.member'
run_check "Define '@impl true' only once before the first function clause" -PU '(?s)@impl\s+true\s*\R\s*defp?\s+([a-z_]\w*[!?]?)\s*(\([^)]*\)).*?@impl\s+true\s*\R\s*defp?\s+\1\s*\2'
run_check "Don't 'alias' self, use '__MODULE__' instead" '^\s*alias __MODULE__$'
run_check "Use 'filename' instead of 'file_name'" 'file_name'
run_check "Add space between parentheses and do" "\)do"

run_check "Don't use 'Map.get/2'. Use 'map[key]', 'Map.fetch!/2' or 'struct.field' instead" -PU 'Map\.get\([a-z_"@:\.]+\,\s[a-z_"@:\.]+\)'
run_check "Remove 'else nil', it's the default" -PU -B 5 "\selse(\s+nil\s+end|:\snil)"
run_check "Using with '<-' expects a pattern matching on the left side" -P '^(?m)\s*(?:with\b\s*|,\s*)(?!(?:nil|true|false)\b)(?:[a-z_]\w*|_)\s*<-'
run_check "Using with '<-' expects a pattern matching on the left side" -PU "(?ms)(?:^\s*|[=(]\s*)with\b(?:(?!\bdo\b).)*\K^\s*(?!(?:nil|true|false)\b)(?:[a-z_]\w*|_)\s*<-"

run_check "Use/import/alias/require/defstruct/defexception should be after @behaviour" -PU '^\s*(use|import|alias|require|defstruct|defexception)\b[^\n]*\n\s*@behaviour\b'
run_check "Import should be after use" -PU '^\s*import\b[^\n]*\n\s*use\b'
run_check "Alias should be after use and import" -PU '^\s*alias\b[^\n]*\n\s*(?:use|import)\b'
run_check "Require should be after use/import/alias" -PU '^\s*require\b[^\n]*\n\s*(?:use|import|alias)\b'
run_check 'Define use/import/alias/require at the top' -PU '\"\"\"[\s\S]*\"\"\"(*SKIP)(*FAIL)|^\s*(?:def|defp|defstruct|defexception|defguard|defguardp|defn|defnp)\s(?:(?!\b(?:defmodule|quote|defimpl)\b|\"\"\")[\s\S])*?\n\s+(?:use|import|alias|require)\s'
# Modules that MAY be fully imported (`import Mod` with no `only:`/`except:`).
# The app's own modules should be refined to `import Mod, only: [...]`.
IMPORT_ALLOWLIST=(
  'ExUnit\.[\w.]+'
  'Bitwise'
  # The notation every song file uses.
  'Mx'
)
IMPORT_ALLOW=$(printf '%s|' "${IMPORT_ALLOWLIST[@]}")
IMPORT_ALLOW=${IMPORT_ALLOW%"|"}
run_check "Use 'import Mod, only: [...]' instead of a bare 'import Mod'; only allowlisted modules (see IMPORT_ALLOWLIST in lint.sh) may be fully imported" \
          -P -g 'lib/**' -g 'test/**' \
          "^\s*import\s+(?!(?:${IMPORT_ALLOW})\s*(?:#.*)?\$)[A-Z][\w.]*\s*(?:#.*)?\$"

run_check "Don't pipe to blocks, use then, or extract a function" '\|> (case|cond|if) do'
run_check "Don't use if inside string interpolations, extract a variable" '#\{if'
run_check "Don't use if within concatentations, extract a variable" "\+\+\s+if[\(\s]"
run_check "Don't use 'unless', use 'if' with a negated condition" '^\s*unless.*do'
run_check "Don't use case true/false, use if/else" -PU '(?ms)^\s*case\b.*?do\b\s*\n(?=(?:[^\n]*\n)*?\s*true\s*->)(?=(?:[^\n]*\n)*?\s*false\s*->)(?!(?:[^\n]*\n)*?\s*(?!true\b|false\b)\w+\s*->).*?\s*end\b'
run_check "Don't wrap keyword-list 'if/def ..., do:' across lines; use a block form with do/else/end" -PU '\b(if|defp?)\b[^\n]*,\s*\n\s*do:'
run_check "Don't use 'apply'; call the function directly, or pass a capture like '&Mod.fun/2' and call it with 'fun.(...)'" \
          -g "!lib/${APP}_web.ex" \
          -P '(?:^\s*def\s+apply\b.*|\.apply\s*\(|\w+_apply\s*\()(*SKIP)(*FAIL)|(?:\bKernel\.)?apply\s*\('

run_check 'Use &function/1 instead of &function(&1)' "&[a-z_]+\(&1\)"
run_check "Don't pipe inside a capture like '&(&1 |> foo() |> bar())'; extract a named function or split the outer pipeline into steps" '&\(&\d+(\.\w+)* \|>'

run_check "Use to_timeout/1" ":timer\.(seconds|minutes|hours)"
run_check "Avoid sleep, if you really need, use Process.sleep" ":timer\.sleep"

run_check "Avoid ':persistent_term.put/2'; it has global VM-wide side effects" \
          -g '!lib/mx/synth.ex' \
          -g '!lib/mx/synths.ex' \
          -g '!lib/mx/transcriber.ex' \
          -g '!test/mx/instrument_song_test.exs' \
          ':persistent_term\.put'

run_check 'Use index, not idx' 'idx'
# Note names (c4, eb3), dynamics (mf, ff), up and Pa are music's own words.
SHORT_NAME='(?!(?:id|by|to|at|db|op|ok|js|ip|fx|on|hz|ms|us|f0|v\d+|[a-g][sb]?\d|pp|mp|mf|ff|up|pa)\b)[a-z]{1,2}\d*'
run_check "Use a descriptive variable name: 'global = insert(:global)', not 'g = insert(:global)', 'g1 = ...' or '%{global: g} = ...'" \
          -P "^\s*(?:${SHORT_NAME}|[%{\[](?:[^=\n]|=>)*?[\s{\[,]${SHORT_NAME}\s*[,}\]](?:[^=\n]|=>)*) = "
run_check "Use a descriptive variable name in 'for' generators: 'for global <- globals', not 'for g <- globals' or 'for i <- 1..5'" \
          -P "\bfor\s+(?:${SHORT_NAME}|[%{\[](?:(?!<-)[^\n])*?[\s{\[,]${SHORT_NAME}\s*[,}\]](?:(?!<-)[^\n])*?)\s*<-"
run_check "Use a descriptive variable name in assertion patterns: 'assert {:ok, global} = ...', not 'assert {:ok, g} = ...'" \
          -P "^\s*(?:assert|assert_receive|assert_received)\s+(?:${SHORT_NAME}\s+=(?![=~>])|[%{\[](?:[^=\n]|=>)*?[\s{\[,]${SHORT_NAME}\s*[,}\]](?:[^=\n]|=>)*?(?:\s=(?![=~>])|\s*$))"
run_check "Use a descriptive parameter name in function heads: 'def label(global)', not 'def label(g)'" \
          -P "^\s*(?:defp?|defmacrop?)\s+[a-z_]\w*[?!]?\((?:(?:(?!\)\s*(?:,\s*do:|do\b|when\b))[^\n])*?[\s(,{\[])?${SHORT_NAME}\s*(?:[,)}\]]|\\\\\\\\)"
run_check 'Avoid # === or # ---, prefer simple comments' '# [-─=]{2,}'
# A comment of one word, such as a URL, may run past.
run_check "Wrap comments at 98 columns, the formatter's line length" -P '^(?=.{99,}$)\s*#.*\S\s+\S'
run_check 'Exclude commented out tests' -g 'test/**/*.exs' "^\s+#\s+(describe|test)\s\""
run_check 'Exclude unused code, do not comment it out' -P "^\s+(#\s+defp?\s|<%!--\s<)"

# Tests
run_check "Don't mutate global Application env (put_env/delete_env) in 'async: true' tests; it races with other async tests. Split these into an 'async: false' file" \
          -PU -g 'test/**/*.exs' \
          '(?s)^\s*use\b[^\n]*async:\s*true[\s\S]*?Application\.(?:put_env|delete_env)'

run_check "Don't call 'Logger.configure' in 'async: true' tests; the logger level is global and races with other async tests. Move these into an 'async: false' file" \
          -PU -g 'test/**/*.exs' \
          '(?s)^\s*use\b[^\n]*async:\s*true[\s\S]*?Logger\.configure'
run_check "Do not leave empty describe/test blocks" -PU -g 'test/**/*' '(describe|test) ".*" do\s+end\b'

run_check "Use 'assert is_nil(...)' instead of 'assert nil = ...'" 'assert nil ='
run_check "Don't define modules inside 'test' blocks; define at the describe level to avoid 'redefining module' warnings on repeated runs" \
          -PU -g 'test/**/*' '(?m)^(\s+)test\b.+?\bdo\b\s*$\n(?:(?!\1end\b)(?![^\n]*\"\"\")[^\n]*\n){0,50}?\1\s+defmodule\b'

run_check "Avoid :capture_log, don't hide logs, but capture and assert them" "tag .?capture_log"
run_check "@tag consistency: :strong in debug-only and shouldn't be committed" -g '!test/support/commanded.ex' "tag consistency\: \:strong"
run_check "Use setup :step when defining only one step" -g "test/**/*.exs" "setup\s\[\:[a-z_]+\]"

run_check "Define each test module on its own file" -g "test/**/*.exs" -UP "defmodule[\s\S]+\ndefmodule"
run_check "Define alias on top of test file" -g "test/**/*.exs" -UP "(describe|test)\s\"[\s\S]+\n\s+alias\s[A-Z]"

# Typespecs
run_check "Don't use [...] in typespecs, use list() and nonempty_list()" '@(type|spec|callback)\b.*\['
run_check "Don't use [SomeModule.t()] in typespecs, use list(SomeModule.t())" '\[.*\.t\('
run_check "Don't use [map()] in typespecs, use list()" '\[map\('
run_check "Always end with nil when nullable in typespecs (e.g., '... | nil')" 'nil \| '
run_check "Use Keyword.t() instead of keyword()" 'keyword\(\)'
run_check "Use String.t() instead of binary()" ' binary\(\)'
run_check 'Type definitions without arguments should not use parentheses' -P "@type.*\(\)\s\:\:"
run_check "Don't append _t in typespecs, instead of @type music_t, simply use @type music" "@type [a-z_]+_t ::"

run_check "Don't use '@dialyzer'; fix the underlying type issue instead of suppressing warnings" '@dialyzer\b'

# moduledoc
run_check 'Modules with a @type must fill in @moduledoc' \
          -g '!test/**/*.exs' \
          -PU '(?ms)^\s*defmodule\s+[A-Z][\w.]*\s+do\R(?:(?!^\s*defmodule\b)[^\n]*\n)*?^\s*@moduledoc\s+false\b[^\n]*\n(?:(?!^\s*defmodule\b)[^\n]*\n)*?^\s*@type\b'

run_check 'Avoid defining @moduledoc for test files' -g 'test/**/*.exs' '@moduledoc'

run_check "Fill in a @moduledoc \"...\" for every module in lib/${APP}/" \
          -g "lib/${APP}/**/*.ex" \
          -PU '(?m)^\s*defmodule\b(?:(?!^\s*defmodule\b)[\s\S])*?^\s*@moduledoc\s+"(*SKIP)(*FAIL)|^\s*defmodule\b'

run_check "Describe every example module in a @moduledoc \"...\", not in comments above it" \
          -g 'examples/**/*.exs' \
          -PU '(?m)^defmodule\b(?:(?!^defmodule\b)[\s\S])*?^\s*@moduledoc\s+"(*SKIP)(*FAIL)|^defmodule\b'

# A line of one word, such as a URL, may run past.
run_check "Wrap example moduledocs at 98 columns, the formatter's line length" \
          -g 'examples/**/*.exs' \
          -PU '(?m)^[ \t]*@moduledoc """\n(?:(?![ \t]*""")[^\n]*\n)*?\K(?=[^\n]{99,}$)[ \t]*\S+[ \t]+\S[^\n]*$|^(?=[^\n]{99,}$)[ \t]*@moduledoc "'

# Env vars
run_check "Use Application config instead of reading/writing env vars directly in lib" \
          -g 'lib/**/*' \
          'System\.(get|fetch|put|delete)_env'

# Acronyms

ACRONYMS=(
  "ABC"
  "AIFC"
  "AIFF"
  "API"
  "BPM"
  "FFT"
  "FLAC"
  "FM"
  "HTML"
  "JPEG"
  "JSON"
  "MIDI"
  "MP3"
  "NIF"
  "OSC"
  "PDF"
  "PNG"
  "RIFF"
  "URI"
  "UTF"
  "VCSL"
  "VSCO"
  "WAV"
)

ACRONYMS_BAD_PATTERNS=()
for acronym in "${ACRONYMS[@]}"; do
  first_char="${acronym:0:1}"
  rest_chars="${acronym:1}"
  rest_chars_lower="$(printf '%s' "$rest_chars" | tr '[:upper:]' '[:lower:]')"
  ACRONYMS_BAD_PATTERNS+=( "${first_char}${rest_chars_lower}" )
done

ACRONYMS_JOINED=$(printf '%s|' "${ACRONYMS_BAD_PATTERNS[@]}")
ACRONYMS_JOINED=${ACRONYMS_JOINED%"|"}

# Matches whole words and PascalCase segments (CsvExport); camelCase names (responseMimeType)
# belong to JS or external APIs.
run_check \
  "Use 100%-uppercase acronyms (e.g. CPU, not Cpu), also inside names (CSVExport, not CsvExport)" \
  -P "\\b(?:[A-Z][A-Za-z0-9]*?(?<=[a-z0-9]))?(?:${ACRONYMS_JOINED})(?![a-z])"

# Typos

COMMON_TYPOS=(
  # Use the American version of "acknowledgment" instead of the British "acknowledgement"
  "acknowledgement"
)

run_check_list "Typo found" "${COMMON_TYPOS[@]}"

if [ "$SHOW_TIMING" -eq 1 ]; then
  echo -e "${DIM}  ripgrep checks: $((SECONDS - RG_START))s${RESET}" >&2
fi

# --- Mix analysis checks (excluding dialyzer) ---

run_mix_check() {
  local label="$1"
  shift

  local start=$SECONDS
  local output

  # Force ANSI colors for mix commands even when captured (no TTY)
  if [ "$1" = "mix" ]; then
    shift
    output=$(elixir --erl "-elixir ansi_enabled true" -S mix "$@" 2>&1)
  else
    output=$("$@" 2>&1)
  fi
  local exit_code=$?

  if [ "$exit_code" -ne 0 ]; then
    echo "$output" >&2
    echo -e "│" >&2
    echo -e "└─ ❌ ${BRIGHT_RED}LINT ERROR: ${UNDERLINE}$label${RESET}" >&2
    echo "" >&2
    mark_failed "$label"
  fi
  if [ "$SHOW_TIMING" -eq 1 ]; then
    echo -e "${DIM}  $label: $((SECONDS - start))s${RESET}" >&2
  fi
}

if [ "$RG_ONLY" -eq 0 ]; then
  run_mix_check "mix format --check-formatted"        mix format --check-formatted
  run_mix_check "mix ex_dna"                           mix ex_dna
  run_mix_check "public functions without a @doc"      mix run --no-start scripts/undocumented.exs
  run_mix_check "mix xref graph (compile-connected cycles)" mix xref graph --format cycles --label compile-connected --fail-above 0
fi

# Allows running custom / experimental checks locally
if [ -n "$LINT_CUSTOM" ]; then
  if [ -f "$LINT_CUSTOM" ]; then
    # shellcheck source=/dev/null
    source "$LINT_CUSTOM"
  else
    echo -e "${BRIGHT_RED}⚠️  LINT_CUSTOM is set, but file not found: $LINT_CUSTOM${RESET}" >&2
    mark_failed "LINT_CUSTOM file not found"
  fi
fi

# Final exit status check
if [ "$LINT_FAILED" -ne 0 ]; then
  echo "" >&2
  echo -e "${BRIGHT_RED}Linting finished with errors. Failed stages (${#FAILED_STAGES[@]}):${RESET}" >&2
  for stage in "${FAILED_STAGES[@]}"; do
    echo -e "  ${BRIGHT_RED}✗${RESET} $stage" >&2
  done
  exit 1
else
  echo "Linting finished successfully. No issues found."
  exit 0
fi
