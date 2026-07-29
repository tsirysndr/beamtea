-module(beamtea_program_tests).

-include_lib("eunit/include/eunit.hrl").
-include("beamtea.hrl").

%%% A tiny counter program used to exercise the Elm loop headlessly, i.e.
%%% without a real terminal. This mirrors exactly what the runtime does with
%%% the normalized #beamtea_prog{} funs.

prog() ->
    #{init => fun(Start) -> {Start, beamtea:none()} end,
      update =>
          fun({key, up},   N) -> {N + 1, beamtea:none()};
             ({key, down}, N) -> {N - 1, beamtea:none()};
             ({key, {char, $q}}, N) -> {N, beamtea:quit()};
             (reset, _N) -> {0, beamtea:none()};
             (_Msg, N) -> {N, beamtea:none()}
          end,
      view => fun(N) -> ["count: ", integer_to_binary(N)] end}.

%% Drive one message through the normalized program.
step(#beamtea_prog{update = U}, Msg, Model) -> U(Msg, Model).

normalize_map_test() ->
    P = beamtea:normalize(prog()),
    ?assert(is_record(P, beamtea_prog)),
    ?assertEqual({7, none}, (P#beamtea_prog.init)(7)).

normalize_module_test() ->
    P = beamtea:normalize(beamtea_program_tests_mod),
    ?assertEqual({0, none}, (P#beamtea_prog.init)(undefined)).

update_and_view_test() ->
    P = beamtea:normalize(prog()),
    {M0, _} = (P#beamtea_prog.init)(0),
    {M1, none} = step(P, {key, up}, M0),
    {M2, none} = step(P, {key, up}, M1),
    {M3, none} = step(P, {key, down}, M2),
    ?assertEqual(1, M3),
    ?assertEqual(<<"count: 1">>, iolist_to_binary((P#beamtea_prog.view)(M3))).

quit_command_flows_through_test() ->
    P = beamtea:normalize(prog()),
    {5, Cmd} = step(P, {key, {char, $q}}, 5),
    ?assertEqual(quit, Cmd),
    ?assertEqual([quit], beamtea_cmd:to_effects(Cmd)).

resize_is_ignored_by_default_test() ->
    P = beamtea:normalize(prog()),
    ?assertEqual({3, none}, step(P, {resize, {80, 24}}, 3)).
