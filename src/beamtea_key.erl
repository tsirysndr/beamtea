%%% @doc Decode a stream of raw terminal bytes into high-level key events.
%%%
%%% The terminal delivers key presses as raw bytes: a single ASCII byte for
%%% ordinary keys, a multi-byte UTF-8 sequence for non-ASCII characters, and
%%% ANSI escape sequences (CSI / SS3) for the arrows, function and navigation
%%% keys. {@link parse/1} turns a binary chunk into a list of `key()' events
%%% plus any trailing bytes that form an incomplete sequence — those must be
%%% prepended to the next chunk.
%%%
%%% Key events are represented as:
%%% <ul>
%%%   <li>a named atom for special keys: `up', `down', `left', `right',
%%%       `enter', `esc', `tab', `back_tab', `backspace', `delete', `insert',
%%%       `home', `'end'', `page_up', `page_down'</li>
%%%   <li>`{ctrl, Letter}' for Ctrl-combinations, e.g. Ctrl-C is
%%%       `{ctrl, $c}'</li>
%%%   <li>`{char, CodePoint}' for a printable character (including space); the
%%%       code point is a full Unicode code point, so UTF-8 text "just
%%%       works"</li>
%%% </ul>
-module(beamtea_key).

-export([parse/1, to_binary/1]).

-export_type([key/0]).

-type key() ::
        up | down | left | right
      | home | 'end' | page_up | page_down
      | insert | delete
      | enter | tab | back_tab | backspace | esc
      | {ctrl, char()}
      | {char, char()}.

%% @doc Parse a raw byte chunk into `{Keys, Rest}'. `Rest' is the tail of an
%% incomplete escape sequence or UTF-8 code point and should be prepended to
%% the next chunk before parsing.
-spec parse(binary()) -> {[key()], binary()}.
parse(Bin) -> parse(Bin, []).

parse(<<>>, Acc) ->
    {lists:reverse(Acc), <<>>};

