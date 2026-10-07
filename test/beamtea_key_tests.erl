-module(beamtea_key_tests).

-include_lib("eunit/include/eunit.hrl").

keys(Bin) ->
    {Keys, <<>>} = beamtea_key:parse(Bin),
    Keys.

%%% --- Single ASCII keys ------------------------------------------------

ascii_char_test() ->
    ?assertEqual([{char, $a}], keys(<<"a">>)).

space_is_a_char_test() ->
    ?assertEqual([{char, 32}], keys(<<" ">>)).

enter_cr_test() ->
    ?assertEqual([enter], keys(<<"\r">>)).

enter_lf_test() ->
    ?assertEqual([enter], keys(<<"\n">>)).

tab_test() ->
    ?assertEqual([tab], keys(<<"\t">>)).

backspace_del_test() ->
    ?assertEqual([backspace], keys(<<127>>)).

backspace_bs_test() ->
    ?assertEqual([backspace], keys(<<8>>)).

lone_esc_test() ->
    ?assertEqual([esc], keys(<<27>>)).

%%% --- Ctrl combinations ------------------------------------------------

ctrl_c_test() ->
    ?assertEqual([{ctrl, $c}], keys(<<3>>)).

ctrl_a_test() ->
    ?assertEqual([{ctrl, $a}], keys(<<1>>)).

ctrl_z_test() ->
    ?assertEqual([{ctrl, $z}], keys(<<26>>)).

%% C0 bytes 28..31 are the traditional Ctrl-\, Ctrl-], Ctrl-^, Ctrl-_ positions.
%% Ctrl-_ shares the physical key with Ctrl-- on US layouts, so we name it $-
%% to match what fixterms CSI-u terminals report for Ctrl--.
c0_symbols_test() ->
    ?assertEqual([{ctrl, $\\}], keys(<<28>>)),
    ?assertEqual([{ctrl, $]}], keys(<<29>>)),
    ?assertEqual([{ctrl, $^}], keys(<<30>>)),
    ?assertEqual([{ctrl, $-}], keys(<<31>>)).

