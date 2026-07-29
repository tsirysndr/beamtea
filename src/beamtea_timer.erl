%%% @doc A bubble: a countdown timer, mirroring the `timer' package in
%%% charmbracelet/bubbles.
%%%
%%% Like the spinner, it keeps itself running by re-scheduling its own tick.
%%% Start it with {@link start/1} from `init/1' (or on a key), forward messages
%%% to {@link update/2}, and check {@link timed_out/1} to react to expiry.
%%%
%%% ```
%%%   T = beamtea_timer:new(#{timeout_ms => 10000}),
%%%   {#st{timer = T}, beamtea_timer:start(T)}.
%%% '''
-module(beamtea_timer).

-export([new/1, start/1, toggle/1, update/2, view/1,
         remaining_ms/1, running/1, timed_out/1]).

-export_type([model/0]).

-opaque model() :: #{type := timer,
                     remaining := integer(),   %% milliseconds
                     interval := pos_integer(),
                     running := boolean(),
                     ref := reference()}.

%% @doc Options: `timeout_ms' (required-ish, default 60000),
%% `interval_ms' (tick granularity, default 1000).
-spec new(map()) -> model().
new(Opts) ->
    #{type => timer,
      remaining => maps:get(timeout_ms, Opts, 60000),
      interval => maps:get(interval_ms, Opts, 1000),
      running => false,
      ref => make_ref()}.

%% @doc Start (or resume) counting down; returns the command that schedules the
%% first tick.
-spec start(model()) -> beamtea:cmd().
start(#{ref := Ref, interval := Ms}) ->
    {tick, Ms, {beamtea_timer, Ref}}.

%% @doc Pause/resume. Returns the (possibly re-armed) command.
-spec toggle(model()) -> {model(), beamtea:cmd()}.
toggle(#{running := true} = M) ->
    {M#{running := false}, beamtea:none()};
toggle(#{running := false} = M) ->
    {M#{running := true}, start(M)}.

%% @doc Advance on the timer's own tick; ignore other messages.
-spec update(term(), model()) -> {model(), beamtea:cmd()}.
update({beamtea_timer, Ref}, #{ref := Ref, running := true,
                               remaining := Rem, interval := Ms} = M) ->
    NewRem = Rem - Ms,
    if
        NewRem =< 0 ->
            {M#{remaining := 0, running := false}, beamtea:none()};
        true ->
            {M#{remaining := NewRem}, {tick, Ms, {beamtea_timer, Ref}}}
    end;
update(_Msg, M) ->
    {M, beamtea:none()}.

%% @doc Render the remaining time as `MM:SS'.
-spec view(model()) -> iodata().
view(#{remaining := Rem}) ->
    beamtea_util:format_clock(Rem).

%%% --- accessors --------------------------------------------------------

-spec remaining_ms(model()) -> integer().
remaining_ms(#{remaining := Rem}) -> Rem.

-spec running(model()) -> boolean().
running(#{running := R}) -> R.

-spec timed_out(model()) -> boolean().
timed_out(#{remaining := Rem}) -> Rem =< 0.
