%%% Table demo — a selectable data table. Uses the beamtea_table bubble.
%%%
%%% Run:  rebar3 as examples shell
%%%       table_demo:main().
-module(table_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

main() -> beamtea:start(?MODULE).

init(_Flags) ->
    Cols = [{<<"Framework">>, 14}, {<<"Language">>, 10}, {<<"Stars">>, 7}],
    Rows = [[<<"beamtea">>,     <<"Erlang">>, <<"new!">>],
            [<<"Bubble Tea">>,  <<"Go">>,     <<"27k">>],
            [<<"ratatui">>,     <<"Rust">>,   <<"9k">>],
            [<<"textual">>,     <<"Python">>, <<"23k">>],
            [<<"blessed">>,     <<"JS">>,     <<"11k">>],
            [<<"Ink">>,         <<"JS">>,     <<"23k">>],
            [<<"tview">>,       <<"Go">>,     <<"10k">>],
            [<<"notcurses">>,   <<"C">>,      <<"3k">>]],
    T = beamtea_table:new(Cols, Rows, #{height => 5}),
    {T, beamtea:none()}.

update({key, {char, $q}}, T) -> {T, beamtea:quit()};
update(Msg, T) ->
    {T1, Cmd} = beamtea_table:update(Msg, T),
    {T1, Cmd}.

view(T) ->
    {_, [Name | _]} = beamtea_table:selected_row(T),
    [
     "\n  ", beamtea_color:fg(charmple, beamtea_term:bold(<<"TUI frameworks">>)), "\n\n",
     "  ", indent(beamtea_table:view(T)), "\n\n",
     "  ", beamtea_color:fg(green, <<"selected: ">>), beamtea_term:bold(Name), "\n\n",
     "  ", beamtea_term:faint(<<"↑/↓ move · q quit"/utf8>>), "\n"
    ].

%% Indent every line of a multi-line block by two spaces.
indent(IoData) ->
    Lines = beamtea_render:lines(IoData),
    lists:join(<<"\n  ">>, Lines).
