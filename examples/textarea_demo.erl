%%% Text area demo — a multi-line editor with a live line/char count. Uses the
%%% beamtea_textarea bubble.
%%%
%%% Run:  rebar3 as examples shell
%%%       textarea_demo:main().
-module(textarea_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

main() -> beamtea:start(?MODULE).

init(_Flags) ->
    TA = beamtea_textarea:focus(
           beamtea_textarea:new(#{height => 8,
                                  placeholder => <<"start typing… (enter for a new line)"/utf8>>})),
    {TA, beamtea:none()}.

update({key, {ctrl, $c}}, TA) -> {TA, beamtea:quit()};
update({key, esc}, TA)        -> {TA, beamtea:quit()};
update(Msg, TA) ->
    {TA1, Cmd} = beamtea_textarea:update(Msg, TA),
    {TA1, Cmd}.

view(TA) ->
    {Row, Col} = beamtea_textarea:cursor(TA),
    Chars = byte_size(beamtea_textarea:value(TA)),
    [
     "  ", beamtea_color:fg(charmple, beamtea_term:bold(<<"beamtea text area">>)),
     beamtea_term:faint(io_lib:format("   ln ~B, col ~B · ~B bytes",
                                      [Row + 1, Col + 1, Chars])), "\n\n",
     box(beamtea_textarea:view(TA)), "\n",
     "  ", beamtea_term:faint(<<"esc/ctrl-c quit">>)
    ].

-define(BOX_INNER, 52).   %% visible columns between the vertical borders

%% A bordered box around the editor. Each content line is padded to the box
%% width (ignoring ANSI colour codes) so the right border always lines up.
box(IoData) ->
    Lines = beamtea_render:lines(IoData),
    Top = ["  ", beamtea_term:faint(["┌", dash(?BOX_INNER), "┐"])],
    Body = [box_line(L) || L <- Lines],
    Bottom = ["  ", beamtea_term:faint(["└", dash(?BOX_INNER), "┘"])],
    lists:join(<<"\n">>, [Top | Body] ++ [Bottom]).

box_line(L) ->
    Padded = beamtea_util:pad_visible([<<" ">>, L], ?BOX_INNER),
    ["  ", beamtea_term:faint(<<"│"/utf8>>), Padded, beamtea_term:faint(<<"│"/utf8>>)].

dash(N) -> lists:duplicate(N, "─").
