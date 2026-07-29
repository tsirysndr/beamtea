%%% Stopwatch — demonstrates commands & timers via beamtea:every/2.
%%%
%%% Run:  rebar3 as examples shell
%%%       stopwatch:main().
-module(stopwatch).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

-define(TICK_MS, 100).

-record(st, {elapsed_ms = 0, running = true}).

main() -> beamtea:start(?MODULE).

init(_Flags) ->
    %% Kick off a repeating tick every 100ms.
    {#st{}, beamtea:every(?TICK_MS, tick)}.

update(tick, #st{running = true, elapsed_ms = E} = St) ->
    {St#st{elapsed_ms = E + ?TICK_MS}, beamtea:none()};
update(tick, St) ->
    {St, beamtea:none()};
update({key, {char, $\s}}, #st{running = R} = St) ->
    {St#st{running = not R}, beamtea:none()};
update({key, {char, $r}}, St) ->
    {St#st{elapsed_ms = 0}, beamtea:none()};
update({key, {char, $q}}, St) ->
    {St, beamtea:quit()};
update(_Msg, St) ->
    {St, beamtea:none()}.

view(#st{elapsed_ms = E, running = Running}) ->
    {Status, Color} = case Running of
                          true  -> {<<"running">>, green};
                          false -> {<<"paused">>, orange}
                      end,
    [
     "\n  ", beamtea_color:fg(charmple, beamtea_term:bold(<<"beamtea stopwatch">>)), "\n\n",
     "  ", beamtea_color:fg(Color, beamtea_term:bold(format_time(E))),
     "   ", beamtea_color:fg(Color, Status), "\n\n",
     "  ", beamtea_term:faint(<<"space start/pause · r reset · q quit"/utf8>>), "\n"
    ].

format_time(Ms) ->
    Total = Ms div 1000,
    Mins = Total div 60,
    Secs = Total rem 60,
    Cents = (Ms rem 1000) div 10,
    io_lib:format("~2..0B:~2..0B.~2..0B", [Mins, Secs, Cents]).
