%%% @doc A composable styling layer, inspired by charmbracelet/lipgloss.
%%%
%%% A style is an immutable set of visual properties (colours, weight, padding,
%%% border, alignment, size). You build one up with chained setters — each
%%% returns a new style — and {@link render/2} applies it to text:
%%%
%%% ```
%%%   S = beamtea_style:border(
%%%         beamtea_style:padding(
%%%           beamtea_style:foreground(beamtea_style:new(), pink), {1, 2}),
%%%         rounded),
%%%   beamtea_style:render(S, <<"Hello">>).
%%% '''
%%%
%%% Styles compose: {@link merge/2} layers one over another, and
%%% {@link join_horizontal/2} / {@link join_vertical/2} arrange rendered blocks
%%% side-by-side or stacked — the building blocks for panels, button rows and
%%% modals. Colours may be a named {@link beamtea_color} atom, an xterm-256
%%% integer, or a truecolor `{R,G,B}' triple.
-module(beamtea_style).

-export([new/0, new/1,
         foreground/2, background/2,
         bold/1, faint/1, italic/1, underline/1, reverse/1,
         width/2, height/2, align/2, valign/2,
         padding/2, margin/2, border/2, border_foreground/2,
         merge/2, render/2,
         join_horizontal/2, join_vertical/2]).

-export_type([style/0, color/0]).

-type color() :: beamtea_color:name() | 0..255 | {0..255, 0..255, 0..255}.
-type box() :: non_neg_integer()
             | {non_neg_integer(), non_neg_integer()}
             | {non_neg_integer(), non_neg_integer(),
                non_neg_integer(), non_neg_integer()}.
-type style() :: map().

%%% ===================================================================
%%% Construction / setters (style is the first arg, returns a new style)
%%% ===================================================================

%% @doc An empty style.
-spec new() -> style().
new() -> #{}.

%% @doc A style from a property map (same keys the setters use).
-spec new(map()) -> style().
new(Map) when is_map(Map) -> Map.

-spec foreground(style(), color()) -> style().
foreground(S, Color) -> S#{fg => Color}.

-spec background(style(), color()) -> style().
background(S, Color) -> S#{bg => Color}.

-spec bold(style()) -> style().
bold(S) -> S#{bold => true}.

-spec faint(style()) -> style().
faint(S) -> S#{faint => true}.

-spec italic(style()) -> style().
italic(S) -> S#{italic => true}.

-spec underline(style()) -> style().
underline(S) -> S#{underline => true}.

-spec reverse(style()) -> style().
reverse(S) -> S#{reverse => true}.

%% @doc Fix the content width (columns); shorter lines are padded per
%% {@link align/2}, longer ones truncated.
-spec width(style(), non_neg_integer()) -> style().
width(S, W) -> S#{width => W}.

%% @doc Fix the content height (rows), padded/truncated per {@link valign/2}.
-spec height(style(), non_neg_integer()) -> style().
height(S, H) -> S#{height => H}.

-spec align(style(), left | center | right) -> style().
align(S, A) -> S#{align => A}.

-spec valign(style(), top | middle | bottom) -> style().
valign(S, V) -> S#{valign => V}.