%%% --- Fixterms CSI-u (ESC [ <codepoint> ; <mods> u) ---------------------

csi_u_ctrl_printable_test() ->
    %% Modifier value 5 = 1 + ctrl. Ghostty sends these in legacy mode.
    ?assertEqual([{ctrl, $[}], keys(<<"\e[91;5u">>)),
    ?assertEqual([{ctrl, $]}], keys(<<"\e[93;5u">>)),
    ?assertEqual([{ctrl, $-}], keys(<<"\e[45;5u">>)),
    ?assertEqual([{ctrl, $=}], keys(<<"\e[61;5u">>)),
    ?assertEqual([{ctrl, $;}], keys(<<"\e[59;5u">>)),
    ?assertEqual([{ctrl, $c}], keys(<<"\e[99;5u">>)).

csi_u_plain_char_test() ->
    ?assertEqual([{char, $a}], keys(<<"\e[97u">>)),
    ?assertEqual([{char, $a}], keys(<<"\e[97;1u">>)).

csi_u_esc_test() ->
    ?assertEqual([esc], keys(<<"\e[27u">>)),
    ?assertEqual([esc], keys(<<"\e[27;1u">>)).

csi_u_other_modifiers_skipped_test() ->
    %% Shift (2), alt (3), ctrl+shift (7), ctrl+alt (6): skip, do not misread.
    ?assertEqual([], keys(<<"\e[91;2u">>)),
    ?assertEqual([], keys(<<"\e[91;3u">>)),
    ?assertEqual([], keys(<<"\e[91;7u">>)),
    ?assertEqual([], keys(<<"\e[97;6u">>)),
    %% Kitty event-type parameter (cp;mods;event): skip too.
    ?assertEqual([], keys(<<"\e[97;1;2u">>)).

csi_u_non_printable_skipped_test() ->
    ?assertEqual([], keys(<<"\e[9;5u">>)),
    ?assertEqual([], keys(<<"\e[13;5u">>)),
    ?assertEqual([], keys(<<"\e[27;5u">>)),
    ?assertEqual([], keys(<<"\e[57441u">>)).

incomplete_csi_u_leftover_test() ->
    ?assertEqual({[], <<"\e[91;5">>}, beamtea_key:parse(<<"\e[91;5">>)),
    {[{ctrl, $[}], <<>>} = beamtea_key:parse(<<"\e[91;5", "u">>).

%%% --- Arrow keys (CSI + SS3) ------------------------------------------

csi_arrows_test() ->
    ?assertEqual([up, down, right, left],
                 keys(<<"\e[A\e[B\e[C\e[D">>)).

ss3_arrows_test() ->
    ?assertEqual([up, down, right, left],
                 keys(<<"\eOA\eOB\eOC\eOD">>)).

%%% --- Navigation keys --------------------------------------------------

home_end_csi_test() ->
    ?assertEqual([home, 'end'], keys(<<"\e[H\e[F">>)).

nav_tilde_test() ->
    ?assertEqual([home, insert, delete, 'end', page_up, page_down],
                 keys(<<"\e[1~\e[2~\e[3~\e[4~\e[5~\e[6~">>)).

back_tab_test() ->
    ?assertEqual([back_tab], keys(<<"\e[Z">>)).

%%% --- UTF-8 text -------------------------------------------------------

utf8_accented_test() ->
    %% "é" is 2 bytes; expect a single code point.
    ?assertEqual([{char, 16#E9}], keys(<<"é"/utf8>>)).

utf8_emoji_test() ->
    %% 😀 U+1F600 is a 4-byte sequence.
    ?assertEqual([{char, 16#1F600}], keys(<<"😀"/utf8>>)).

utf8_mixed_word_test() ->
    ?assertEqual([{char, $c}, {char, $a}, {char, $f}, {char, $é}],
                 keys(<<"caf", 16#C3, 16#A9>>)).

to_binary_roundtrip_test() ->
    ?assertEqual(<<"😀"/utf8>>, beamtea_key:to_binary({char, 16#1F600})),
    ?assertEqual(<<"a">>, beamtea_key:to_binary($a)).

%%% --- Multiple keys & mixed streams -----------------------------------

mixed_stream_test() ->
    ?assertEqual([{char, $h}, {char, $i}, enter, up, {ctrl, $c}],
                 keys(<<"hi\r\e[A", 3>>)).

%%% --- Incomplete sequences carried over -------------------------------

incomplete_csi_leftover_test() ->
    %% An escape split across a read boundary must be returned as leftover.
    ?assertEqual({[], <<"\e[">>}, beamtea_key:parse(<<"\e[">>)),
    ?assertEqual({[{char, $x}], <<"\e[">>}, beamtea_key:parse(<<"x\e[">>)).

incomplete_then_complete_test() ->
    {Keys1, Rest1} = beamtea_key:parse(<<"\e">>),
    %% lone ESC at end is treated as the Escape key (buffer fully consumed)
    ?assertEqual({[esc], <<>>}, {Keys1, Rest1}),
    %% but a real split sequence: feed "\e[" then "A"
    {[], Rest2} = beamtea_key:parse(<<"\e[">>),
    {Keys3, <<>>} = beamtea_key:parse(<<Rest2/binary, "A">>),
    ?assertEqual([up], Keys3).

incomplete_utf8_leftover_test() ->
    %% First byte of a 2-byte code point, split.
    {Keys, Rest} = beamtea_key:parse(<<16#C3>>),
    ?assertEqual([], Keys),
    ?assertEqual(<<16#C3>>, Rest),
    %% Completing it yields the character.
    {Keys2, <<>>} = beamtea_key:parse(<<Rest/binary, 16#A9>>),
    ?assertEqual([{char, 16#E9}], Keys2).

invalid_byte_dropped_test() ->
    %% A stray continuation byte with no lead is dropped, not fatal.
    ?assertEqual([{char, $a}], keys(<<16#80, "a">>)).
