-module(beamtea_layout_tests).

-include_lib("eunit/include/eunit.hrl").

lines(IoData) -> beamtea_render:lines(IoData).

center_horizontally_test() ->
    %% "ab" (width 2) in 10 cols -> left pad (10-2)/2 = 4 spaces.
    Out = beamtea_layout:place(<<"ab">>, {10, 1}, #{halign => center, valign => top}),
    ?assertEqual([<<"    ab">>], lines(Out)).

center_vertically_test() ->
    %% one line in 5 rows -> (5-1)/2 = 2 blank lines on top.
    Out = beamtea_layout:place(<<"x">>, {1, 5}, #{halign => left, valign => middle}),
    ?assertEqual([<<>>, <<>>, <<"x">>], lines(Out)).

center_both_test() ->
    Out = beamtea_layout:center(<<"hi">>, {8, 3}),
    %% vertical: (3-1)/2 = 1 blank; horizontal: (8-2)/2 = 3 spaces
    ?assertEqual([<<>>, <<"   hi">>], lines(Out)).

block_keeps_internal_alignment_test() ->
    %% Two lines of different width are shifted by the same amount (block width).
    Out = beamtea_layout:place(<<"aa\nb">>, {10, 2}, #{halign => center, valign => top}),
    %% block width = 2 -> pad = (10-2)/2 = 4 for both lines
    ?assertEqual([<<"    aa">>, <<"    b">>], lines(Out)).

right_and_bottom_test() ->
    Out = beamtea_layout:place(<<"ab">>, {6, 3}, #{halign => right, valign => bottom}),
    %% right: 6-2 = 4 spaces; bottom: 3-1 = 2 blank lines on top
    ?assertEqual([<<>>, <<>>, <<"    ab">>], lines(Out)).

ignores_ansi_width_test() ->
    %% Coloured "ab" has the visible width of 2, not the escape length.
    Colored = beamtea_term:bold(<<"ab">>),
    Out = beamtea_layout:place(Colored, {10, 1}, #{halign => center, valign => top}),
    [Line] = lines(Out),
    %% 4 leading spaces then the (styled) content
    ?assertMatch(<<"    ", _/binary>>, Line),
    ?assertEqual(2 + 4, beamtea_util:visible_width(Line)).

no_negative_padding_test() ->
    %% Content wider/taller than the area: no padding, no crash.
    Out = beamtea_layout:center(<<"abcdefgh">>, {4, 1}),
    ?assertEqual([<<"abcdefgh">>], lines(Out)).

%%% --- frame -----------------------------------------------------------

frame_fills_full_size_test() ->
    Out = beamtea_layout:frame(<<"hi">>, {20, 6}, #{padding => 0}),
    Rows = lines(Out),
    %% exactly Rows lines tall
    ?assertEqual(6, length(Rows)),
    %% every rendered row is exactly Cols visible columns wide
    [?assertEqual(20, beamtea_util:visible_width(R)) || R <- Rows],
    ok.

frame_has_borders_test() ->
    Out = iolist_to_binary(beamtea_layout:frame(<<"x">>, {12, 6}, #{})),
    ?assertNotEqual(nomatch, binary:match(Out, <<"┌"/utf8>>)),
    ?assertNotEqual(nomatch, binary:match(Out, <<"┐"/utf8>>)),
    ?assertNotEqual(nomatch, binary:match(Out, <<"└"/utf8>>)),
    ?assertNotEqual(nomatch, binary:match(Out, <<"┘"/utf8>>)),
    ?assertNotEqual(nomatch, binary:match(Out, <<"x">>)).

frame_places_content_inside_test() ->
    %% content sits on the first inner row with padding=0 (border glyphs are
    %% colour-wrapped, so compare with ANSI stripped)
    Rows = lines(beamtea_layout:frame(<<"ab">>, {8, 4}, #{padding => 0})),
    Row = beamtea_util:strip_ansi(lists:nth(2, Rows)),
    ?assertMatch(<<"│ab"/utf8, _/binary>>, Row).

frame_too_small_returns_content_test() ->
    ?assertEqual(<<"hi">>, iolist_to_binary(beamtea_layout:frame(<<"hi">>, {2, 2}, #{}))).