%% @doc Inner spacing. `N' for all sides, `{V, H}' for vertical/horizontal, or
%% `{Top, Right, Bottom, Left}'.
-spec padding(style(), box()) -> style().
padding(S, Spec) -> S#{padding => box(Spec)}.

%% @doc Outer spacing (same shorthand as {@link padding/2}).
-spec margin(style(), box()) -> style().
margin(S, Spec) -> S#{margin => box(Spec)}.

-spec border(style(), none | normal | rounded | thick | double) -> style().
border(S, B) -> S#{border => B}.

-spec border_foreground(style(), color()) -> style().
border_foreground(S, Color) -> S#{border_fg => Color}.

%% @doc Layer `Over' on top of `Base' (Over's properties win).
-spec merge(style(), style()) -> style().
merge(Base, Over) -> maps:merge(Base, Over).

%%% ===================================================================
%%% Rendering
%%% ===================================================================

%% @doc Apply the style to `Text', returning styled `iodata()' (possibly
%% multiple lines). Order: inline SGR -> width/align -> height/valign ->
%% padding -> border -> margin.
-spec render(style(), iodata()) -> iodata().
render(S, Text) ->
    Lines0 = beamtea_render:lines(Text),
    {PT, PR, PB, PL} = maps:get(padding, S, {0, 0, 0, 0}),
    Align = maps:get(align, S, left),
    CW = case maps:get(width, S, auto) of
             auto -> lists:max([0 | [beamtea_util:visible_width(L) || L <- Lines0]]);
             W -> W
         end,
    Lines1 = vfit(Lines0, maps:get(height, S, auto), maps:get(valign, S, top)),
    Codes = sgr_codes(S),
    FullW = CW + PL + PR,
    ContentRows = [style_row(L, CW, PL, PR, Align, Codes) || L <- Lines1],
    PadRow = blank_row(FullW, Codes),
    Block = lists:duplicate(PT, PadRow) ++ ContentRows ++ lists:duplicate(PB, PadRow),
    Bordered = maybe_border(Block, FullW, S),
    Marginned = maybe_margin(Bordered, S),
    lists:join(<<"\n">>, Marginned).

%% One content row: left/right padding around the aligned, styled text.
style_row(L, CW, PL, PR, Align, Codes) ->
    Inner = [spaces(PL), align_to(L, CW, Align), spaces(PR)],
    wrap(Codes, Inner).

blank_row(W, Codes) -> wrap(Codes, spaces(W)).

%% Pad/truncate the list of lines to a fixed height with vertical alignment.
vfit(Lines, auto, _V) -> Lines;
vfit(Lines, H, V) ->
    N = length(Lines),
    if
        N >= H -> lists:sublist(Lines, H);
        true ->
            Extra = H - N,
            case V of
                top -> Lines ++ blanks(Extra);
                bottom -> blanks(Extra) ++ Lines;
                middle ->
                    Top = Extra div 2,
                    blanks(Top) ++ Lines ++ blanks(Extra - Top)
            end
    end.

blanks(N) -> lists:duplicate(N, <<>>).

%%% --- border ----------------------------------------------------------

maybe_border(Block, FullW, S) ->
    case maps:get(border, S, none) of
        none -> Block;
        B ->
            {TL, T, TR, L, R, BL, Bo, BR} = border_chars(B),
            BCodes = case maps:get(border_fg, S, none) of
                         none -> [];
                         C -> color_codes(38, C)
                     end,
            Bar = beamtea_term:rule(FullW, T),
            Top = wrap(BCodes, [TL, Bar, TR]),
            Bottom = wrap(BCodes, [BL, beamtea_term:rule(FullW, Bo), BR]),
            Body = [[wrap(BCodes, L), Row, wrap(BCodes, R)] || Row <- Block],
            [Top | Body] ++ [Bottom]
    end.

%%% --- margin -----------------------------------------------------------

maybe_margin(Block, S) ->
    case maps:get(margin, S, {0, 0, 0, 0}) of
        {0, 0, 0, 0} -> Block;
        {MT, _MR, MB, ML} ->
            LeftPad = spaces(ML),
            Shifted = [[LeftPad, Row] || Row <- Block],
            blanks(MT) ++ Shifted ++ blanks(MB)
    end.

%%% ===================================================================
%%% Composition of rendered blocks
%%% ===================================================================

%% @doc Place rendered blocks side by side, aligning their differing heights
%% (`top' | `middle' | `bottom').
-spec join_horizontal(top | middle | bottom, [iodata()]) -> iodata().
join_horizontal(VAlign, Blocks) ->
    Grids = [beamtea_render:lines(B) || B <- Blocks],
    MaxH = lists:max([1 | [length(G) || G <- Grids]]),
    Widths = [block_width(G) || G <- Grids],
    Padded = [pad_block(G, W, MaxH, VAlign) || {G, W} <- lists:zip(Grids, Widths)],
    Rows = [[lists:nth(I, P) || P <- Padded] || I <- lists:seq(1, MaxH)],
    lists:join(<<"\n">>, Rows).

