%%% @doc A bubble: a multi-line text area, mirroring the `textarea' package in
%%% charmbracelet/bubbles.
%%%
%%% Full multi-line editing: insertion, newlines, backspace/delete across line
%%% boundaries, and caret movement with the arrows and Home/End. The visible
%%% window scrolls vertically to keep the caret in view. As with
%%% {@link beamtea_textinput}, the caret is drawn with reverse video.
-module(beamtea_textarea).

-export([new/0, new/1, update/2, view/1,
         value/1, set_value/2, clear/1,
         focus/1, blur/1, focused/1, cursor/1, line_count/1]).

-export_type([model/0]).

-opaque model() :: #{type := textarea,
                     lines := [[char()]],       %% each line is code points
                     row := non_neg_integer(),
                     col := non_neg_integer(),
                     offset := non_neg_integer(),
                     height := pos_integer(),
                     focus := boolean(),
                     placeholder := iodata(),
                     color := 0..255}.

%% @equiv new(#{})
-spec new() -> model().
new() -> new(#{}).

%% @doc Options: `height' (visible rows, default 6), `placeholder', `color',
%% and `value' (initial contents).
-spec new(map()) -> model().
new(Opts) ->
    #{type => textarea,
      lines => to_lines(maps:get(value, Opts, <<>>)),
      row => 0,
      col => 0,
      offset => 0,
      height => maps:get(height, Opts, 6),
      focus => maps:get(focus, Opts, false),
      placeholder => maps:get(placeholder, Opts, <<>>),
      color => maps:get(color, Opts, beamtea_color:c(pink))}.

