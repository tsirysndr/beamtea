%%% Counter — the "hello world" of beamtea. No bubbles, just the core loop.
%%%
%%% Run:  ./bin/beamtea-run counter
-module(counter).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

main() -> beamtea:start(?MODULE).

init(_Flags) -> {0, beamtea:none()}.

update({key, up},         N) -> {N + 1, beamtea:none()};
update({key, {char, $k}}, N) -> {N + 1, beamtea:none()};
update({key, {char, $+}}, N) -> {N + 1, beamtea:none()};
update({key, down},         N) -> {N - 1, beamtea:none()};
update({key, {char, $j}},   N) -> {N - 1, beamtea:none()};
update({key, {char, $-}},   N) -> {N - 1, beamtea:none()};
update({key, {char, $r}},  _N) -> {0, beamtea:none()};
update({key, {char, $q}},   N) -> {N, beamtea:quit()};
update(_Msg, N) -> {N, beamtea:none()}.

view(N) ->
    Color = if N > 0 -> green; N < 0 -> red; true -> gray end,
    [
     "\n",
     "  ", beamtea_color:fg(charmple, beamtea_term:bold(<<"beamtea counter">>)), "\n\n",
     "  ", beamtea_color:fg(Color, beamtea_term:bold(io_lib:format("~p", [N]))), "\n\n",
     "  ", beamtea_term:faint(<<"↑/k/+ up  ·  ↓/j/- down  ·  r reset  ·  q quit"/utf8>>), "\n"
    ].
