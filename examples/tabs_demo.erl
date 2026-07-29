%%% Tabs demo — a tabbed interface styled with beamtea_style. The tab bar is a
%%% row of pill buttons (join_horizontal); the active tab's content sits in a
%%% bordered panel below (join_vertical). ←/→ or h/l switch tabs · q quits.
%%%
%%% Run:  ./bin/beamtea-run tabs_demo
-module(tabs_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

-record(st, {active = 1}).

-define(PANEL_W, 54).

main() -> beamtea:start(?MODULE).

init(_Flags) -> {#st{}, beamtea:none()}.

tabs() ->
    [{<<"Home">>,     home()},
     {<<"Bubbles">>,  bubbles()},
     {<<"Styling">>,  styling()},
     {<<"About">>,    about()}].

%%% --- update ----------------------------------------------------------

update({key, Key}, #st{active = A} = St) ->
    N = length(tabs()),
    case Key of
        _ when Key =:= right; Key =:= {char, $l}; Key =:= tab ->
            {St#st{active = (A rem N) + 1}, beamtea:none()};
        _ when Key =:= left; Key =:= {char, $h} ->
            {St#st{active = ((A - 2 + N) rem N) + 1}, beamtea:none()};
        {char, $q} -> {St, beamtea:quit()};
        _ -> {St, beamtea:none()}
    end;
update(_Msg, St) ->
    {St, beamtea:none()}.

%%% --- view ------------------------------------------------------------

view(#st{active = A}) ->
    Tabs = tabs(),
    Bar = tab_bar(Tabs, A),
    {_Label, Content} = lists:nth(A, Tabs),
    Panel = beamtea_style:render(panel_style(), Content),
    Title = beamtea_style:render(
              beamtea_style:bold(beamtea_style:foreground(beamtea_style:new(), charmple)),
              <<"beamtea tabs">>),
    Help = beamtea_style:render(beamtea_style:faint(beamtea_style:new()),
                                <<"←/→ switch tab · q quit"/utf8>>),
    Body = beamtea_style:join_vertical(left, [Title, <<>>, Bar, <<>>, Panel, <<>>, Help]),
    ["\n  ", indent(Body)].

tab_bar(Tabs, Active) ->
    Pills = [tab(Label, I =:= Active) || {I, {Label, _}} <- enumerate(Tabs)],
    Spaced = lists:join(<<" ">>, Pills),
    beamtea_style:join_horizontal(top, Spaced).

tab(Label, Active) ->
    Base = beamtea_style:padding(beamtea_style:new(), {0, 2}),
    S = case Active of
            true ->
                beamtea_style:bold(
                  beamtea_style:background(
                    beamtea_style:foreground(Base, {16#1a, 16#1a, 16#1a}), pink));
            false ->
                beamtea_style:foreground(
                  beamtea_style:background(Base, 236), 245)
        end,
    beamtea_style:render(S, Label).

panel_style() ->
    S0 = beamtea_style:border(beamtea_style:new(), rounded),
    S1 = beamtea_style:border_foreground(S0, pink),
    S2 = beamtea_style:padding(S1, {1, 2}),
    beamtea_style:width(S2, ?PANEL_W).

%%% --- tab content -----------------------------------------------------

home() ->
    [beamtea_color:fg(charmple, beamtea_term:bold(<<"Welcome to beamtea 🍵"/utf8>>)), "\n\n",
     "A delightful terminal UI framework for the BEAM —\n",
     "Bubble Tea for Erlang, with a lipgloss-style layer.\n\n",
     beamtea_term:faint(<<"Use the arrow keys to explore the tabs.">>)].

bubbles() ->
    [beamtea_term:bold(<<"Reusable components (bubbles):">>), "\n\n",
     "  • spinner, progress, textinput, textarea\n",
     "  • list, table, viewport, paginator\n",
     "  • timer, stopwatch, filepicker, cursor\n",
     "  • keybind + help"].

styling() ->
    [beamtea_term:bold(<<"beamtea_style">>), " — composable styling\n\n",
     "  ", beamtea_color:fg(pink, <<"foreground">>), " / ",
     beamtea_color:fg(cyan, <<"colours">>), "\n",
     "  ", beamtea_term:bold(<<"bold">>), "  ",
     beamtea_term:underline(<<"underline">>), "  ",
     beamtea_term:faint(<<"faint">>), "\n",
     "  borders · padding · margin · align\n",
     "  join_horizontal / join_vertical"].

about() ->
    ["Built on OTP's ", beamtea_term:bold(<<"prim_tty">>), ".\n\n",
     "The Elm Architecture: ", beamtea_color:fg(green, <<"init">>), " · ",
     beamtea_color:fg(green, <<"update">>), " · ",
     beamtea_color:fg(green, <<"view">>), ".\n\n",
     beamtea_term:faint(<<"MIT licensed.">>)].

%%% --- helpers ---------------------------------------------------------

enumerate(List) -> lists:zip(lists:seq(1, length(List)), List).

indent(IoData) ->
    lists:join(<<"\n  ">>, beamtea_render:lines(IoData)).
