-module(beamtea_components_tests).

-include_lib("eunit/include/eunit.hrl").

%%% ===================================================================
%%% util
%%% ===================================================================

format_clock_test() ->
    ?assertEqual(<<"00:00">>, iolist_to_binary(beamtea_util:format_clock(0))),
    ?assertEqual(<<"01:05">>, iolist_to_binary(beamtea_util:format_clock(65000))),
    ?assertEqual(<<"1:00:00">>, iolist_to_binary(beamtea_util:format_clock(3600000))).

format_stopwatch_test() ->
    ?assertEqual(<<"00:01.50">>,
                 iolist_to_binary(beamtea_util:format_stopwatch(1500))).

truncate_test() ->
    ?assertEqual(<<"hello">>, beamtea_util:truncate(<<"hello">>, 10)),
    ?assertEqual(<<"hel…"/utf8>>, beamtea_util:truncate(<<"hello">>, 4)).

pad_right_test() ->
    ?assertEqual(<<"hi   ">>, iolist_to_binary(beamtea_util:pad_right(<<"hi">>, 5))),
    ?assertEqual(<<"toolong">>, iolist_to_binary(beamtea_util:pad_right(<<"toolong">>, 3))).

%%% ===================================================================
%%% keybind + help
%%% ===================================================================

keybind_matches_test() ->
    Up = beamtea_keybind:new([up, {char, $k}], {<<"↑/k">>, <<"up">>}),
    ?assert(beamtea_keybind:matches(up, Up)),
    ?assert(beamtea_keybind:matches({char, $k}, Up)),
    ?assertNot(beamtea_keybind:matches(down, Up)).

keybind_disabled_never_matches_test() ->
    B = beamtea_keybind:set_enabled(
          false, beamtea_keybind:new([up], {<<"↑">>, <<"up">>})),
    ?assertNot(beamtea_keybind:matches(up, B)).

keybind_matches_any_test() ->
    A = beamtea_keybind:new([up], {<<"↑">>, <<"up">>}),
    B = beamtea_keybind:new([down], {<<"↓">>, <<"down">>}),
    ?assert(beamtea_keybind:matches_any(down, [A, B])),
    ?assertNot(beamtea_keybind:matches_any(left, [A, B])).

help_short_omits_disabled_test() ->
    H = beamtea_help:new(),
    Up = beamtea_keybind:new([up], {<<"↑">>, <<"up">>}),
    Off = beamtea_keybind:set_enabled(
            false, beamtea_keybind:new([down], {<<"↓">>, <<"down">>})),
    Bin = iolist_to_binary(beamtea_help:short(H, [Up, Off])),
    ?assertNotEqual(nomatch, binary:match(Bin, <<"up">>)),
    ?assertEqual(nomatch, binary:match(Bin, <<"down">>)).

%%% ===================================================================
%%% paginator
%%% ===================================================================

