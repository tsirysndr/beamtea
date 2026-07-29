%%% @doc Small shared helpers for beamtea bubbles.
-module(beamtea_util).

-export([format_clock/1, format_stopwatch/1, truncate/2, pad_right/2,
         strip_ansi/1, visible_width/1, char_width/1, pad_visible/2]).

%% @doc Format milliseconds as `MM:SS' (or `HH:MM:SS' past an hour).
-spec format_clock(integer()) -> iodata().
format_clock(Ms) when Ms < 0 -> format_clock(0);
format_clock(Ms) ->
    Total = Ms div 1000,
    H = Total div 3600,
    M = (Total rem 3600) div 60,
    S = Total rem 60,
    case H of
        0 -> io_lib:format("~2..0B:~2..0B", [M, S]);
        _ -> io_lib:format("~B:~2..0B:~2..0B", [H, M, S])
    end.

%% @doc Format milliseconds as `MM:SS.CS' (centiseconds) — for stopwatches.
-spec format_stopwatch(integer()) -> iodata().
format_stopwatch(Ms) when Ms < 0 -> format_stopwatch(0);
format_stopwatch(Ms) ->
    Total = Ms div 1000,
    M = Total div 60,
    S = Total rem 60,
    Cs = (Ms rem 1000) div 10,
    io_lib:format("~2..0B:~2..0B.~2..0B", [M, S, Cs]).

%% @doc Truncate an iodata string to at most `Max' *display columns*, adding an
%% ellipsis when cut. Wide characters count as 2, so the result never exceeds
%% `Max' columns even when it splits around emoji/CJK.
-spec truncate(iodata(), non_neg_integer()) -> binary().
truncate(IoData, Max) ->
    Chars = unicode:characters_to_list(iolist_to_binary(IoData)),
    case visible_width(unicode:characters_to_binary(Chars)) =< Max of
        true -> unicode:characters_to_binary(Chars);
        false when Max =< 1 ->
            unicode:characters_to_binary(take_width(Chars, Max));
        false ->
            unicode:characters_to_binary(take_width(Chars, Max - 1) ++ [$…])
    end.

%% Take a prefix of code points that fits within `Max' display columns.
take_width(Chars, Max) -> take_width(Chars, Max, 0, []).
take_width([], _Max, _W, Acc) -> lists:reverse(Acc);
take_width([C | Rest], Max, W, Acc) ->
    W1 = W + char_width(C),
    case W1 > Max of
        true -> lists:reverse(Acc);
        false -> take_width(Rest, Max, W1, [C | Acc])
    end.

%% @doc Right-pad an iodata string with spaces to `Width' code points (never
%% truncates).
-spec pad_right(iodata(), non_neg_integer()) -> iodata().
pad_right(IoData, Width) ->
    Bin = to_bin(IoData),
    Len = length(unicode:characters_to_list(Bin)),
    case Width > Len of
        true -> [Bin, binary:copy(<<" ">>, Width - Len)];
        false -> Bin
    end.

%% @doc Remove ANSI escape sequences (SGR colours, cursor moves, …) from a
%% string, leaving only the visible characters.
-spec strip_ansi(unicode:chardata()) -> binary().
strip_ansi(IoData) ->
    Bin = to_bin(IoData),
    strip_ansi(Bin, <<>>).

strip_ansi(<<>>, Acc) ->
    Acc;
strip_ansi(<<16#1B, $[, Rest/binary>>, Acc) ->
    strip_ansi(skip_to_final(Rest), Acc);
strip_ansi(<<C/utf8, Rest/binary>>, Acc) ->
    strip_ansi(Rest, <<Acc/binary, C/utf8>>);
strip_ansi(<<_, Rest/binary>>, Acc) ->
    strip_ansi(Rest, Acc).

%% Consume a CSI body up to and including its final byte (0x40..0x7E).
skip_to_final(<<C, Rest/binary>>) when C >= 16#40, C =< 16#7E -> Rest;
skip_to_final(<<_, Rest/binary>>) -> skip_to_final(Rest);
skip_to_final(<<>>) -> <<>>.

%% @doc The number of *display columns* a string occupies, ignoring ANSI
%% escapes. Uses a `wcwidth' (via `prim_tty:npwcwidth/1'), so wide characters
%% (emoji, CJK) count as 2 and combining marks as 0 — this is what keeps
%% borders and padding aligned around wide glyphs.
-spec visible_width(unicode:chardata()) -> non_neg_integer().
visible_width(IoData) ->
    lists:sum([char_width(C) || C <- unicode:characters_to_list(strip_ansi(IoData))]).

%% @doc The display width of a single code point (0, 1 or 2).
-spec char_width(char()) -> 0..2.
char_width(C) ->
    case prim_tty:npwcwidth(C) of
        W when is_integer(W), W > 0 -> W;
        _ -> 0   %% -1 (non-printable) / 0 (combining) -> occupies no column
    end.

%% @doc Right-pad to `Width' *visible* columns, ignoring ANSI escapes in the
%% width calculation (so coloured text lines up correctly).
-spec pad_visible(unicode:chardata(), non_neg_integer()) -> iodata().
pad_visible(IoData, Width) ->
    Vis = visible_width(IoData),
    case Width > Vis of
        true -> [IoData, binary:copy(<<" ">>, Width - Vis)];
        false -> IoData
    end.

to_bin(IoData) ->
    case unicode:characters_to_binary(IoData) of
        Bin when is_binary(Bin) -> Bin;
        {error, Encoded, _} -> Encoded;
        {incomplete, Encoded, _} -> Encoded
    end.