%% @doc Stack rendered blocks, aligning their differing widths
%% (`left' | `center' | `right').
-spec join_vertical(left | center | right, [iodata()]) -> iodata().
join_vertical(HAlign, Blocks) ->
    Lines = lists:append([beamtea_render:lines(B) || B <- Blocks]),
    MaxW = lists:max([0 | [beamtea_util:visible_width(L) || L <- Lines]]),
    Aligned = [align_to(L, MaxW, HAlign) || L <- Lines],
    lists:join(<<"\n">>, Aligned).

%% Pad a block's lines to `W' wide and to `H' rows with the given vertical align.
pad_block(Grid, W, H, VAlign) ->
    Padded = [beamtea_util:pad_visible(L, W) || L <- Grid],
    Blank = spaces(W),
    N = length(Padded),
    Extra = max(0, H - N),
    case VAlign of
        top -> Padded ++ lists:duplicate(Extra, Blank);
        bottom -> lists:duplicate(Extra, Blank) ++ Padded;
        middle ->
            Top = Extra div 2,
            lists:duplicate(Top, Blank) ++ Padded
                ++ lists:duplicate(Extra - Top, Blank)
    end.

block_width(Grid) ->
    lists:max([0 | [beamtea_util:visible_width(L) || L <- Grid]]).

%%% ===================================================================
%%% Helpers
%%% ===================================================================

wrap([], X) -> X;
wrap(Codes, X) -> [beamtea_term:sgr(Codes), X, beamtea_term:reset()].

%% Collect the inline SGR codes for a style.
sgr_codes(S) ->
    lists:append([
        [1 || maps:get(bold, S, false)],
        [2 || maps:get(faint, S, false)],
        [3 || maps:get(italic, S, false)],
        [4 || maps:get(underline, S, false)],
        [7 || maps:get(reverse, S, false)],
        case maps:get(fg, S, none) of none -> []; C -> color_codes(38, C) end,
        case maps:get(bg, S, none) of none -> []; C -> color_codes(48, C) end
    ]).

color_codes(Sel, {R, G, B}) -> [Sel, 2, R, G, B];
color_codes(Sel, N) when is_integer(N) -> [Sel, 5, N];
color_codes(Sel, Name) when is_atom(Name) -> [Sel, 5, beamtea_color:c(Name)].

%% Pad or truncate `L' to exactly `W' visible columns with alignment.
align_to(L, W, Align) ->
    Vis = beamtea_util:visible_width(L),
    if
        Vis > W -> beamtea_util:truncate(beamtea_util:strip_ansi(L), W);
        true ->
            Extra = W - Vis,
            case Align of
                left -> [L, spaces(Extra)];
                right -> [spaces(Extra), L];
                center ->
                    Lp = Extra div 2,
                    [spaces(Lp), L, spaces(Extra - Lp)]
            end
    end.

box(N) when is_integer(N) -> {N, N, N, N};
box({V, H}) -> {V, H, V, H};
box({T, R, B, L}) -> {T, R, B, L}.

spaces(0) -> <<>>;
spaces(N) -> binary:copy(<<" ">>, N).

%% {TopLeft, Top, TopRight, Left, Right, BottomLeft, Bottom, BottomRight}
border_chars(normal) ->
    {<<"┌"/utf8>>, <<"─"/utf8>>, <<"┐"/utf8>>, <<"│"/utf8>>, <<"│"/utf8>>,
     <<"└"/utf8>>, <<"─"/utf8>>, <<"┘"/utf8>>};
border_chars(rounded) ->
    {<<"╭"/utf8>>, <<"─"/utf8>>, <<"╮"/utf8>>, <<"│"/utf8>>, <<"│"/utf8>>,
     <<"╰"/utf8>>, <<"─"/utf8>>, <<"╯"/utf8>>};
border_chars(thick) ->
    {<<"┏"/utf8>>, <<"━"/utf8>>, <<"┓"/utf8>>, <<"┃"/utf8>>, <<"┃"/utf8>>,
     <<"┗"/utf8>>, <<"━"/utf8>>, <<"┛"/utf8>>};
border_chars(double) ->
    {<<"╔"/utf8>>, <<"═"/utf8>>, <<"╗"/utf8>>, <<"║"/utf8>>, <<"║"/utf8>>,
     <<"╚"/utf8>>, <<"═"/utf8>>, <<"╝"/utf8>>}.
