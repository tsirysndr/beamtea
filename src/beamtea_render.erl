%%% @doc Turn a view (the full desired screen contents) into the byte stream
%%% that redraws the terminal.
%%%
%%% beamtea 0.1.0 uses simple full-frame rendering: every frame is drawn from
%%% the top-left. To keep flicker low we do <em>not</em> issue a full
%%% `clear' each frame. Instead we home the cursor, and end every line with
%%% "erase to end of line"; a trailing "erase below" wipes any lines the
%%% previous, taller frame left behind. The net effect is a clean repaint with
%%% no visible clear.
-module(beamtea_render).

-export([to_frame/1, lines/1]).

%% @doc Build the escape/byte sequence that repaints the screen with `View'.
%% `View' is any `iodata()'; lines are separated by `\n' (a trailing `\r' is
%% tolerated). In raw mode line breaks must be `\r\n', which this inserts.
-spec to_frame(iodata()) -> iodata().
to_frame(View) ->
    [beamtea_term:home(),
     render_lines(lines(View)),
     beamtea_term:reset(),
     beamtea_term:clear_below()].

%% @doc Split a view into its constituent lines (on `\n', trailing `\r'
%% stripped).
-spec lines(unicode:chardata()) -> [binary()].
lines(View) ->
    Bin = to_binary(View),
    [strip_cr(L) || L <- binary:split(Bin, <<"\n">>, [global])].

%% Encode a view to a UTF-8 binary. Unlike `iolist_to_binary/1' this accepts
%% both UTF-8 binaries and lists of Unicode code points (e.g. "─"), so views
%% can freely mix the two without crashing on code points above 255.
to_binary(View) ->
    case unicode:characters_to_binary(View) of
        Bin when is_binary(Bin) -> Bin;
        {error, Encoded, _Rest} -> Encoded;
        {incomplete, Encoded, _Rest} -> Encoded
    end.

render_lines([]) ->
    [];
render_lines([Last]) ->
    [Last, beamtea_term:clear_line()];
render_lines([Line | Rest]) ->
    [Line, beamtea_term:clear_line(), <<"\r\n">> | render_lines(Rest)].

strip_cr(Bin) ->
    case Bin of
        <<>> -> <<>>;
        _ ->
            Size = byte_size(Bin) - 1,
            case Bin of
                <<Head:Size/binary, $\r>> -> Head;
                _ -> Bin
            end
    end.
