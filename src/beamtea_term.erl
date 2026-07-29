%%% @doc Low-level ANSI/VT terminal escape sequences.
%%%
%%% Every function returns an `iodata()' escape string that can be embedded
%%% directly in a view or written to the terminal. Kept deliberately small and
%%% dependency-free so it is trivial to unit-test on any platform.
-module(beamtea_term).

-export([alt_enter/0, alt_leave/0,
         hide_cursor/0, show_cursor/0,
         clear/0, clear_line/0, clear_below/0,
         home/0, move/2,
         reset/0, sgr/1,
         fg/1, bg/1, fg_rgb/3, bg_rgb/3, paint_rgb/2,
         bold/1, faint/1, italic/1, underline/1, reverse/1, paint/2,
         rule/1, rule/2]).

%%% ===================================================================
%%% Screen / cursor control
%%% ===================================================================

%% @doc Switch to the alternate screen buffer (like `vim'/`less').
-spec alt_enter() -> binary().
alt_enter() -> <<"\e[?1049h">>.

%% @doc Restore the primary screen buffer.
-spec alt_leave() -> binary().
alt_leave() -> <<"\e[?1049l">>.

-spec hide_cursor() -> binary().
hide_cursor() -> <<"\e[?25l">>.

-spec show_cursor() -> binary().
show_cursor() -> <<"\e[?25h">>.

%% @doc Clear the whole screen.
-spec clear() -> binary().
clear() -> <<"\e[2J">>.

%% @doc Clear from the cursor to the end of the current line.
-spec clear_line() -> binary().
clear_line() -> <<"\e[K">>.

%% @doc Clear from the cursor to the end of the screen.
-spec clear_below() -> binary().
clear_below() -> <<"\e[J">>.

%% @doc Move the cursor to the top-left corner.
-spec home() -> binary().
home() -> <<"\e[H">>.

%% @doc Move the cursor to a 1-indexed `{Row, Col}'.
-spec move(pos_integer(), pos_integer()) -> iodata().
move(Row, Col) ->
    [<<"\e[">>, integer_to_binary(Row), $;, integer_to_binary(Col), $H].

%%% ===================================================================
%%% Styling (SGR)
%%% ===================================================================

%% @doc Reset all attributes.
-spec reset() -> binary().
reset() -> <<"\e[0m">>.

%% @doc Build an SGR sequence from a list of numeric codes, e.g.
%% `sgr([1, 38, 5, 205])'.
-spec sgr([non_neg_integer()]) -> iodata().
sgr(Codes) ->
    [<<"\e[">>, lists:join($;, [integer_to_binary(C) || C <- Codes]), $m].

%% @doc 256-colour foreground.
-spec fg(0..255) -> iodata().
fg(N) -> sgr([38, 5, N]).

%% @doc 256-colour background.
-spec bg(0..255) -> iodata().
bg(N) -> sgr([48, 5, N]).

%% @doc 24-bit truecolor foreground.
-spec fg_rgb(0..255, 0..255, 0..255) -> iodata().
fg_rgb(R, G, B) -> sgr([38, 2, R, G, B]).

%% @doc 24-bit truecolor background.
-spec bg_rgb(0..255, 0..255, 0..255) -> iodata().
bg_rgb(R, G, B) -> sgr([48, 2, R, G, B]).

%% @doc Paint `Text' in a truecolor `{R, G, B}' foreground and reset.
-spec paint_rgb({0..255, 0..255, 0..255}, iodata()) -> iodata().
paint_rgb({R, G, B}, Text) -> paint([38, 2, R, G, B], Text).

-spec bold(iodata()) -> iodata().
bold(Text) -> paint([1], Text).

-spec faint(iodata()) -> iodata().
faint(Text) -> paint([2], Text).

-spec italic(iodata()) -> iodata().
italic(Text) -> paint([3], Text).

-spec underline(iodata()) -> iodata().
underline(Text) -> paint([4], Text).

-spec reverse(iodata()) -> iodata().
reverse(Text) -> paint([7], Text).

%% @doc Wrap `Text' in the given SGR codes and reset afterwards.
-spec paint([non_neg_integer()], iodata()) -> iodata().
paint(Codes, Text) -> [sgr(Codes), Text, reset()].

%% @equiv rule(Width, <<"─"/utf8>>)
-spec rule(non_neg_integer()) -> iodata().
rule(Width) -> rule(Width, <<"─"/utf8>>).

%% @doc A horizontal rule: `Glyph' repeated to `Width' columns.
-spec rule(non_neg_integer(), binary()) -> iodata().
rule(Width, Glyph) -> lists:duplicate(Width, Glyph).
