%%% Key inspector — shows how raw input decodes into key events. Great for
%%% seeing arrows, UTF-8, and Ctrl-combos in action.
%%%
%%% Run:  ./bin/beamtea-run keys
-module(keys).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

-record(st, {last = none, count = 0, history = []}).

main() -> beamtea:start(?MODULE).

init(_Flags) -> {#st{}, beamtea:none()}.

update({key, {char, $q}}, St) -> {St, beamtea:quit()};
update({key, Key}, #st{count = C, history = H} = St) ->
    {St#st{last = Key, count = C + 1,
           history = lists:sublist([Key | H], 8)}, beamtea:none()};
update({resize, _}, St) -> {St, beamtea:none()};
update(_Msg, St) -> {St, beamtea:none()}.

view(#st{last = Last, count = C, history = H}) ->
    [
     "\n  ", beamtea_color:fg(cyan, beamtea_term:bold(<<"beamtea key inspector">>)), "\n\n",
     "  last key:  ", beamtea_color:fg(hotpink, beamtea_term:bold(describe(Last))), "\n",
     "  presses:   ", beamtea_term:faint(integer_to_binary(C)), "\n\n",
     "  recent:\n",
     [["    ", beamtea_color:fg(purple, describe(K)), "\n"] || K <- H],
     "\n  ", beamtea_term:faint(<<"press any key · q to quit"/utf8>>), "\n"
    ].

describe({char, Cp}) -> [<<"char ">>, <<Cp/utf8>>, io_lib:format(" (U+~4.16.0B)", [Cp])];
describe({ctrl, L})  -> [<<"ctrl-">>, <<L>>];
describe(none)       -> <<"—"/utf8>>;
describe(Atom)       -> atom_to_binary(Atom, utf8).
