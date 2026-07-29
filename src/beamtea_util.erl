%%% @doc Small shared helpers for beamtea bubbles.
-module(beamtea_util).

-export([format_clock/1, format_stopwatch/1, truncate/2, pad_right/2,
         strip_ansi/1, visible_width/1, pad_visible/2]).

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

%% @doc Truncate an iodata string to at most `Max' code points, adding an
%% ellipsis when cut.
-spec truncate(iodata(), non_neg_integer()) -> binary().
truncate(IoData, Max) ->
    Chars = unicode:characters_to_list(iolist_to_binary(IoData)),
    case length(Chars) =< Max of
        true -> unicode:characters_to_binary(Chars);
        false when Max =< 1 ->
            unicode:characters_to_binary(lists:sublist(Chars, Max));
        false ->
            unicode:characters_to_binary(lists:sublist(Chars, Max - 1) ++ [$…])
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

%% @doc The number of visible columns in a string, ignoring ANSI escapes.
%% (Counts code points; wide characters are treated as width 1.)
-spec visible_width(unicode:chardata()) -> non_neg_integer().
visible_width(IoData) ->
    length(unicode:characters_to_list(strip_ansi(IoData))).

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
