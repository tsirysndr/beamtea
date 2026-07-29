%%% @doc Pure interpretation of {@link beamtea:cmd()} values into a flat list
%%% of side-effects.
%%%
%%% Keeping this translation pure (no message sends, no timers, no spawns)
%%% means the whole command language can be unit-tested without a terminal or
%%% a running runtime. {@link beamtea_runtime} executes the resulting effects.
-module(beamtea_cmd).

-export([to_effects/1]).

-export_type([effect/0]).

-type effect() ::
        quit
      | {msg, term()}                              %% deliver a message now
      | {after_ms, non_neg_integer(), term()}      %% deliver once after a delay
      | {every, pos_integer(), term()}             %% deliver repeatedly
      | {task, fun(() -> term())}.                 %% run async, deliver result

%% @doc Flatten a command into zero or more effects. Unknown commands raise
%% `{bad_command, Cmd}' so mistakes surface loudly during development.
-spec to_effects(beamtea:cmd()) -> [effect()].
to_effects(none)      -> [];
to_effects(ok)        -> [];
to_effects(undefined) -> [];
to_effects(quit)      -> [quit];
to_effects({batch, Cmds}) when is_list(Cmds) ->
    lists:flatmap(fun to_effects/1, Cmds);
to_effects({seq, Cmds}) when is_list(Cmds) ->
    lists:flatmap(fun to_effects/1, Cmds);
to_effects({msg, Msg}) ->
    [{msg, Msg}];
to_effects({tick, Ms, Msg}) when is_integer(Ms), Ms >= 0 ->
    [{after_ms, Ms, Msg}];
to_effects({every, Ms, Msg}) when is_integer(Ms), Ms > 0 ->
    [{every, Ms, Msg}];
to_effects({task, Fun}) when is_function(Fun, 0) ->
    [{task, Fun}];
to_effects(Fun) when is_function(Fun, 0) ->
    [{task, Fun}];
to_effects(Cmds) when is_list(Cmds) ->
    lists:flatmap(fun to_effects/1, Cmds);
to_effects(Cmd) ->
    erlang:error({bad_command, Cmd}).
