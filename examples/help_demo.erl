%%% Help & paginator demo — declares key bindings once and renders both the
%%% controls (via beamtea_help) and a paged list (via beamtea_paginator).
%%%
%%% Run:  ./bin/beamtea-run help_demo
-module(help_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

-record(st, {items, pager, keys, show_all = false}).

%% All bindings declared once, then reused for matching and for help.
keymap() ->
    #{prev => beamtea_keybind:new([left, {char, $h}], {<<"←/h"/utf8>>, <<"prev page">>}),
      next => beamtea_keybind:new([right, {char, $l}], {<<"→/l"/utf8>>, <<"next page">>}),
      help => beamtea_keybind:new([{char, $?}], {<<"?">>, <<"toggle help">>}),
      quit => beamtea_keybind:new([{char, $q}, {ctrl, $c}], {<<"q">>, <<"quit">>})}.

main() -> beamtea:start(?MODULE).

init(_Flags) ->
    Items = [io_lib:format("Item ~2..0B", [N]) || N <- lists:seq(1, 23)],
    Pager = beamtea_paginator:new(#{total_items => length(Items), per_page => 6}),
    {#st{items = Items, pager = Pager, keys = keymap()}, beamtea:none()}.

update({key, Key}, #st{keys = K, pager = P, show_all = Show} = St) ->
    #{prev := Prev, next := Next, help := Help, quit := Quit} = K,
    Matches = fun(B) -> beamtea_keybind:matches(Key, B) end,
    case Matches(Quit) of
        true ->
            {St, beamtea:quit()};
        false ->
            case Matches(Help) of
                true ->
                    {St#st{show_all = not Show}, beamtea:none()};
                false ->
                    case Matches(Prev) orelse Matches(Next) of
                        true ->
                            {P1, _} = beamtea_paginator:update({key, Key}, P),
                            {St#st{pager = P1}, beamtea:none()};
                        false ->
                            {St, beamtea:none()}
                    end
            end
    end;
update(_Msg, St) ->
    {St, beamtea:none()}.

view(#st{items = Items, pager = P, keys = K, show_all = Show}) ->
    {Start, End} = beamtea_paginator:slice_bounds(P, length(Items)),
    Page = lists:sublist(Items, Start + 1, End - Start),
    Rows = [["    ", beamtea_color:fg(cyan, Item)] || Item <- Page],
    Help = help_view(K, Show),
    [
     "\n  ", beamtea_color:fg(charmple, beamtea_term:bold(<<"beamtea help + paginator">>)), "\n\n",
     lists:join(<<"\n">>, Rows), "\n\n",
     "  ", beamtea_paginator:view(P), "\n\n",
     "  ", Help, "\n"
    ].

help_view(K, false) ->
    #{prev := Prev, next := Next, help := Help, quit := Quit} = K,
    beamtea_help:short(beamtea_help:new(), [Prev, Next, Help, Quit]);
help_view(K, true) ->
    #{prev := Prev, next := Next, help := Help, quit := Quit} = K,
    beamtea_help:full(beamtea_help:new(), [[Prev, Next], [Help, Quit]]).
