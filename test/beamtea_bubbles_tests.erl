-module(beamtea_bubbles_tests).

-include_lib("eunit/include/eunit.hrl").

%%% ===================================================================
%%% Colour palette
%%% ===================================================================

color_names_resolve_test() ->
    lists:foreach(
      fun(Name) ->
              C = beamtea_color:c(Name),
              ?assert(is_integer(C) andalso C >= 0 andalso C =< 255)
      end, beamtea_color:names()).

color_fg_test() ->
    ?assertEqual(<<"\e[38;5;205mx\e[0m">>,
                 iolist_to_binary(beamtea_color:fg(hotpink, "x"))).

%%% ===================================================================
%%% Spinner
%%% ===================================================================

spinner_advances_on_own_tick_test() ->
    S0 = beamtea_spinner:new(line),
    {tick, _Ms, TickMsg} = beamtea_spinner:tick(S0),
    {S1, {tick, _, _}} = beamtea_spinner:update(TickMsg, S0),
    ?assertNotEqual(iolist_to_binary(beamtea_spinner:view(S0)),
                    iolist_to_binary(beamtea_spinner:view(S1))).

spinner_ignores_foreign_messages_test() ->
    S0 = beamtea_spinner:new(line),
    ?assertEqual({S0, none},
                 beamtea_spinner:update({beamtea_spinner, make_ref()}, S0)),
    ?assertEqual({S0, none}, beamtea_spinner:update({key, up}, S0)).

spinner_wraps_around_test() ->
    S0 = beamtea_spinner:new(line),  %% 4 frames
    {tick, _, T} = beamtea_spinner:tick(S0),
    Advance = fun(S) -> {S1, _} = beamtea_spinner:update(T, S), S1 end,
    S4 = lists:foldl(fun(_, S) -> Advance(S) end, S0, lists:seq(1, 4)),
    ?assertEqual(iolist_to_binary(beamtea_spinner:view(S0)),
                 iolist_to_binary(beamtea_spinner:view(S4))).

%%% ===================================================================
%%% Text input
%%% ===================================================================

ti(Keys) ->
    M0 = beamtea_textinput:focus(beamtea_textinput:new()),
    lists:foldl(fun(K, M) ->
                        {M1, _} = beamtea_textinput:update({key, K}, M),
                        M1
                end, M0, Keys).

