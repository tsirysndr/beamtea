%%% A module-form program, used to test `beamtea:normalize/1' with a module.
-module(beamtea_program_tests_mod).

-behaviour(beamtea).

-export([init/1, update/2, view/1]).

init(_Flags) -> {0, beamtea:none()}.

update({key, {char, $q}}, N) -> {N, beamtea:quit()};
update(_Msg, N) -> {N, beamtea:none()}.

view(N) -> integer_to_binary(N).