paginator_pages_test() ->
    P = beamtea_paginator:new(#{total_items => 42, per_page => 10}),
    ?assertEqual(5, beamtea_paginator:total_pages(P)),
    ?assertEqual(0, beamtea_paginator:page(P)).

paginator_navigation_test() ->
    P0 = beamtea_paginator:new(#{total_items => 25, per_page => 10}),
    {P1, _} = beamtea_paginator:update({key, right}, P0),
    ?assertEqual(1, beamtea_paginator:page(P1)),
    {P2, _} = beamtea_paginator:update({key, 'end'}, P1),
    ?assertEqual(2, beamtea_paginator:page(P2)),
    {P3, _} = beamtea_paginator:update({key, right}, P2),  %% clamp at last
    ?assertEqual(2, beamtea_paginator:page(P3)),
    ?assert(beamtea_paginator:on_last_page(P3)).

paginator_slice_bounds_test() ->
    P0 = beamtea_paginator:new(#{total_items => 25, per_page => 10}),
    ?assertEqual({0, 10}, beamtea_paginator:slice_bounds(P0, 25)),
    {P1, _} = beamtea_paginator:update({key, 'end'}, P0),
    ?assertEqual({20, 25}, beamtea_paginator:slice_bounds(P1, 25)).

%%% ===================================================================
%%% viewport
%%% ===================================================================

viewport_scrolls_test() ->
    Content = lists:join(<<"\n">>, [integer_to_binary(N) || N <- lists:seq(1, 30)]),
    V0 = beamtea_viewport:set_content(Content, beamtea_viewport:new(#{height => 5})),
    ?assert(beamtea_viewport:at_top(V0)),
    {V1, _} = beamtea_viewport:update({key, page_down}, V0),
    ?assertEqual(5, beamtea_viewport:offset(V1)),
    {V2, _} = beamtea_viewport:update({key, 'end'}, V1),
    ?assert(beamtea_viewport:at_bottom(V2)),
    ?assertEqual(25, beamtea_viewport:offset(V2)),
    ?assertEqual(1.0, beamtea_viewport:scroll_percent(V2)).

viewport_clamps_test() ->
    V0 = beamtea_viewport:set_content(<<"a\nb\nc">>, beamtea_viewport:new(#{height => 10})),
    {V1, _} = beamtea_viewport:update({key, down}, V0),
    ?assertEqual(0, beamtea_viewport:offset(V1)).  %% content shorter than height

%%% ===================================================================
%%% timer + stopwatch
%%% ===================================================================

timer_counts_down_test() ->
    T0 = beamtea_timer:new(#{timeout_ms => 3000, interval_ms => 1000}),
    {T1, Cmd} = beamtea_timer:toggle(T0),
    ?assert(beamtea_timer:running(T1)),
    {tick, 1000, TickMsg} = Cmd,
    {T2, _} = beamtea_timer:update(TickMsg, T1),
    ?assertEqual(2000, beamtea_timer:remaining_ms(T2)),
    {T3, _} = beamtea_timer:update(TickMsg, T2),
    {T4, none} = beamtea_timer:update(TickMsg, T3),
    ?assertEqual(0, beamtea_timer:remaining_ms(T4)),
    ?assert(beamtea_timer:timed_out(T4)),
    ?assertNot(beamtea_timer:running(T4)).

stopwatch_counts_up_test() ->
    S0 = beamtea_stopwatch:new(#{interval_ms => 100}),
    {S1, Cmd} = beamtea_stopwatch:toggle(S0),
    {tick, 100, TickMsg} = Cmd,
    {S2, _} = beamtea_stopwatch:update(TickMsg, S1),
    {S3, _} = beamtea_stopwatch:update(TickMsg, S2),
    ?assertEqual(200, beamtea_stopwatch:elapsed_ms(S3)),
    ?assertEqual(0, beamtea_stopwatch:elapsed_ms(beamtea_stopwatch:reset(S3))).

stopwatch_paused_does_not_advance_test() ->
    S0 = beamtea_stopwatch:new(),   %% not running
    %% A tick while paused is ignored (the update clause requires running).
    {S1, none} = beamtea_stopwatch:update({beamtea_stopwatch, make_ref()}, S0),
    ?assertEqual(0, beamtea_stopwatch:elapsed_ms(S1)).

%%% ===================================================================
%%% table
%%% ===================================================================

tbl() ->
    Cols = [{<<"Name">>, 10}, {<<"Lang">>, 8}],
    Rows = [[<<"beamtea">>, <<"Erlang">>],
            [<<"bubbletea">>, <<"Go">>],
            [<<"iced">>, <<"Rust">>]],
    beamtea_table:new(Cols, Rows, #{height => 2}).

table_selection_test() ->
    T0 = tbl(),
    ?assertEqual({0, [<<"beamtea">>, <<"Erlang">>]}, beamtea_table:selected_row(T0)),
    {T1, _} = beamtea_table:update({key, down}, T0),
    ?assertEqual({1, [<<"bubbletea">>, <<"Go">>]}, beamtea_table:selected_row(T1)).

table_view_has_header_test() ->
    Bin = iolist_to_binary(beamtea_table:view(tbl())),
    ?assertNotEqual(nomatch, binary:match(Bin, <<"Name">>)),
    ?assertNotEqual(nomatch, binary:match(Bin, <<"Lang">>)).

table_set_rows_clamps_test() ->
    T0 = tbl(),
    {T1, _} = beamtea_table:update({key, 'end'}, T0),
    T2 = beamtea_table:set_rows([[<<"only">>, <<"x">>]], T1),
    ?assertEqual({0, [<<"only">>, <<"x">>]}, beamtea_table:selected_row(T2)).

%%% ===================================================================
%%% textarea
%%% ===================================================================

ta(Keys) ->
    M0 = beamtea_textarea:focus(beamtea_textarea:new()),
    lists:foldl(fun(K, M) ->
                        {M1, _} = beamtea_textarea:update({key, K}, M), M1
                end, M0, Keys).

textarea_multiline_test() ->
    M = ta([{char, $a}, {char, $b}, enter, {char, $c}]),
    ?assertEqual(<<"ab\nc">>, beamtea_textarea:value(M)),
    ?assertEqual(2, beamtea_textarea:line_count(M)),
    ?assertEqual({1, 1}, beamtea_textarea:cursor(M)).

textarea_backspace_merges_lines_test() ->
    %% "ab\nc", caret at start of line 2, backspace merges -> "abc"
    M0 = ta([{char, $a}, {char, $b}, enter, {char, $c}, home]),
    {M1, _} = beamtea_textarea:update({key, backspace}, M0),
    ?assertEqual(<<"abc">>, beamtea_textarea:value(M1)),
    ?assertEqual(1, beamtea_textarea:line_count(M1)).

textarea_arrow_navigation_test() ->
    %% two lines, go up then insert
    M0 = ta([{char, $a}, {char, $b}, enter, {char, $c}, {char, $d}]),
    {M1, _} = beamtea_textarea:update({key, up}, M0),
    {M2, _} = beamtea_textarea:update({key, home}, M1),
    {M3, _} = beamtea_textarea:update({key, {char, $X}}, M2),
    ?assertEqual(<<"Xab\ncd">>, beamtea_textarea:value(M3)).

textarea_set_value_test() ->
    M = beamtea_textarea:set_value(<<"one\ntwo\nthree">>, beamtea_textarea:new()),
    ?assertEqual(3, beamtea_textarea:line_count(M)),
    ?assertEqual(<<"one\ntwo\nthree">>, beamtea_textarea:value(M)).

%%% ===================================================================
%%% cursor
%%% ===================================================================

cursor_blinks_test() ->
    C0 = beamtea_cursor:new(),
    ?assert(beamtea_cursor:visible(C0)),
    {tick, _Ms, TickMsg} = beamtea_cursor:blink(C0),
    {C1, {tick, _, _}} = beamtea_cursor:update(TickMsg, C0),
    ?assertNot(beamtea_cursor:visible(C1)),
    {C2, _} = beamtea_cursor:update(TickMsg, C1),
    ?assert(beamtea_cursor:visible(C2)).

cursor_static_and_hidden_test() ->
    Static = beamtea_cursor:set_mode(static, beamtea_cursor:new()),
    ?assertEqual(<<"\e[7mx\e[0m">>, iolist_to_binary(beamtea_cursor:view(Static, <<"x">>))),
    Hidden = beamtea_cursor:set_mode(hidden, beamtea_cursor:new()),
    ?assertEqual(<<"x">>, iolist_to_binary(beamtea_cursor:view(Hidden, <<"x">>))),
    ?assertNot(beamtea_cursor:visible(Hidden)).

%%% ===================================================================
%%% filepicker (uses a real temp dir)
%%% ===================================================================

filepicker_lists_and_navigates_test() ->
    Dir = make_temp_tree(),
    try
        FP0 = beamtea_filepicker:new(#{path => Dir}),
        ?assertEqual(Dir, beamtea_filepicker:path(FP0)),
        %% directories sort first: first entry should be the subdir "adir"
        ?assertMatch({<<"adir">>, true}, beamtea_filepicker:highlighted(FP0)),
        %% descend into it
        {FP1, _} = beamtea_filepicker:update({key, enter}, FP0),
        ?assertEqual(filename:join(Dir, "adir"), beamtea_filepicker:path(FP1)),
        %% ascend back
        {FP2, _} = beamtea_filepicker:update({key, backspace}, FP1),
        ?assertEqual(Dir, beamtea_filepicker:path(FP2)),
        %% move to the file and select it
        {FP3, _} = beamtea_filepicker:update({key, down}, FP2),
        {FP4, _} = beamtea_filepicker:update({key, enter}, FP3),
        ?assertEqual(filename:join(Dir, "zfile.txt"),
                     beamtea_filepicker:did_select_file(FP4))
    after
        cleanup_temp_tree(Dir)
    end.

make_temp_tree() ->
    Base = filename:join(["/tmp", "beamtea_fp_test_" ++ os:getpid()]),
    ok = filelib:ensure_dir(filename:join(Base, "dummy")),
    ok = file:make_dir(filename:join(Base, "adir")),
    ok = file:write_file(filename:join(Base, "zfile.txt"), <<"hi">>),
    Base.

cleanup_temp_tree(Dir) ->
    file:delete(filename:join(Dir, "zfile.txt")),
    file:del_dir(filename:join(Dir, "adir")),
    file:del_dir(Dir).