%% @doc Edit in response to a key (only while focused).
-spec update(term(), model()) -> {model(), beamtea:cmd()}.
update({key, Key}, #{focus := true} = M) ->
    {scroll(handle_key(Key, M)), beamtea:none()};
update(_Msg, M) ->
    {M, beamtea:none()}.

handle_key({char, Cp}, M) -> insert_char(Cp, M);
handle_key(enter, M)      -> insert_newline(M);
handle_key(backspace, M)  -> backspace(M);
handle_key(delete, M)     -> delete(M);
handle_key(left, M)       -> move_left(M);
handle_key(right, M)      -> move_right(M);
handle_key(up, M)         -> move_up(M);
handle_key(down, M)       -> move_down(M);
handle_key(home, #{row := R} = M)  -> M#{col := 0, row := R};
handle_key('end', #{row := R, lines := Ls} = M) ->
    M#{col := length(lists:nth(R + 1, Ls))};
handle_key(_Other, M) -> M.

insert_char(Cp, #{lines := Ls, row := R, col := C} = M) ->
    Line = lists:nth(R + 1, Ls),
    {Before, After} = lists:split(C, Line),
    NewLine = Before ++ [Cp | After],
    M#{lines := set_nth(R + 1, NewLine, Ls), col := C + 1}.

insert_newline(#{lines := Ls, row := R, col := C} = M) ->
    Line = lists:nth(R + 1, Ls),
    {Before, After} = lists:split(C, Line),
    Ls1 = insert_after(R + 1, Before, After, Ls),
    M#{lines := Ls1, row := R + 1, col := 0}.

backspace(#{col := C, row := R, lines := Ls} = M) when C > 0 ->
    Line = lists:nth(R + 1, Ls),
    {Before, After} = lists:split(C, Line),
    NewLine = lists:droplast(Before) ++ After,
    M#{lines := set_nth(R + 1, NewLine, Ls), col := C - 1};
backspace(#{col := 0, row := R, lines := Ls} = M) when R > 0 ->
    Prev = lists:nth(R, Ls),
    Cur = lists:nth(R + 1, Ls),
    Merged = Prev ++ Cur,
    Ls1 = set_nth(R, Merged, delete_nth(R + 1, Ls)),
    M#{lines := Ls1, row := R - 1, col := length(Prev)};
backspace(M) -> M.

delete(#{col := C, row := R, lines := Ls} = M) ->
    Line = lists:nth(R + 1, Ls),
    Len = length(Line),
    if
        C < Len ->
            {Before, [_ | After]} = lists:split(C, Line),
            M#{lines := set_nth(R + 1, Before ++ After, Ls)};
        R + 1 < length(Ls) ->
            Next = lists:nth(R + 2, Ls),
            Merged = Line ++ Next,
            M#{lines := set_nth(R + 1, Merged, delete_nth(R + 2, Ls))};
        true -> M
    end.

move_left(#{col := C} = M) when C > 0 -> M#{col := C - 1};
move_left(#{col := 0, row := R, lines := Ls} = M) when R > 0 ->
    M#{row := R - 1, col := length(lists:nth(R, Ls))};
move_left(M) -> M.

move_right(#{col := C, row := R, lines := Ls} = M) ->
    Len = length(lists:nth(R + 1, Ls)),
    if
        C < Len -> M#{col := C + 1};
        R + 1 < length(Ls) -> M#{row := R + 1, col := 0};
        true -> M
    end.

move_up(#{row := R} = M) when R > 0 -> clamp_col(M#{row := R - 1});
move_up(M) -> M.

move_down(#{row := R, lines := Ls} = M) when R + 1 < length(Ls) ->
    clamp_col(M#{row := R + 1});
move_down(M) -> M.

clamp_col(#{row := R, col := C, lines := Ls} = M) ->
    M#{col := min(C, length(lists:nth(R + 1, Ls)))}.

%% Keep the caret row inside the visible window.
scroll(#{row := R, offset := Off, height := H} = M) ->
    Off1 = if
               R < Off      -> R;
               R >= Off + H -> R - H + 1;
               true         -> Off
           end,
    M#{offset := Off1}.

%% @doc Render the visible lines with the caret (or a faint placeholder).
-spec view(model()) -> iodata().
view(#{lines := [[]], focus := Focus, placeholder := Ph} = M)
  when Ph =/= <<>> ->
    %% Empty document with a placeholder.
    case Focus of
        true -> view_lines(M);
        false -> beamtea_term:faint(Ph)
    end;
view(M) ->
    view_lines(M).

view_lines(#{lines := Ls, row := R, col := C, offset := Off, height := H,
             focus := Focus}) ->
    Window = lists:sublist(lists:nthtail(Off, Ls), H),
    Rendered = [render_line(Line, Off + Idx - 1, R, C, Focus)
                || {Idx, Line} <- enumerate(Window)],
    Padding = lists:duplicate(max(0, H - length(Window)), <<>>),
    lists:join(<<"\n">>, Rendered ++ Padding).

render_line(Line, LineIdx, R, C, true) when LineIdx =:= R ->
    {Before, After} = lists:split(min(C, length(Line)), Line),
    case After of
        [] -> [chars(Before), beamtea_term:reverse(<<" ">>)];
        [Ch | Rest] ->
            [chars(Before), beamtea_term:reverse(<<Ch/utf8>>), chars(Rest)]
    end;
render_line(Line, _LineIdx, _R, _C, _Focus) ->
    chars(Line).

%%% --- accessors --------------------------------------------------------

%% @doc The full contents as a UTF-8 binary (lines joined with `\n').
-spec value(model()) -> binary().
value(#{lines := Ls}) ->
    unicode:characters_to_binary(lists:join($\n, Ls)).

-spec set_value(iodata(), model()) -> model().
set_value(Value, M) ->
    Ls = to_lines(Value),
    M#{lines := Ls, row := 0, col := 0, offset := 0}.

-spec clear(model()) -> model().
clear(M) -> M#{lines := [[]], row := 0, col := 0, offset := 0}.

-spec focus(model()) -> model().
focus(M) -> M#{focus := true}.

-spec blur(model()) -> model().
blur(M) -> M#{focus := false}.

-spec focused(model()) -> boolean().
focused(#{focus := F}) -> F.

-spec cursor(model()) -> {non_neg_integer(), non_neg_integer()}.
cursor(#{row := R, col := C}) -> {R, C}.

-spec line_count(model()) -> pos_integer().
line_count(#{lines := Ls}) -> length(Ls).

%%% --- helpers ----------------------------------------------------------

chars(Cs) -> unicode:characters_to_binary(Cs).

to_lines(Value) ->
    Bin = iolist_to_binary(Value),
    [unicode:characters_to_list(L) || L <- binary:split(Bin, <<"\n">>, [global])].

enumerate(List) -> lists:zip(lists:seq(1, length(List)), List).

set_nth(N, Elem, List) ->
    {Before, [_ | After]} = lists:split(N - 1, List),
    Before ++ [Elem | After].

delete_nth(N, List) ->
    {Before, [_ | After]} = lists:split(N - 1, List),
    Before ++ After.

%% Replace element N with `First' and insert `Second' right after it.
insert_after(N, First, Second, List) ->
    {Before, [_ | After]} = lists:split(N - 1, List),
    Before ++ [First, Second | After].