%% --- Escape sequences -------------------------------------------------
parse(<<$\e, $[, Rest/binary>> = All, Acc) ->
    case parse_seq(Rest, fun interpret_csi/2) of
        {ok, Key, Rest1} -> parse(Rest1, [Key | Acc]);
        {skip, Rest1}    -> parse(Rest1, Acc);
        incomplete       -> {lists:reverse(Acc), All}
    end;
parse(<<$\e, $O, Rest/binary>> = All, Acc) ->
    case parse_seq(Rest, fun interpret_ss3/2) of
        {ok, Key, Rest1} -> parse(Rest1, [Key | Acc]);
        {skip, Rest1}    -> parse(Rest1, Acc);
        incomplete       -> {lists:reverse(Acc), All}
    end;
%% A lone ESC at the very end of the buffer is the Escape key.
parse(<<$\e>>, Acc) ->
    {lists:reverse([esc | Acc]), <<>>};
%% ESC followed by something that is not a sequence introducer: emit Escape
%% and reparse the remainder (also covers Alt+key, treated as Esc then key).
parse(<<$\e, B, Rest/binary>>, Acc) when B =/= $[, B =/= $O ->
    parse(<<B, Rest/binary>>, [esc | Acc]);

%% --- Named control keys ----------------------------------------------
parse(<<$\r, Rest/binary>>, Acc) -> parse(Rest, [enter | Acc]);
parse(<<$\n, Rest/binary>>, Acc) -> parse(Rest, [enter | Acc]);
parse(<<$\t, Rest/binary>>, Acc) -> parse(Rest, [tab | Acc]);
parse(<<127, Rest/binary>>, Acc) -> parse(Rest, [backspace | Acc]);
parse(<<8,   Rest/binary>>, Acc) -> parse(Rest, [backspace | Acc]);

%% --- Ctrl-<letter> ----------------------------------------------------
%% Bytes 1..26 are Ctrl-A..Ctrl-Z (0x0d/0x09/0x08 handled above).
parse(<<C, Rest/binary>>, Acc) when C >= 1, C =< 26 ->
    parse(Rest, [{ctrl, C + $a - 1} | Acc]);

%% Drop any remaining C0 control bytes we do not recognise (incl. NUL).
parse(<<C, Rest/binary>>, Acc) when C < 32 ->
    parse(Rest, Acc);

%% --- Printable characters (UTF-8) ------------------------------------
parse(Bin, Acc) ->
    case Bin of
        <<Cp/utf8, Rest/binary>> ->
            parse(Rest, [{char, Cp} | Acc]);
        _ ->
            case incomplete_utf8(Bin) of
                true ->
                    %% Truncated multi-byte code point: keep for next chunk.
                    {lists:reverse(Acc), Bin};
                false ->
                    %% Invalid byte: drop it and continue.
                    <<_, Rest/binary>> = Bin,
                    parse(Rest, Acc)
            end
    end.

%% @doc Render a single `{char, Cp}' (or a bare code point) as a UTF-8 binary.
%% Handy for building text buffers in an `update/2'.
-spec to_binary({char, char()} | char()) -> binary().
to_binary({char, Cp}) -> <<Cp/utf8>>;
to_binary(Cp) when is_integer(Cp) -> <<Cp/utf8>>.

%%% ===================================================================
%%% Escape-sequence scanning
%%% ===================================================================

%% Scan a CSI/SS3 body up to its final byte, then hand the parameter bytes and
%% final byte to `Interpret'. Returns `incomplete' if no final byte is present
%% yet (the sequence spans a read boundary).
parse_seq(Bin, Interpret) ->
    case final_byte(Bin, 0) of
        incomplete ->
            incomplete;
        {Final, Idx} ->
            Params = binary:part(Bin, 0, Idx),
            Rest = binary:part(Bin, Idx + 1, byte_size(Bin) - Idx - 1),
            case Interpret(Params, Final) of
                {ok, Key} -> {ok, Key, Rest};
                skip      -> {skip, Rest}
            end
    end.

%% Find the offset of the terminating byte (0x40..0x7E) of a CSI/SS3 sequence.
final_byte(<<>>, _Idx) ->
    incomplete;
final_byte(<<C, Rest/binary>>, Idx) ->
    if
        C >= 16#40, C =< 16#7E -> {C, Idx};
        true                   -> final_byte(Rest, Idx + 1)
    end.

%% CSI (ESC [) — arrows plus the `~'-terminated navigation keys.
interpret_csi(<<>>, $A) -> {ok, up};
interpret_csi(<<>>, $B) -> {ok, down};
interpret_csi(<<>>, $C) -> {ok, right};
interpret_csi(<<>>, $D) -> {ok, left};
interpret_csi(<<>>, $H) -> {ok, home};
interpret_csi(<<>>, $F) -> {ok, 'end'};
interpret_csi(<<>>, $Z) -> {ok, back_tab};
interpret_csi(<<"1">>, $~) -> {ok, home};
interpret_csi(<<"2">>, $~) -> {ok, insert};
interpret_csi(<<"3">>, $~) -> {ok, delete};
interpret_csi(<<"4">>, $~) -> {ok, 'end'};
interpret_csi(<<"5">>, $~) -> {ok, page_up};
interpret_csi(<<"6">>, $~) -> {ok, page_down};
interpret_csi(<<"7">>, $~) -> {ok, home};
interpret_csi(<<"8">>, $~) -> {ok, 'end'};
interpret_csi(_, _) -> skip.

%% SS3 (ESC O) — application-cursor-mode arrows and Home/End.
interpret_ss3(<<>>, $A) -> {ok, up};
interpret_ss3(<<>>, $B) -> {ok, down};
interpret_ss3(<<>>, $C) -> {ok, right};
interpret_ss3(<<>>, $D) -> {ok, left};
interpret_ss3(<<>>, $H) -> {ok, home};
interpret_ss3(<<>>, $F) -> {ok, 'end'};
interpret_ss3(_, _) -> skip.

%%% ===================================================================
%%% UTF-8 boundary detection
%%% ===================================================================

%% True when `Bin' is a valid but truncated prefix of a multi-byte code point.
incomplete_utf8(<<B>>)       when B >= 16#C2, B =< 16#F4 -> true;
incomplete_utf8(<<B, _>>)    when B >= 16#E0, B =< 16#F4 -> true;
incomplete_utf8(<<B, _, _>>) when B >= 16#F0, B =< 16#F4 -> true;
incomplete_utf8(_) -> false.
