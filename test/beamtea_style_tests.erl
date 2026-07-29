-module(beamtea_style_tests).

-include_lib("eunit/include/eunit.hrl").

lines(IoData) -> beamtea_render:lines(IoData).
vis(IoData) -> beamtea_util:visible_width(IoData).

%%% --- inline styling --------------------------------------------------

foreground_test() ->
    S = beamtea_style:foreground(beamtea_style:new(), pink),
    ?assertEqual(<<"\e[38;5;212mhi\e[0m">>,
                 iolist_to_binary(beamtea_style:render(S, <<"hi">>))).

truecolor_fg_test() ->
    S = beamtea_style:foreground(beamtea_style:new(), {10, 20, 30}),
    ?assertEqual(<<"\e[38;2;10;20;30mhi\e[0m">>,
                 iolist_to_binary(beamtea_style:render(S, <<"hi">>))).

bold_and_bg_test() ->
    S = beamtea_style:bold(beamtea_style:background(beamtea_style:new(), 236)),
    Bin = iolist_to_binary(beamtea_style:render(S, <<"x">>)),
    ?assertNotEqual(nomatch, binary:match(Bin, <<"1">>)),
    ?assertNotEqual(nomatch, binary:match(Bin, <<"48;5;236">>)).

%%% --- width / align ---------------------------------------------------

width_pads_to_visible_columns_test() ->
    S = beamtea_style:width(beamtea_style:new(), 10),
    [Line] = lines(beamtea_style:render(S, <<"hi">>)),
    ?assertEqual(10, vis(Line)).

align_right_test() ->
    S = beamtea_style:align(beamtea_style:width(beamtea_style:new(), 6), right),
    ?assertEqual(<<"    hi">>, iolist_to_binary(beamtea_style:render(S, <<"hi">>))).

align_center_test() ->
    S = beamtea_style:align(beamtea_style:width(beamtea_style:new(), 6), center),
    ?assertEqual(<<"  hi  ">>, iolist_to_binary(beamtea_style:render(S, <<"hi">>))).

%%% --- padding ---------------------------------------------------------

padding_adds_rows_and_cols_test() ->
    S = beamtea_style:padding(beamtea_style:new(), 1),
    Ls = lines(beamtea_style:render(S, <<"hi">>)),
    ?assertEqual(3, length(Ls)),                 %% 1 top + content + 1 bottom
    ?assertEqual(4, vis(lists:nth(2, Ls))).      %% 1 left + "hi" + 1 right

%%% --- border ----------------------------------------------------------

border_wraps_content_test() ->
    S = beamtea_style:border(beamtea_style:new(), rounded),
    Ls = lines(beamtea_style:render(S, <<"hi">>)),
    ?assertEqual(3, length(Ls)),
    ?assertMatch(<<"╭"/utf8, _/binary>>, hd(Ls)),
    ?assertMatch(<<"╰"/utf8, _/binary>>, lists:last(Ls)),
    [?assertEqual(4, vis(L)) || L <- Ls].        %% border + "hi" + border

border_color_test() ->
    S = beamtea_style:border_foreground(
          beamtea_style:border(beamtea_style:new(), normal), pink),
    Bin = iolist_to_binary(beamtea_style:render(S, <<"x">>)),
    ?assertNotEqual(nomatch, binary:match(Bin, <<"38;5;212">>)).

%%% --- merge -----------------------------------------------------------

merge_overrides_test() ->
    A = beamtea_style:foreground(beamtea_style:bold(beamtea_style:new()), pink),
    B = beamtea_style:foreground(beamtea_style:new(), cyan),
    Merged = beamtea_style:merge(A, B),
    Bin = iolist_to_binary(beamtea_style:render(Merged, <<"x">>)),
    ?assertNotEqual(nomatch, binary:match(Bin, <<"38;5;51">>)),   %% cyan wins
    ?assertNotEqual(nomatch, binary:match(Bin, <<"1">>)).          %% bold kept

%%% --- composition -----------------------------------------------------

join_horizontal_aligns_heights_test() ->
    A = <<"a">>,               %% 1 line
    B = <<"b\nc\nd">>,         %% 3 lines
    Out = beamtea_style:join_horizontal(top, [A, <<" ">>, B]),
    Ls = lines(Out),
    ?assertEqual(3, length(Ls)),
    %% first row has both blocks' first lines
    ?assertMatch(<<"a b">>, iolist_to_binary(hd(Ls))).

join_vertical_aligns_widths_test() ->
    Out = beamtea_style:join_vertical(center, [<<"xxxx">>, <<"y">>]),
    Ls = lines(Out),
    ?assertEqual([<<"xxxx">>, <<" y  ">>], [iolist_to_binary(L) || L <- Ls]).

%%% --- overlay (beamtea_layout) ----------------------------------------

overlay_center_floats_fg_test() ->
    Bg = lists:join(<<"\n">>, [binary:copy(<<".">>, 10) || _ <- lists:seq(1, 5)]),
    Fg = <<"AB">>,
    Out = iolist_to_binary(beamtea_layout:overlay_center(Bg, Fg, {10, 5})),
    Ls = lines(Out),
    ?assertEqual(5, length(Ls)),
    %% middle row: 4 dots, "AB", 4 dots (ANSI reset markers stripped)
    ?assertEqual(<<"....AB....">>, beamtea_util:strip_ansi(lists:nth(3, Ls))),
    ?assertEqual(<<"..........">>, beamtea_util:strip_ansi(hd(Ls))),
    ?assertEqual(10, vis(lists:nth(3, Ls))).

overlay_preserves_styled_background_test() ->
    %% background with ANSI: slicing must keep it intact around the overlay
    Bg = beamtea_color:fg(cyan, binary:copy(<<"x">>, 10)),
    Out = iolist_to_binary(beamtea_layout:overlay_center(Bg, <<"O">>, {10, 1})),
    %% the cyan colour code survives and the foreground char is present
    ?assertNotEqual(nomatch, binary:match(Out, <<"38;5;51">>)),
    ?assertNotEqual(nomatch, binary:match(Out, <<"O">>)),
    %% visible width is preserved at 10
    ?assertEqual(10, vis(Out)).
