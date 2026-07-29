%%% Viewport demo — scroll through a long document. Uses the beamtea_viewport
%%% bubble plus a beamtea_progress scroll indicator.
%%%
%%% Run:  rebar3 as examples shell
%%%       viewport_demo:main().
-module(viewport_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

-record(st, {vp}).

main() -> beamtea:start(?MODULE).

init(_Flags) ->
    Lines = [io_lib:format("~3..0B  ~s", [N, lorem(N)]) || N <- lists:seq(1, 60)],
    Content = lists:join(<<"\n">>, Lines),
    VP = beamtea_viewport:set_content(Content, beamtea_viewport:new(#{height => 12})),
    {#st{vp = VP}, beamtea:none()}.

update({key, {char, $q}}, St) -> {St, beamtea:quit()};
update(Msg, #st{vp = VP} = St) ->
    {VP1, Cmd} = beamtea_viewport:update(Msg, VP),
    {St#st{vp = VP1}, Cmd}.

view(#st{vp = VP}) ->
    Pct = round(beamtea_viewport:scroll_percent(VP) * 100),
    [
     "  ", beamtea_color:fg(charmple, beamtea_term:bold(<<"beamtea viewport">>)),
     beamtea_term:faint(io_lib:format("   ~3B%", [Pct])), "\n\n",
     beamtea_viewport:view(VP), "\n\n",
     "  ", beamtea_term:faint(<<"↑/↓ scroll · space/PgDn page · home/end · q quit"/utf8>>)
    ].

lorem(N) ->
    Words = [<<"charm">>, <<"electric">>, <<"beam">>, <<"tea">>, <<"terminal">>,
             <<"raw">>, <<"unicode">>, <<"elm">>, <<"render">>, <<"bubble">>],
    Pick = fun(K) -> lists:nth((K rem length(Words)) + 1, Words) end,
    lists:join(<<" ">>, [Pick(N + I) || I <- lists:seq(0, 5)]).
