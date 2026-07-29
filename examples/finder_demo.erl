%%% Finder demo — an fzf-style fuzzy finder in a floating modal, over an app
%%% with a bottom status bar. Everything is composed with beamtea_style and
%%% overlaid with beamtea_layout:overlay_center/3 (ANSI-aware, so the modal
%%% floats over the *styled* app + status bar).
%%%
%%%   /        open the fuzzy finder
%%%   type     filter (subsequence match, matched chars highlighted)
%%%   ↑/↓      move selection      enter  select      esc  close
%%%   q        quit
%%%
%%% Run:  ./bin/beamtea-run finder_demo
-module(finder_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

-record(finder, {input, cursor = 0}).
-record(st, {items, finder = closed, chosen = none}).

-define(MODAL_W, 56).
-define(MAX_RESULTS, 10).

main() -> beamtea:start(?MODULE).

init(_Flags) -> {#st{items = data()}, beamtea:none()}.

%%% --- update ----------------------------------------------------------

%% Finder closed: `/` opens it, `q` quits.
update({key, {char, $/}}, #st{finder = closed} = St) ->
    Input = beamtea_textinput:focus(
              beamtea_textinput:new(#{prompt => <<"">>, placeholder => <<"type to filter">>})),
    {St#st{finder = #finder{input = Input}}, beamtea:none()};
update({key, {char, $q}}, #st{finder = closed} = St) ->
    {St, beamtea:quit()};
update({key, _}, #st{finder = closed} = St) ->
    {St, beamtea:none()};

%% Finder open.
update({key, esc}, #st{finder = #finder{}} = St) ->
    {St#st{finder = closed}, beamtea:none()};
update({key, enter}, #st{finder = F, items = Items} = St) ->
    case filtered(F, Items) of
        [] -> {St#st{finder = closed}, beamtea:none()};
        Results ->
            {Item, _} = lists:nth(clamp_cursor(F, Results) + 1, Results),
            {St#st{finder = closed, chosen = Item}, beamtea:none()}
    end;
update({key, Key}, #st{finder = #finder{cursor = Cur} = F, items = Items} = St)
  when Key =:= up; Key =:= down ->
    N = length(filtered(F, Items)),
    Cur1 = case Key of
               up -> max(0, Cur - 1);
               down -> min(max(0, N - 1), Cur + 1)
           end,
    {St#st{finder = F#finder{cursor = Cur1}}, beamtea:none()};
update({key, Key}, #st{finder = #finder{input = In} = F} = St) ->
    {In1, _} = beamtea_textinput:update({key, Key}, In),
    %% typing changes the result set — reset the selection to the top
    {St#st{finder = F#finder{input = In1, cursor = 0}}, beamtea:none()};
update(_Msg, St) ->
    {St, beamtea:none()}.

%%% --- view ------------------------------------------------------------

view(#st{items = Items, finder = F, chosen = Chosen}) ->
    {W, H} = beamtea:window_size(),
    Bg = app(Items, Chosen, W, H),
    case F of
        closed -> Bg;
        #finder{} -> beamtea_layout:overlay_center(Bg, finder_modal(F, Items), {W, H})
    end.

%% The background app: a header, the item list, and a status bar on the last row.
app(Items, Chosen, W, H) ->
    Header = ["  ", beamtea_color:fg(charmple, beamtea_term:bold(<<"beamtea finder">>)),
              "   ", beamtea_term:faint(<<"press / to search"/utf8>>)],
    Rows = [["   ", item_row(I, Chosen)] || I <- lists:sublist(Items, H - 4)],
    Body = [Header, <<>> | Rows],
    Filled = Body ++ lists:duplicate(max(0, (H - 1) - length(Body)), <<>>),
    Bar = status_bar(Items, Chosen, W),
    lists:join(<<"\n">>, Filled ++ [Bar]).

item_row(Item, Item) -> beamtea_color:fg(green, [<<"• ">>, beamtea_term:bold(Item)]);
item_row(Item, _)    -> [<<"  ">>, Item].

status_bar(Items, Chosen, W) ->
    Badge = seg(<<" FINDER ">>, beamtea_color:c(pink), 232, true),
    Count = seg([<<" ">>, integer_to_binary(length(Items)), <<" items ">>], 238, 252),
    Sel = case Chosen of
              none -> <<" no selection ">>;
              _ -> [<<" ">>, Chosen, <<" ">>]
          end,
    Right = seg(Sel, beamtea_color:c(charmple), 231, true),
    Left = beamtea_style:join_horizontal(top, [Badge, Count]),
    Fill = filler(max(0, W - beamtea_util:visible_width(Left)
                          - beamtea_util:visible_width(Right))),
    beamtea_style:join_horizontal(top, [Left, Fill, Right]).

%%% --- the finder modal ------------------------------------------------

finder_modal(#finder{input = In} = F, Items) ->
    Results = filtered(F, Items),
    Cursor = clamp_cursor(F, Results),
    Prompt = [beamtea_color:fg(pink, <<"❯ "/utf8>>), beamtea_textinput:view(In)],
    Count = beamtea_term:faint([integer_to_binary(length(Results)), <<"/">>,
                                integer_to_binary(length(Items)), <<" matches">>]),
    Off = result_offset(Cursor, ?MAX_RESULTS),
    Shown = window(Results, Cursor, ?MAX_RESULTS),
    ResultLines = [result_row(R, Off + I - 1 =:= Cursor)
                   || {I, R} <- enumerate(Shown)],
    Body = beamtea_style:join_vertical(
             left, [Prompt, Count, <<>> | pad_results(ResultLines)]),
    beamtea_style:render(modal_style(), Body).

pad_results([]) -> [beamtea_term:faint(<<"  (no matches)">>)];
pad_results(Lines) -> Lines.

result_row({Item, Positions}, Selected) ->
    Marker = case Selected of
                 true -> beamtea_color:fg(pink, <<"❯ "/utf8>>);
                 false -> <<"  ">>
             end,
    Text = highlight(Item, Positions),
    Line = case Selected of
               true -> beamtea_term:bold(Text);
               false -> Text
           end,
    [Marker, Line].

modal_style() ->
    S0 = beamtea_style:border(beamtea_style:new(), rounded),
    S1 = beamtea_style:border_foreground(S0, pink),
    S2 = beamtea_style:padding(S1, {1, 2}),
    beamtea_style:width(S2, ?MODAL_W).

%%% --- fuzzy matching --------------------------------------------------

filtered(#finder{input = In}, Items) ->
    Query = beamtea_textinput:value(In),
    case string:trim(Query) of
        <<>> -> [{I, []} || I <- Items];
        _ ->
            QCps = [lower(C) || C <- to_cps(Query)],
            lists:filtermap(
              fun(I) ->
                      case fmatch(QCps, I) of
                          false -> false;
                          R -> {true, R}
                      end
              end, Items)
    end.

%% Subsequence match: every query code point appears in order in the item.
fmatch(QCps, Item) ->
    case walk(QCps, [lower(C) || C <- to_cps(Item)], 0, []) of
        {ok, Positions} -> {Item, Positions};
        no -> false
    end.

walk([], _Item, _Idx, Acc) -> {ok, lists:reverse(Acc)};
walk(_Q, [], _Idx, _Acc) -> no;
walk([Q | Qs], [Q | Cs], Idx, Acc) -> walk(Qs, Cs, Idx + 1, [Idx | Acc]);
walk(Qs, [_ | Cs], Idx, Acc) -> walk(Qs, Cs, Idx + 1, Acc).

%% Paint the matched positions pink; leave the rest plain.
highlight(Item, []) -> Item;
highlight(Item, Positions) ->
    Set = maps:from_keys(Positions, true),
    Cps = to_cps(Item),
    [case maps:is_key(I, Set) of
         true -> beamtea_color:fg(pink, <<Cp/utf8>>);
         false -> <<Cp/utf8>>
     end || {I, Cp} <- enumerate0(Cps)].

%%% --- helpers ---------------------------------------------------------

clamp_cursor(#finder{cursor = C}, Results) -> min(C, max(0, length(Results) - 1)).

result_offset(Cursor, Max) -> max(0, Cursor - Max + 1).

window(Results, Cursor, Max) ->
    Off = result_offset(Cursor, Max),
    lists:sublist(lists:nthtail(min(Off, length(Results)), Results), Max).

seg(Text, Bg, Fg) -> seg(Text, Bg, Fg, false).
seg(Text, Bg, Fg, Bold) ->
    S0 = beamtea_style:background(beamtea_style:foreground(beamtea_style:new(), Fg), Bg),
    S1 = case Bold of true -> beamtea_style:bold(S0); false -> S0 end,
    beamtea_style:render(S1, Text).

filler(Width) ->
    beamtea_style:render(
      beamtea_style:background(beamtea_style:width(beamtea_style:new(), Width), 236), <<>>).

lower(C) when C >= $A, C =< $Z -> C + 32;
lower(C) -> C.

to_cps(Bin) -> unicode:characters_to_list(iolist_to_binary(Bin)).

enumerate(List) -> lists:zip(lists:seq(1, length(List)), List).
enumerate0(List) -> lists:zip(lists:seq(0, length(List) - 1), List).

%% Fake data — a plausible project tree.
data() ->
    [<<"src/beamtea.erl">>, <<"src/beamtea_runtime.erl">>, <<"src/beamtea_key.erl">>,
     <<"src/beamtea_term.erl">>, <<"src/beamtea_render.erl">>, <<"src/beamtea_style.erl">>,
     <<"src/beamtea_layout.erl">>, <<"src/beamtea_color.erl">>, <<"src/beamtea_spinner.erl">>,
     <<"src/beamtea_progress.erl">>, <<"src/beamtea_table.erl">>, <<"src/beamtea_list.erl">>,
     <<"src/beamtea_textinput.erl">>, <<"src/beamtea_textarea.erl">>, <<"src/beamtea_viewport.erl">>,
     <<"src/beamtea_filepicker.erl">>, <<"src/beamtea_timer.erl">>, <<"src/beamtea_help.erl">>,
     <<"test/beamtea_key_tests.erl">>, <<"test/beamtea_style_tests.erl">>,
     <<"examples/counter.erl">>, <<"examples/modal_demo.erl">>, <<"examples/finder_demo.erl">>,
     <<"examples/statusbar_demo.erl">>, <<"examples/tabs_demo.erl">>,
     <<"README.md">>, <<"LICENSE">>, <<"rebar.config">>, <<"rebar.lock">>, <<"Makefile">>,
     <<"bin/beamtea-run">>, <<".github/workflows/ci.yml">>, <<"include/beamtea.hrl">>].
