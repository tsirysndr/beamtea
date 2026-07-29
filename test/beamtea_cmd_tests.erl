-module(beamtea_cmd_tests).

-include_lib("eunit/include/eunit.hrl").

none_variants_test() ->
    ?assertEqual([], beamtea_cmd:to_effects(none)),
    ?assertEqual([], beamtea_cmd:to_effects(ok)),
    ?assertEqual([], beamtea_cmd:to_effects(undefined)).

quit_test() ->
    ?assertEqual([quit], beamtea_cmd:to_effects(quit)).

msg_test() ->
    ?assertEqual([{msg, hello}], beamtea_cmd:to_effects({msg, hello})).

tick_test() ->
    ?assertEqual([{after_ms, 100, tick}],
                 beamtea_cmd:to_effects({tick, 100, tick})).

every_test() ->
    ?assertEqual([{every, 250, frame}],
                 beamtea_cmd:to_effects({every, 250, frame})).

task_forms_test() ->
    F = fun() -> done end,
    ?assertEqual([{task, F}], beamtea_cmd:to_effects({task, F})),
    ?assertEqual([{task, F}], beamtea_cmd:to_effects(F)).

batch_flattens_test() ->
    Cmd = {batch, [quit, {msg, a}, none, {tick, 5, b}]},
    ?assertEqual([quit, {msg, a}, {after_ms, 5, b}],
                 beamtea_cmd:to_effects(Cmd)).

nested_batch_test() ->
    Cmd = {batch, [{batch, [{msg, a}]}, {seq, [{msg, b}]}]},
    ?assertEqual([{msg, a}, {msg, b}], beamtea_cmd:to_effects(Cmd)).

bare_list_test() ->
    ?assertEqual([quit, {msg, x}],
                 beamtea_cmd:to_effects([quit, {msg, x}])).

bad_command_raises_test() ->
    ?assertError({bad_command, wibble}, beamtea_cmd:to_effects(wibble)).

%%% Constructor helpers on the public module produce the expected commands.
constructors_test() ->
    ?assertEqual(none, beamtea:none()),
    ?assertEqual(quit, beamtea:quit()),
    ?assertEqual({batch, [quit]}, beamtea:batch([quit])),
    ?assertEqual({seq, [quit]}, beamtea:sequence([quit])),
    ?assertEqual({msg, hi}, beamtea:msg(hi)),
    ?assertEqual({tick, 10, t}, beamtea:tick(10, t)),
    ?assertEqual({every, 20, e}, beamtea:every(20, e)).
