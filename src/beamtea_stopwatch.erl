%%% @doc A bubble: a count-up stopwatch, mirroring the `stopwatch' package in
%%% charmbracelet/bubbles.
%%%
%%% Self-ticking like {@link beamtea_timer}. Start it, forward messages to
%%% {@link update/2}, and read {@link elapsed_ms/1}.
-module(beamtea_stopwatch).

-export([new/0, new/1, start/1, toggle/1, reset/1, update/2, view/1,
         elapsed_ms/1, running/1]).

-export_type([model/0]).

-opaque model() :: #{type := stopwatch,
                     elapsed := non_neg_integer(),
                     interval := pos_integer(),
                     running := boolean(),
                     ref := reference()}.

%% @equiv new(#{})
-spec new() -> model().
new() -> new(#{}).

%% @doc Options: `interval_ms' (tick granularity, default 100).
-spec new(map()) -> model().
new(Opts) ->
    #{type => stopwatch,
      elapsed => 0,
      interval => maps:get(interval_ms, Opts, 100),
      running => false,
      ref => make_ref()}.

%% @doc Start (or resume); returns the command scheduling the first tick.
-spec start(model()) -> beamtea:cmd().
start(#{ref := Ref, interval := Ms}) ->
    {tick, Ms, {beamtea_stopwatch, Ref}}.

%% @doc Pause/resume.
-spec toggle(model()) -> {model(), beamtea:cmd()}.
toggle(#{running := true} = M) ->
    {M#{running := false}, beamtea:none()};
toggle(#{running := false} = M) ->
    {M#{running := true}, start(M)}.

%% @doc Reset the elapsed time to zero (keeps running state).
-spec reset(model()) -> model().
reset(M) -> M#{elapsed := 0}.

%% @doc Advance on its own tick; ignore other messages.
-spec update(term(), model()) -> {model(), beamtea:cmd()}.
update({beamtea_stopwatch, Ref}, #{ref := Ref, running := true,
                                   elapsed := E, interval := Ms} = M) ->
    {M#{elapsed := E + Ms}, {tick, Ms, {beamtea_stopwatch, Ref}}};
update(_Msg, M) ->
    {M, beamtea:none()}.

%% @doc Render elapsed time as `MM:SS.CS'.
-spec view(model()) -> iodata().
view(#{elapsed := E}) ->
    beamtea_util:format_stopwatch(E).

-spec elapsed_ms(model()) -> non_neg_integer().
elapsed_ms(#{elapsed := E}) -> E.

-spec running(model()) -> boolean().
running(#{running := R}) -> R.
