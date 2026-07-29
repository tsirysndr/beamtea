-module(beamtea_term_tests).

-include_lib("eunit/include/eunit.hrl").

b(IoData) -> iolist_to_binary(IoData).

alt_screen_test() ->
    ?assertEqual(<<"\e[?1049h">>, beamtea_term:alt_enter()),
    ?assertEqual(<<"\e[?1049l">>, beamtea_term:alt_leave()).

cursor_test() ->
    ?assertEqual(<<"\e[?25l">>, beamtea_term:hide_cursor()),
    ?assertEqual(<<"\e[?25h">>, beamtea_term:show_cursor()).

clear_test() ->
    ?assertEqual(<<"\e[2J">>, beamtea_term:clear()),
    ?assertEqual(<<"\e[K">>, beamtea_term:clear_line()),
    ?assertEqual(<<"\e[J">>, beamtea_term:clear_below()).

home_test() ->
    ?assertEqual(<<"\e[H">>, beamtea_term:home()).

move_test() ->
    ?assertEqual(<<"\e[3;10H">>, b(beamtea_term:move(3, 10))).

reset_test() ->
    ?assertEqual(<<"\e[0m">>, beamtea_term:reset()).

sgr_test() ->
    ?assertEqual(<<"\e[1;38;5;205m">>, b(beamtea_term:sgr([1, 38, 5, 205]))).

fg_bg_test() ->
    ?assertEqual(<<"\e[38;5;42m">>, b(beamtea_term:fg(42))),
    ?assertEqual(<<"\e[48;5;7m">>, b(beamtea_term:bg(7))).

paint_wraps_and_resets_test() ->
    ?assertEqual(<<"\e[1mhi\e[0m">>, b(beamtea_term:bold("hi"))),
    ?assertEqual(<<"\e[7mx\e[0m">>, b(beamtea_term:reverse("x"))).