textinput_types_utf8_test() ->
    M = ti([{char, $h}, {char, $i}, {char, 16#E9}]),
    ?assertEqual(<<"hié"/utf8>>, beamtea_textinput:value(M)).

textinput_backspace_test() ->
    M = ti([{char, $a}, {char, $b}, {char, $c}, backspace]),
    ?assertEqual(<<"ab">>, beamtea_textinput:value(M)).

textinput_caret_movement_and_insert_test() ->
    %% type "ac", move left, insert "b" -> "abc"
    M = ti([{char, $a}, {char, $c}, left, {char, $b}]),
    ?assertEqual(<<"abc">>, beamtea_textinput:value(M)),
    ?assertEqual(2, beamtea_textinput:cursor(M)).

textinput_home_end_delete_test() ->
    M0 = ti([{char, $x}, {char, $y}, {char, $z}]),
    {M1, _} = beamtea_textinput:update({key, home}, M0),
    {M2, _} = beamtea_textinput:update({key, delete}, M1),
    ?assertEqual(<<"yz">>, beamtea_textinput:value(M2)).

textinput_limit_test() ->
    M0 = beamtea_textinput:focus(beamtea_textinput:new(#{limit => 2})),
    M = lists:foldl(fun(K, M) ->
                            {M1, _} = beamtea_textinput:update({key, K}, M), M1
                    end, M0, [{char, $a}, {char, $b}, {char, $c}]),
    ?assertEqual(<<"ab">>, beamtea_textinput:value(M)).

textinput_ignores_keys_when_blurred_test() ->
    M0 = beamtea_textinput:new(),   %% not focused
    {M1, none} = beamtea_textinput:update({key, {char, $a}}, M0),
    ?assertEqual(<<>>, beamtea_textinput:value(M1)).

textinput_set_and_clear_test() ->
    M0 = beamtea_textinput:set_value(<<"hello">>, beamtea_textinput:new()),
    ?assertEqual(<<"hello">>, beamtea_textinput:value(M0)),
    ?assertEqual(<<>>, beamtea_textinput:value(beamtea_textinput:clear(M0))).

%%% ===================================================================
%%% Progress
%%% ===================================================================

progress_clamps_test() ->
    P = beamtea_progress:new(),
    ?assertEqual(1.0, beamtea_progress:percent(beamtea_progress:set(5.0, P))),
    ?assertEqual(0.0, beamtea_progress:percent(beamtea_progress:set(-1.0, P))).

progress_incr_test() ->
    P0 = beamtea_progress:new(),
    P1 = beamtea_progress:incr(0.25, P0),
    P2 = beamtea_progress:incr(0.25, P1),
    ?assertEqual(0.5, beamtea_progress:percent(P2)).

progress_view_has_percentage_test() ->
    P = beamtea_progress:set(0.5, beamtea_progress:new(#{width => 10})),
    Bin = iolist_to_binary(beamtea_progress:view(P)),
    ?assertNotEqual(nomatch, binary:match(Bin, <<"50%">>)).

%%% ===================================================================
%%% List
%%% ===================================================================

lst() ->
    beamtea_list:new([<<"a">>, <<"b">>, <<"c">>], #{title => <<"pick">>}).

list_selection_moves_test() ->
    L0 = lst(),
    ?assertEqual({0, <<"a">>}, beamtea_list:selected(L0)),
    {L1, _} = beamtea_list:update({key, down}, L0),
    ?assertEqual({1, <<"b">>}, beamtea_list:selected(L1)),
    {L2, _} = beamtea_list:update({key, {char, $j}}, L1),
    ?assertEqual({2, <<"c">>}, beamtea_list:selected(L2)).

list_clamps_at_edges_test() ->
    L0 = lst(),
    {L1, _} = beamtea_list:update({key, up}, L0),   %% already at top
    ?assertEqual({0, <<"a">>}, beamtea_list:selected(L1)),
    {L2, _} = beamtea_list:update({key, 'end'}, L0),
    ?assertEqual({2, <<"c">>}, beamtea_list:selected(L2)),
    {L3, _} = beamtea_list:update({key, down}, L2),  %% already at bottom
    ?assertEqual({2, <<"c">>}, beamtea_list:selected(L3)).

list_scrolls_window_test() ->
    Items = [integer_to_binary(N) || N <- lists:seq(1, 20)],
    L0 = beamtea_list:new(Items, #{height => 5}),
    L1 = lists:foldl(fun(_, L) ->
                             {L2, _} = beamtea_list:update({key, down}, L), L2
                     end, L0, lists:seq(1, 10)),
    ?assertEqual({10, <<"11">>}, beamtea_list:selected(L1)),
    %% the selected item must appear in the rendered window
    Bin = iolist_to_binary(beamtea_list:view(L1)),
    ?assertNotEqual(nomatch, binary:match(Bin, <<"11">>)),
    %% and item 1 must have scrolled out of view
    ?assertEqual(nomatch, binary:match(Bin, <<"1\n">>)).

list_empty_selected_test() ->
    ?assertEqual(none, beamtea_list:selected(beamtea_list:new([]))).

list_set_items_clamps_cursor_test() ->
    L0 = lst(),
    {L1, _} = beamtea_list:update({key, 'end'}, L0),   %% cursor at 2
    L2 = beamtea_list:set_items([<<"only">>], L1),
    ?assertEqual({0, <<"only">>}, beamtea_list:selected(L2)).
