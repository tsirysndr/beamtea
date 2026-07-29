-module(beamtea_render_tests).

-include_lib("eunit/include/eunit.hrl").

frame(View) -> iolist_to_binary(beamtea_render:to_frame(View)).

starts_at_home_test() ->
    Bin = frame(<<"hello">>),
    ?assertMatch(<<"\e[H", _/binary>>, Bin).

single_line_clears_eol_and_below_test() ->
    ?assertEqual(<<"\e[Hhello\e[K\e[0m\e[J">>, frame(<<"hello">>)).

multi_line_uses_crlf_test() ->
    %% Each line ends with erase-to-eol; joined with CRLF for raw mode.
    ?assertEqual(<<"\e[Ha\e[K\r\nb\e[K\e[0m\e[J">>, frame(<<"a\nb">>)).

trailing_cr_is_stripped_test() ->
    %% A view authored with \r\n must not double up the CR.
    ?assertEqual(<<"\e[Ha\e[K\r\nb\e[K\e[0m\e[J">>, frame(<<"a\r\nb">>)).

empty_view_test() ->
    ?assertEqual(<<"\e[H\e[K\e[0m\e[J">>, frame(<<>>)).

accepts_iodata_test() ->
    ?assertEqual(frame(<<"ab">>), frame(["a", <<"b">>])).

lines_splits_on_newline_test() ->
    ?assertEqual([<<"a">>, <<"b">>, <<"c">>],
                 beamtea_render:lines(<<"a\nb\nc">>)).
