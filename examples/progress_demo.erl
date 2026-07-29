%%% Progress demo — a self-filling gradient progress bar. Combines the
%%% beamtea_progress bubble with a beamtea:every/2 timer.
%%%
%%% Run:  ./bin/beamtea-run progress_demo
-module(progress_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

-record(st, {bar, done = false}).

main() -> beamtea:start(?MODULE).

init(_Flags) ->
    Bar = beamtea_progress:new(#{width => 40}),
    {#st{bar = Bar}, beamtea:every(120, tick)}.

update(tick, #st{bar = Bar} = St) ->
    Bar1 = beamtea_progress:incr(0.025, Bar),
    {St#st{bar = Bar1, done = beamtea_progress:percent(Bar1) >= 1.0},
     beamtea:none()};
update({key, {char, $r}}, #st{bar = Bar} = St) ->
    {St#st{bar = beamtea_progress:set(0.0, Bar), done = false}, beamtea:none()};
update({key, {char, $q}}, St) -> {St, beamtea:quit()};
update(_Msg, St) -> {St, beamtea:none()}.

view(#st{bar = Bar, done = Done}) ->
    Status = case Done of
                 true  -> beamtea_color:fg(green, beamtea_term:bold(<<"✓ complete"/utf8>>));
                 false -> beamtea_term:faint(<<"loading…"/utf8>>)
             end,
    [
     "\n  ", beamtea_color:fg(charmple, beamtea_term:bold(<<"beamtea progress">>)), "\n\n",
     "  ", beamtea_progress:view(Bar), "\n\n",
     "  ", Status, "\n\n",
     "  ", beamtea_term:faint(<<"r restart · q quit"/utf8>>), "\n"
    ].
