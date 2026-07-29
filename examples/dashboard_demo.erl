%%% Dashboard demo — a grid of styled "stat cards" composed with
%%% beamtea_style:join_horizontal/2 and join_vertical/2. A pure showcase of the
%%% styling layer's composition (press q to quit).
%%%
%%% Run:  ./bin/beamtea-run dashboard_demo
-module(dashboard_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

main() -> beamtea:start(?MODULE).

init(_Flags) -> {ok, beamtea:none()}.

update({key, {char, $q}}, St) -> {St, beamtea:quit()};
update(_Msg, St) -> {St, beamtea:none()}.

view(_St) ->
    Title = beamtea_style:render(
              beamtea_style:bold(beamtea_style:foreground(beamtea_style:new(), charmple)),
              <<"beamtea dashboard">>),
    Row1 = beamtea_style:join_horizontal(
             top, [card(<<"USERS">>, <<"1,204">>, green, <<"▲ 12%"/utf8>>), gap(),
                   card(<<"REVENUE">>, <<"$8.4k">>, pink, <<"▲ 4%"/utf8>>)]),
    Row2 = beamtea_style:join_horizontal(
             top, [card(<<"LATENCY">>, <<"42ms">>, cyan, <<"▼ 8ms"/utf8>>), gap(),
                   card(<<"ERRORS">>, <<"3">>, red, <<"▲ 2"/utf8>>)]),
    Grid = beamtea_style:join_vertical(left, [Row1, <<>>, Row2]),
    Help = beamtea_style:render(beamtea_style:faint(beamtea_style:new()),
                                <<"composed with join_horizontal / join_vertical · q quit"/utf8>>),
    Body = beamtea_style:join_vertical(left, [Title, <<>>, Grid, <<>>, Help]),
    ["\n  ", indent(Body)].

%% One stat card: a rounded, accent-bordered box with a label, a big value and
%% a delta line.
card(Label, Value, Accent, Delta) ->
    Content = beamtea_style:join_vertical(
                left,
                [beamtea_style:render(beamtea_style:faint(beamtea_style:new()), Label),
                 <<>>,
                 beamtea_style:render(
                   beamtea_style:bold(beamtea_style:foreground(beamtea_style:new(), Accent)),
                   Value),
                 beamtea_style:render(
                   beamtea_style:foreground(beamtea_style:new(), Accent), Delta)]),
    S0 = beamtea_style:border(beamtea_style:new(), rounded),
    S1 = beamtea_style:border_foreground(S0, Accent),
    S2 = beamtea_style:padding(S1, {1, 3}),
    S3 = beamtea_style:width(S2, 22),
    beamtea_style:render(S3, Content).

gap() -> <<"  ">>.

indent(IoData) -> lists:join(<<"\n  ">>, beamtea_render:lines(IoData)).
