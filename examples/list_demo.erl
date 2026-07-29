%%% List demo — a scrollable, selectable menu. Uses the beamtea_list bubble.
%%%
%%% Run:  rebar3 as examples shell
%%%       list_demo:main().
-module(list_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

-record(st, {list, chosen = none}).

main() -> beamtea:start(?MODULE).

init(_Flags) ->
    Items = [<<"🍵  Green tea"/utf8>>, <<"☕  Espresso"/utf8>>, <<"🧋  Bubble tea"/utf8>>,
             <<"🥤  Cola"/utf8>>, <<"💧  Water"/utf8>>, <<"🍺  Beer"/utf8>>, <<"🍷  Wine"/utf8>>,
             <<"🧃  Juice"/utf8>>, <<"🥛  Milk"/utf8>>, <<"🍸  Martini"/utf8>>],
    L = beamtea_list:new(Items, #{title => <<"What are you drinking?">>,
                                  height => 6}),
    {#st{list = L}, beamtea:none()}.

update({key, {char, $q}}, St) -> {St, beamtea:quit()};
update({key, enter}, #st{list = L} = St) ->
    {_Idx, Item} = beamtea_list:selected(L),
    {St#st{chosen = Item}, beamtea:none()};
update(Msg, #st{list = L} = St) ->
    {L1, Cmd} = beamtea_list:update(Msg, L),
    {St#st{list = L1}, Cmd}.

view(#st{list = L, chosen = Chosen}) ->
    Footer =
        case Chosen of
            none -> beamtea_term:faint(<<"↑/↓ move · enter choose · q quit"/utf8>>);
            Item -> [beamtea_color:fg(green, <<"you chose: ">>),
                     beamtea_term:bold(Item)]
        end,
    [
     "\n  ", beamtea_list:view(L), "\n\n",
     "  ", Footer, "\n"
    ].
