# beamtea 🍵

A delightful terminal UI framework for the BEAM — **[Bubble Tea](https://github.com/charmbracelet/bubbletea) for Erlang.**

beamtea brings [The Elm Architecture](https://guide.elm-lang.org/architecture/) to the terminal, built directly on OTP's `prim_tty`. You write three pure functions — `init`, `update`, `view` — and beamtea handles raw input, UTF-8 decoding, the alternate screen, resizing, timers, and a clean exit. It ships with **bubbles**: a set of high-level, reusable components inspired by [charmbracelet/bubbles](https://github.com/charmbracelet/bubbles), styled with an electric, Charm-inspired colour palette.

```erlang
-module(counter).
-behaviour(beamtea).
-export([main/0, init/1, update/2, view/1]).

main() -> beamtea:start(?MODULE).

init(_Flags) -> {0, beamtea:none()}.

update({key, up},           N) -> {N + 1, beamtea:none()};
update({key, down},         N) -> {N - 1, beamtea:none()};
update({key, {char, $q}},   N) -> {N, beamtea:quit()};
update(_Msg,                N) -> {N, beamtea:none()}.

view(N) ->
    ["\n  ", beamtea_color:fg(charmple, beamtea_term:bold(<<"counter">>)),
     "\n\n  ", integer_to_binary(N),
     "\n\n  ", beamtea_term:faint(<<"↑ up · ↓ down · q quit"/utf8>>), "\n"].
```

---

## Status — v0.1.0

Everything below is implemented and covered by tests (103 EUnit cases) plus PTY integration checks on macOS and Linux:

| Feature | ✓ |
|---|---|
| Raw single-key input | ✓ |
| UTF-8 text input | ✓ |
| Arrow keys (CSI + SS3) | ✓ |
| Elm-style `init`/`update`/`view` | ✓ |
| Commands and timers | ✓ |
| Alternate screen | ✓ |
| Cursor restoration | ✓ |
| Terminal resizing (SIGWINCH) | ✓ |
| Full-frame rendering | ✓ |
| Clean `q` / `Ctrl-C` exit | ✓ |
| Linux and macOS tests | ✓ |

Requires **Erlang/OTP 26+** (developed against OTP 29) and `rebar3`.

---

## Install

Add beamtea as a rebar3 dependency:

```erlang
%% rebar.config
{deps, [{beamtea, {git, "https://github.com/tsiry-sndr/beamtea.git", {tag, "0.1.0"}}}]}.
```

Or clone and build locally:

```console
git clone https://github.com/tsiry-sndr/beamtea.git
cd beamtea
rebar3 compile
rebar3 eunit
```

---

## Running a program

> **Important:** a full-screen TUI needs to *own* the terminal. Don't launch beamtea programs from inside `rebar3 shell` — the interactive Erlang shell keeps its own `prim_tty` on stdin and will fight beamtea for input (you'll see `stealing control of fd=0`), and `Ctrl-C` will hit the BEAM break handler.

Use the included launcher, which sets the terminal up correctly and restores it on exit:

```console
./bin/beamtea-run counter
# or
make run EXAMPLE=counter
```

Under the hood the launcher runs:

```console
stty -isig -ixon                       # Ctrl-C / Ctrl-S arrive as bytes, not signals
erl +Bi -noshell -noinput ... \        # disable the break handler; own the terminal
    -eval "counter:main(), halt()."
```

To ship your own app, do the same three things (or copy `bin/beamtea-run`): `stty -isig`, `erl +Bi -noshell -noinput`, and call `beamtea:start/1`.

---

## The Elm Architecture

A beamtea **program** is three functions. Provide them as a module implementing the `beamtea` behaviour, or as a map `#{init => F, update => F, view => F}`.

```erlang
init(Flags)        -> {Model, Cmd}.   %% initial model + first command
update(Msg, Model) -> {Model, Cmd}.   %% fold a message into the model
view(Model)        -> iodata().       %% render the whole screen
```

### Messages

`update/2` receives, from the runtime:

- `{key, Key}` — a keypress (see **Keys** below)
- `{resize, {Cols, Rows}}` — the terminal was resized

…plus any message produced by the commands you return.

### Commands

Return a command from `init/2` or `update/2` to ask the runtime to do something:

| Command | Constructor | Effect |
|---|---|---|
| do nothing | `beamtea:none()` | — |
| quit | `beamtea:quit()` | stop the program, return the final model |
| run many | `beamtea:batch([Cmd])` | run several commands |
| defer a message | `beamtea:msg(Msg)` | deliver `Msg` to `update/2` soon |
| one-shot timer | `beamtea:tick(Ms, Msg)` | deliver `Msg` after `Ms` ms |
| repeating timer | `beamtea:every(Ms, Msg)` | deliver `Msg` every `Ms` ms |
| async task | `beamtea:task(fun () -> Msg end)` | run in a process, deliver the result |

### Keys

`beamtea_key` decodes raw bytes into ergonomic key events:

- Named atoms: `up`, `down`, `left`, `right`, `enter`, `esc`, `tab`, `back_tab`, `backspace`, `delete`, `insert`, `home`, `'end'`, `page_up`, `page_down`
- `{ctrl, Letter}` — e.g. `Ctrl-C` is `{ctrl, $c}`
- `{char, CodePoint}` — a printable character, including space; a full Unicode code point so UTF-8 "just works" (build text with `<<Text/binary, CodePoint/utf8>>`)

### Options

`beamtea:start(Program, Flags, Opts)`:

- `alt_screen => boolean()` (default `true`) — use the alternate screen buffer
- `catch_ctrl_c => boolean()` (default `true`) — quit on `Ctrl-C` instead of passing it to `update/2`

---

## Bubbles — reusable components

Each bubble is a self-contained mini-program (`new`, `update`, `view`, plus accessors). Compose them: keep the bubble's model inside yours, forward messages to its `update/2`, and embed its `view/1`. Components that animate (spinner, timer, …) keep themselves running by re-scheduling their own tick — start them once from `init/1`.

| Module | Component | Highlights |
|---|---|---|
| `beamtea_spinner` | Spinner | 8 styles (`dot`, `line`, `moon`, `points`, …), self-animating |
| `beamtea_textinput` | Text input | UTF-8, caret, char limit, placeholder |
| `beamtea_textarea` | Text area | multi-line editing, cross-line backspace, scrolling |
| `beamtea_progress` | Progress bar | electric gradient fill, percentage |
| `beamtea_list` | Selectable list | arrow/`j`/`k` nav, scrolling window, title |
| `beamtea_table` | Data table | columns, row selection, scrolling, truncation |
| `beamtea_viewport` | Scrollable viewport | page/line/home/end scrolling, scroll % |
| `beamtea_paginator` | Paginator | dots or `N/M`, slice helper for the current page |
| `beamtea_keybind` | Key binding | match keys by intent, carry help text |
| `beamtea_help` | Help view | short (one line) and full (columns) help |
| `beamtea_timer` | Countdown timer | self-ticking, `timed_out/1` |
| `beamtea_stopwatch` | Stopwatch | self-ticking count-up |
| `beamtea_filepicker` | File picker | browse dirs, select files |
| `beamtea_cursor` | Blinking cursor | blink / static / hidden modes |

Example — wiring a spinner into your program:

```erlang
init(_) ->
    S = beamtea_spinner:new(dot),
    {#st{spin = S}, beamtea_spinner:tick(S)}.        %% start animating

update(Msg, St) ->
    {S1, Cmd} = beamtea_spinner:update(Msg, St#st.spin),
    {St#st{spin = S1}, Cmd}.

view(St) ->
    [beamtea_spinner:view(St#st.spin), " loading..."].
```

---

## Examples

Build once with `rebar3 as examples compile`, then run any of these with the launcher:

```console
./bin/beamtea-run <name>
```

| Name | Shows off |
|---|---|
| `counter` | the core loop — keys, model, view |
| `keys` | key inspector — arrows, Ctrl-combos, UTF-8, emoji |
| `stopwatch` | commands & timers via `beamtea:every/2` |
| `spinner_demo` | `beamtea_spinner` — cycle every style |
| `textinput_demo` | `beamtea_textinput` — a live greeting |
| `textarea_demo` | `beamtea_textarea` — a bordered multi-line editor |
| `progress_demo` | `beamtea_progress` — a self-filling gradient bar |
| `list_demo` | `beamtea_list` — a drink chooser |
| `table_demo` | `beamtea_table` — a sortable-looking framework table |
| `viewport_demo` | `beamtea_viewport` — scroll a long document |
| `timer_demo` | `beamtea_timer` — a 10-second countdown |
| `filepicker_demo` | `beamtea_filepicker` — browse the filesystem |
| `help_demo` | `beamtea_keybind` + `beamtea_help` + `beamtea_paginator` |

Most examples quit with `q`; the text-entry demos (`textinput_demo`, `textarea_demo`) quit with `Esc` or `Ctrl-C`.

---

## Colours

`beamtea_color` provides an electric, Charm-inspired palette mapped to xterm-256 indices. Reference a colour by name:

```erlang
beamtea_color:fg(hotpink, "hi")                     %% named foreground
beamtea_term:paint([38, 5, beamtea_color:c(charmple)], "hi")
```

Names include `charmple`, `purple`, `indigo`, `violet`, `hotpink`, `pink`, `magenta`, `cyan`, `aqua`, `teal`, `blue`, `green`, `lime`, `mint`, `yellow`, `gold`, `orange`, `coral`, `red`, and neutrals (`cloud`, `gray`, `dim`, `charcoal`). See `beamtea_color:names/0`.

Low-level escapes live in `beamtea_term`: `alt_enter/0`, `hide_cursor/0`, `move/2`, `sgr/1`, `bold/1`, `faint/1`, `reverse/1`, `paint/2`, …

> **Tip:** always tag non-ASCII binary literals with `/utf8` — `<<"↑ up"/utf8>>`, not `<<"↑ up">>`. Without it the compiler byte-truncates each code point into garbage. beamtea's renderer also accepts plain Unicode code-point lists (`"↑ up"`), so either works.

---

## Testing

```console
rebar3 eunit        # 103 unit tests (pure logic: key parsing, rendering, commands, every bubble)
rebar3 xref         # cross-reference checks
```

The unit tests are pure and run identically on Linux and macOS. Terminal behaviour (raw mode, alt screen, arrow keys, UTF-8, Ctrl-C, clean restore) is verified separately by driving real programs through a PTY.

## Documentation

Every module is annotated with `@doc`/`-spec`. Generate browsable HTML API docs into `./doc`:

```console
rebar3 edoc         # or: make docs
open doc/index.html
```

---

## Project layout

```
src/
  beamtea.erl            public API, behaviour, command constructors
  beamtea_runtime.erl    the event loop that owns the terminal
  beamtea_key.erl        raw bytes -> key events
  beamtea_term.erl       ANSI / VT escape sequences
  beamtea_render.erl     full-frame rendering
  beamtea_cmd.erl        command -> effects (pure)
  beamtea_color.erl      electric colour palette
  beamtea_util.erl       shared helpers (time formatting, padding, ANSI width)
  beamtea_*.erl          the bubbles (spinner, textinput, table, …)
examples/                runnable example programs
bin/beamtea-run          the launcher
test/                    EUnit suites
```

---

## Why a launcher, and how Ctrl-C works

`prim_tty`'s raw mode keeps `ISIG` enabled — exactly as the Erlang shell does — so `Ctrl-C` would normally become a `SIGINT` handled by the BEAM break handler (`BREAK: (a)bort ...`), hanging the UI. The BEAM reserves `SIGINT` (you cannot `os:set_signal(sigint, handle)`), so beamtea instead:

1. runs with `+Bi` to disable the break handler, and
2. disables `ISIG` on the terminal (via `stty -isig` in the launcher) so `Ctrl-C` arrives as a plain `0x03` byte.

`prim_tty` preserves that setting, so the runtime sees `{ctrl, $c}` and quits cleanly, restoring cooked mode, the cursor, and the primary screen on the way out. Running with `-noshell -noinput` makes beamtea the sole owner of stdin, avoiding any conflict with the interactive shell.

---

## License

MIT © 2026 Tsiry Sandratraina. See [LICENSE](LICENSE).
