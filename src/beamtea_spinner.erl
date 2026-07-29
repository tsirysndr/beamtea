%%% @doc A bubble: an animated spinner.
%%%
%%% Inspired by charmbracelet/bubbles. A spinner is a self-contained
%%% mini-program (model + update + view). Start its animation by returning
%%% {@link tick/1} from your `init/1', then forward every message to
%%% {@link update/2} — the spinner recognises only its own tick messages and
%%% keeps itself running by returning the next tick.
%%%
%%% ```
%%%   init(_)          -> S = beamtea_spinner:new(dot),
%%%                       {#st{spin = S}, beamtea_spinner:tick(S)}.
%%%   update(Msg, St)  -> {S1, Cmd} = beamtea_spinner:update(Msg, St#st.spin),
%%%                       {St#st{spin = S1}, Cmd}.
%%%   view(St)         -> [beamtea_spinner:view(St#st.spin), " loading..."].
%%% '''
-module(beamtea_spinner).

-export([new/0, new/1, tick/1, update/2, view/1, styles/0]).

-export_type([spinner/0, style/0]).

-opaque spinner() :: #{type := spinner,
                       frames := [binary()],
                       index := non_neg_integer(),
                       fps_ms := pos_integer(),
                       ref := reference(),
                       color := 0..255 | default}.

-type style() :: line | dot | minidot | jump | points | moon | meter | pulse.

%% @doc A spinner with the default style (`dot').
-spec new() -> spinner().
new() -> new(dot).

%% @doc A spinner with the given built-in `style()' or a custom
%% `#{frames => [binary()], fps_ms => pos_integer(), color => 0..255}'.
-spec new(style() | map()) -> spinner().
new(Style) when is_atom(Style) ->
    {Frames, Fps} = frames_for(Style),
    new(#{frames => Frames, fps_ms => Fps});
new(Opts) when is_map(Opts) ->
    {DefFrames, DefFps} = frames_for(dot),
    #{type => spinner,
      frames => maps:get(frames, Opts, DefFrames),
      index => 0,
      fps_ms => maps:get(fps_ms, Opts, DefFps),
      ref => make_ref(),
      color => maps:get(color, Opts, beamtea_color:c(pink))}.

%% @doc The command that advances the animation once. Return it from `init/1'
%% (and it re-schedules itself thereafter).
-spec tick(spinner()) -> beamtea:cmd().
tick(#{ref := Ref, fps_ms := Ms}) ->
    {tick, Ms, {beamtea_spinner, Ref}}.

%% @doc Advance the spinner on its own tick; ignore everything else.
-spec update(term(), spinner()) -> {spinner(), beamtea:cmd()}.
update({beamtea_spinner, Ref}, #{ref := Ref, index := I, frames := Fs} = S) ->
    S1 = S#{index := (I + 1) rem length(Fs)},
    {S1, tick(S1)};
update(_Msg, S) ->
    {S, beamtea:none()}.

%% @doc The current frame, coloured if a colour was configured.
-spec view(spinner()) -> iodata().
view(#{frames := Fs, index := I, color := Color}) ->
    Frame = lists:nth(I + 1, Fs),
    case Color of
        default -> Frame;
        N -> beamtea_term:paint([38, 5, N], Frame)
    end.

%% @doc The list of built-in style names.
-spec styles() -> [style()].
styles() -> [line, dot, minidot, jump, points, moon, meter, pulse].

frames_for(line)    -> {[<<"|">>, <<"/">>, <<"-">>, <<"\\">>], 100};
frames_for(dot)     -> {[<<"⠋"/utf8>>, <<"⠙"/utf8>>, <<"⠹"/utf8>>, <<"⠸"/utf8>>,
                         <<"⠼"/utf8>>, <<"⠴"/utf8>>, <<"⠦"/utf8>>, <<"⠧"/utf8>>,
                         <<"⠇"/utf8>>, <<"⠏"/utf8>>], 80};
frames_for(minidot) -> {[<<"⣾"/utf8>>, <<"⣽"/utf8>>, <<"⣻"/utf8>>, <<"⢿"/utf8>>,
                         <<"⡿"/utf8>>, <<"⣟"/utf8>>, <<"⣯"/utf8>>, <<"⣷"/utf8>>], 80};
frames_for(jump)    -> {[<<"⢄"/utf8>>, <<"⢂"/utf8>>, <<"⢁"/utf8>>, <<"⡁"/utf8>>,
                         <<"⡈"/utf8>>, <<"⡐"/utf8>>, <<"⡠"/utf8>>], 100};
frames_for(points)  -> {[<<"∙∙∙"/utf8>>, <<"●∙∙"/utf8>>, <<"∙●∙"/utf8>>,
                         <<"∙∙●"/utf8>>], 140};
frames_for(moon)    -> {[<<"🌑"/utf8>>, <<"🌒"/utf8>>, <<"🌓"/utf8>>, <<"🌔"/utf8>>,
                         <<"🌕"/utf8>>, <<"🌖"/utf8>>, <<"🌗"/utf8>>, <<"🌘"/utf8>>], 120};
frames_for(meter)   -> {[<<"▱▱▱"/utf8>>, <<"▰▱▱"/utf8>>, <<"▰▰▱"/utf8>>,
                         <<"▰▰▰"/utf8>>, <<"▰▰▱"/utf8>>, <<"▰▱▱"/utf8>>], 120};
frames_for(pulse)   -> {[<<"█"/utf8>>, <<"▓"/utf8>>, <<"▒"/utf8>>, <<"░"/utf8>>,
                         <<"▒"/utf8>>, <<"▓"/utf8>>], 120}.
