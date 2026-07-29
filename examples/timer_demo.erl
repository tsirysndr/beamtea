%%% Timer demo — a 10-second countdown. Uses the beamtea_timer bubble.
%%%
%%% Run:  ./bin/beamtea-run timer_demo
-module(timer_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

-record(st, {timer}).

main() -> beamtea:start(?MODULE).

init(_Flags) ->
    %% Start paused; press space to begin the countdown.
    T = beamtea_timer:new(#{timeout_ms => 10000, interval_ms => 1000}),
    {#st{timer = T}, beamtea:none()}.

update({key, {char, $\s}}, #st{timer = T} = St) ->
    {T1, Cmd} = beamtea_timer:toggle(T),
    {St#st{timer = T1}, Cmd};
update({key, {char, $q}}, St) -> {St, beamtea:quit()};
update(Msg, #st{timer = T} = St) ->
    {T1, Cmd} = beamtea_timer:update(Msg, T),
    {St#st{timer = T1}, Cmd}.

view(#st{timer = T}) ->
    {Label, Color} =
        case {beamtea_timer:timed_out(T), beamtea_timer:running(T)} of
            {true, _}      -> {<<"⏰  time's up!"/utf8>>, red};
            {false, true}  -> {<<"counting down…"/utf8>>, cyan};
            {false, false} -> {<<"paused (space to start)">>, orange}
        end,
    [
     "\n  ", beamtea_color:fg(charmple, beamtea_term:bold(<<"beamtea timer">>)), "\n\n",
     "  ", beamtea_color:fg(Color, beamtea_term:bold(beamtea_timer:view(T))), "\n\n",
     "  ", beamtea_color:fg(Color, Label), "\n\n",
     "  ", beamtea_term:faint(<<"space start/pause · q quit"/utf8>>), "\n"
    ].
