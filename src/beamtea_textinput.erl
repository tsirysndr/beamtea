%%% @doc A bubble: a single-line text input.
%%%
%%% Handles UTF-8 text entry, a movable caret (arrows, Home/End), backspace and
%%% delete, an optional character limit, and a placeholder. Because beamtea
%%% hides the hardware cursor, the caret is drawn with reverse video.
%%%
%%% ```
%%%   init(_)         -> {beamtea_textinput:focus(beamtea_textinput:new(#{placeholder => <<"Name">>})), none}.
%%%   update({key,K}, M) -> {M1, Cmd} = beamtea_textinput:update({key,K}, M), {M1, Cmd}.
%%%   view(M)         -> beamtea_textinput:view(M).
%%%   %% read it back with beamtea_textinput:value(M)
%%% '''
-module(beamtea_textinput).

-export([new/0, new/1, update/2, view/1,
         value/1, set_value/2, clear/1,
         focus/1, blur/1, focused/1, cursor/1]).

-export_type([model/0]).

-opaque model() :: #{type := text_input,
                     chars := [char()],       %% the value, as code points
                     cursor := non_neg_integer(),
                     prompt := iodata(),
                     placeholder := iodata(),
                     focus := boolean(),
                     limit := non_neg_integer() | infinity,
                     color := 0..255}.

%% @equiv new(#{})
-spec new() -> model().
new() -> new(#{}).

%% @doc Create a text input. Options: `prompt' (default "> "), `placeholder',
%% `limit' (max chars, default `infinity'), `color' (caret/prompt accent).
-spec new(map()) -> model().
new(Opts) ->
    #{type => text_input,
      chars => to_chars(maps:get(value, Opts, <<>>)),
      cursor => 0,
      prompt => maps:get(prompt, Opts, <<"> ">>),
      placeholder => maps:get(placeholder, Opts, <<>>),
      focus => maps:get(focus, Opts, false),
      limit => maps:get(limit, Opts, infinity),
      color => maps:get(color, Opts, beamtea_color:c(pink))}.

%% @doc Feed a message. Only key messages matter, and only while focused.
-spec update(term(), model()) -> {model(), beamtea:cmd()}.
update({key, Key}, #{focus := true} = M) ->
    {handle_key(Key, M), beamtea:none()};
update(_Msg, M) ->
    {M, beamtea:none()}.

handle_key({char, Cp}, #{chars := Cs, cursor := Cur, limit := Limit} = M) ->
    case Limit =:= infinity orelse length(Cs) < Limit of
        true ->
            {Before, After} = lists:split(Cur, Cs),
            M#{chars := Before ++ [Cp | After], cursor := Cur + 1};
        false ->
            M
    end;
handle_key(backspace, #{chars := Cs, cursor := Cur} = M) when Cur > 0 ->
    {Before, After} = lists:split(Cur, Cs),
    M#{chars := lists:droplast(Before) ++ After, cursor := Cur - 1};
handle_key(delete, #{chars := Cs, cursor := Cur} = M) when Cur < length(Cs) ->
    {Before, [_ | After]} = lists:split(Cur, Cs),
    M#{chars := Before ++ After};
handle_key(left, #{cursor := Cur} = M) when Cur > 0 ->
    M#{cursor := Cur - 1};
handle_key(right, #{chars := Cs, cursor := Cur} = M) when Cur < length(Cs) ->
    M#{cursor := Cur + 1};
handle_key(home, M) ->
    M#{cursor := 0};
handle_key('end', #{chars := Cs} = M) ->
    M#{cursor := length(Cs)};
handle_key(_Other, M) ->
    M.

%% @doc Render the prompt, the current text and (when focused) the caret.
-spec view(model()) -> iodata().
view(#{chars := [], focus := Focus, prompt := Prompt,
       placeholder := Ph, color := Color}) ->
    Caret = case Focus of true -> caret(<<" ">>); false -> <<>> end,
    Tail = case iolist_size(Ph) of
               0 -> <<>>;
               _ when Focus -> beamtea_term:faint(Ph);
               _ -> beamtea_term:faint(Ph)
           end,
    [accent(Prompt, Color), Caret, Tail];
view(#{chars := Cs, cursor := Cur, focus := Focus, prompt := Prompt,
       color := Color}) ->
    Body =
        case Focus of
            false ->
                chars_to_bin(Cs);
            true ->
                {Before, After} = lists:split(Cur, Cs),
                case After of
                    [] ->
                        [chars_to_bin(Before), caret(<<" ">>)];
                    [C | Rest] ->
                        [chars_to_bin(Before), caret(<<C/utf8>>),
                         chars_to_bin(Rest)]
                end
        end,
    [accent(Prompt, Color), Body].

%%% --- accessors --------------------------------------------------------

%% @doc The current value as a UTF-8 binary.
-spec value(model()) -> binary().
value(#{chars := Cs}) -> chars_to_bin(Cs).

%% @doc Replace the value; the caret moves to the end.
-spec set_value(iodata(), model()) -> model().
set_value(Value, M) ->
    Cs = to_chars(Value),
    M#{chars := Cs, cursor := length(Cs)}.

%% @doc Empty the input.
-spec clear(model()) -> model().
clear(M) -> M#{chars := [], cursor := 0}.

-spec focus(model()) -> model().
focus(M) -> M#{focus := true}.

-spec blur(model()) -> model().
blur(M) -> M#{focus := false}.

-spec focused(model()) -> boolean().
focused(#{focus := F}) -> F.

-spec cursor(model()) -> non_neg_integer().
cursor(#{cursor := C}) -> C.

%%% --- helpers ----------------------------------------------------------

caret(Bin) -> beamtea_term:reverse(Bin).

accent(Text, Color) -> beamtea_term:paint([38, 5, Color], Text).

to_chars(Bin) when is_binary(Bin) -> unicode:characters_to_list(Bin);
to_chars(List) -> unicode:characters_to_list(iolist_to_binary(List)).

chars_to_bin(Cs) -> unicode:characters_to_binary(Cs).
