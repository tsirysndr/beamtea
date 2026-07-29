%%% @doc Position a block of content within the full terminal.
%%%
%%% beamtea renders exactly what your `view/1' returns, anchored at the
%%% top-left. To use the whole screen you place your content inside the
%%% terminal's `{Cols, Rows}' — centre it, pin it to a corner, etc. Widths are
%%% measured ignoring ANSI colour codes (via {@link beamtea_util:visible_width/1}),
%%% so coloured content still aligns.
%%%
%%% The runtime can apply this for you: `beamtea:start(Mod, Flags,
%%% #{layout => center})'. Or call it yourself in `view/1' when you track the
%%% size via the `{resize, {Cols, Rows}}' message.
-module(beamtea_layout).

-export([place/3, center/2, top_center/2, frame/3,
         overlay/4, overlay_center/3]).

-export_type([halign/0, valign/0]).

-type halign() :: left | center | right.
-type valign() :: top | middle | bottom.

%% @doc Place `Content' within a `{Cols, Rows}' area. Options:
%% `halign' (`left' | `center' | `right', default `center') and
%% `valign' (`top' | `middle' | `bottom', default `middle'). The block keeps
%% its internal left-alignment; it is positioned as a unit.
-spec place(iodata(), {pos_integer(), pos_integer()},
            #{halign => halign(), valign => valign()}) -> iodata().
place(Content, {Cols, Rows}, Opts) ->
    HAlign = maps:get(halign, Opts, center),
    VAlign = maps:get(valign, Opts, middle),
    Lines = beamtea_render:lines(Content),
    BlockW = lists:max([0 | [beamtea_util:visible_width(L) || L <- Lines]]),
    LeftPad = spaces(hpad(HAlign, Cols, BlockW)),
    Placed = [[LeftPad, L] || L <- Lines],
    TopPad = lists:duplicate(vpad(VAlign, Rows, length(Lines)), <<>>),
    lists:join(<<"\n">>, TopPad ++ Placed).

%% @doc Centre `Content' both horizontally and vertically.
-spec center(iodata(), {pos_integer(), pos_integer()}) -> iodata().
center(Content, Size) ->
    place(Content, Size, #{halign => center, valign => middle}).

%% @doc Centre horizontally, pinned to the top.
-spec top_center(iodata(), {pos_integer(), pos_integer()}) -> iodata().
top_center(Content, Size) ->
    place(Content, Size, #{halign => center, valign => top}).

%% @doc Draw a bordered panel that fills the whole `{Cols, Rows}' terminal and
%% place `Content' inside it (top-left, with one column of padding). This is
%% what makes a small view "fit the terminal". Options: `border_color'
%% (default charmple) and `padding' (inner columns/rows, default 1). Lines
%% wider than the inner width are truncated; the panel is padded to full height.
-spec frame(iodata(), {pos_integer(), pos_integer()}, map()) -> iodata().
frame(Content, {Cols, Rows}, Opts) when Cols >= 4, Rows >= 3 ->
    BC = maps:get(border_color, Opts, beamtea_color:c(charmple)),
    Pad = maps:get(padding, Opts, 1),
    ContentW = max(0, Cols - 2 - 2 * Pad),
    InnerH = max(0, Rows - 2 - 2 * Pad),
    Lines = [fit_line(L, ContentW) || L <- beamtea_render:lines(Content)],
    Kept = lists:sublist(Lines, InnerH),
    Blank = fit_line(<<>>, ContentW),
    VPad = lists:duplicate(Pad, Blank),
    Filled = VPad ++ Kept
             ++ lists:duplicate(max(0, InnerH - length(Kept)), Blank)
             ++ VPad,
    Side = border(<<"│"/utf8>>, BC),
    PadSp = spaces(Pad),
    Body = [[Side, PadSp, L, PadSp, Side] || L <- Filled],
    Bar = beamtea_term:rule(Cols - 2),
    Top = border([<<"┌"/utf8>>, Bar, <<"┐"/utf8>>], BC),
    Bottom = border([<<"└"/utf8>>, Bar, <<"┘"/utf8>>], BC),
    lists:join(<<"\n">>, [Top | Body] ++ [Bottom]);
frame(Content, _Size, _Opts) ->
    Content.

%% @doc Composite `Fg' on top of `Bg' at `{Col, Row}' (0-based) within a
%% `{Cols, Rows}' area — the basis for a floating modal/popover. Both may be
%% fully styled (ANSI is handled when slicing the background by column); `Bg'
%% is padded to the full area first.
-spec overlay(iodata(), iodata(), {non_neg_integer(), non_neg_integer()},
              {pos_integer(), pos_integer()}) -> iodata().
overlay(Bg, Fg, {Col, Row}, {Cols, Rows}) ->
    BgLines = normalize_bg(beamtea_render:lines(Bg), Cols, Rows),
    FgLines = beamtea_render:lines(Fg),
    FgW = lists:max([0 | [beamtea_util:visible_width(L) || L <- FgLines]]),
    FgH = length(FgLines),
    Composited =
        [compose_row(I, BgLines, FgLines, FgW, FgH, Col, Row)
         || I <- lists:seq(0, Rows - 1)],
    lists:join(<<"\n">>, Composited).

%% @doc Centre `Fg' over `Bg' within `{Cols, Rows}'.
-spec overlay_center(iodata(), iodata(), {pos_integer(), pos_integer()}) -> iodata().
overlay_center(Bg, Fg, {Cols, Rows}) ->
    FgLines = beamtea_render:lines(Fg),
    FgW = lists:max([0 | [beamtea_util:visible_width(L) || L <- FgLines]]),
    FgH = length(FgLines),
    Col = max(0, (Cols - FgW) div 2),
    Row = max(0, (Rows - FgH) div 2),
    overlay(Bg, Fg, {Col, Row}, {Cols, Rows}).

compose_row(I, BgLines, FgLines, FgW, FgH, Col, Row)
  when I >= Row, I < Row + FgH ->
    Bg = lists:nth(I + 1, BgLines),
    Fg = beamtea_util:pad_visible(lists:nth(I - Row + 1, FgLines), FgW),
    [ansi_take(Bg, Col), Fg, ansi_drop(Bg, Col + FgW)];
compose_row(I, BgLines, _FgLines, _FgW, _FgH, _Col, _Row) ->
    lists:nth(I + 1, BgLines).

%% Pad the background to exactly Rows lines of Cols visible columns.
normalize_bg(Lines, Cols, Rows) ->
    Fitted = [beamtea_util:pad_visible(L, Cols) || L <- Lines],
    case length(Fitted) of
        N when N >= Rows -> lists:sublist(Fitted, Rows);
        N -> Fitted ++ lists:duplicate(Rows - N, spaces(Cols))
    end.

%% Take the first `N' visible columns, keeping ANSI escapes; reset at the end.
ansi_take(Line, N) ->
    take_cols(iolist_to_binary(Line), N, <<>>).

take_cols(<<>>, _N, Acc) -> Acc;
take_cols(_B, 0, Acc) -> <<Acc/binary, "\e[0m">>;
take_cols(<<16#1B, $[, R/binary>>, N, Acc) ->
    {Seq, R1} = grab_csi(R),
    take_cols(R1, N, <<Acc/binary, 16#1B, $[, Seq/binary>>);
take_cols(<<C/utf8, R/binary>>, N, Acc) when N > 0 ->
    take_cols(R, N - 1, <<Acc/binary, C/utf8>>);
take_cols(<<_, R/binary>>, N, Acc) ->
    take_cols(R, N, Acc).

%% Drop the first `N' visible columns, replaying the ANSI state seen so far so
%% the remainder keeps its colours.
ansi_drop(Line, N) ->
    drop_cols(iolist_to_binary(Line), N, <<>>).

drop_cols(<<>>, _N, _State) -> <<>>;
drop_cols(B, 0, State) -> <<State/binary, B/binary>>;
drop_cols(<<16#1B, $[, R/binary>>, N, State) ->
    {Seq, R1} = grab_csi(R),
    drop_cols(R1, N, <<State/binary, 16#1B, $[, Seq/binary>>);
drop_cols(<<_C/utf8, R/binary>>, N, State) when N > 0 ->
    drop_cols(R, N - 1, State);
drop_cols(<<_, R/binary>>, N, State) ->
    drop_cols(R, N, State).

%% Read a CSI body up to and including its final byte (0x40..0x7E).
grab_csi(B) -> grab_csi(B, <<>>).
grab_csi(<<C, R/binary>>, Acc) when C >= 16#40, C =< 16#7E -> {<<Acc/binary, C>>, R};
grab_csi(<<C, R/binary>>, Acc) -> grab_csi(R, <<Acc/binary, C>>);
grab_csi(<<>>, Acc) -> {Acc, <<>>}.

%%% --- helpers ----------------------------------------------------------

border(IoData, Color) -> beamtea_term:paint([38, 5, Color], IoData).

%% Pad (or truncate) a line to exactly `W' visible columns.
fit_line(Line, W) ->
    case beamtea_util:visible_width(Line) of
        Vis when Vis =< W -> [Line, spaces(W - Vis)];
        _ -> beamtea_util:truncate(beamtea_util:strip_ansi(Line), W)
    end.

hpad(left, _Cols, _BlockW)   -> 0;
hpad(center, Cols, BlockW)   -> max(0, (Cols - BlockW) div 2);
hpad(right, Cols, BlockW)    -> max(0, Cols - BlockW).

vpad(top, _Rows, _N)   -> 0;
vpad(middle, Rows, N)  -> max(0, (Rows - N) div 2);
vpad(bottom, Rows, N)  -> max(0, Rows - N).

spaces(0) -> <<>>;
spaces(N) -> binary:copy(<<" ">>, N).
