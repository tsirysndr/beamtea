%%% @doc A bubble: key bindings (the `key' package in charmbracelet/bubbles).
%%%
%%% A binding groups the concrete keys that trigger an action with the help
%%% text describing it, so your `update/2' matches against intent rather than
%%% raw keys, and {@link beamtea_help} can render the controls automatically.
%%%
%%% ```
%%%   Up = beamtea_keybind:new([up, {char, $k}], {<<"↑/k">>, <<"up">>}),
%%%   case beamtea_keybind:matches(Key, Up) of true -> ...; false -> ... end
%%% '''
-module(beamtea_keybind).

-export([new/2, new/3, matches/2, matches_any/2,
         help/1, keys/1, enabled/1, set_enabled/2]).

-export_type([binding/0]).

-opaque binding() :: #{type := keybind,
                       keys := [beamtea_key:key()],
                       help := {iodata(), iodata()},
                       enabled := boolean()}.

%% @doc A binding over `Keys' with `{KeyLabel, Description}' help.
-spec new([beamtea_key:key()], {iodata(), iodata()}) -> binding().
new(Keys, Help) -> new(Keys, Help, true).

-spec new([beamtea_key:key()], {iodata(), iodata()}, boolean()) -> binding().
new(Keys, {_, _} = Help, Enabled) ->
    #{type => keybind, keys => Keys, help => Help, enabled => Enabled}.

%% @doc Does `Key' trigger this binding? (Always false when disabled.)
-spec matches(beamtea_key:key(), binding()) -> boolean().
matches(_Key, #{enabled := false}) -> false;
matches(Key, #{keys := Keys}) -> lists:member(Key, Keys).

%% @doc Does `Key' match any binding in the list?
-spec matches_any(beamtea_key:key(), [binding()]) -> boolean().
matches_any(Key, Bindings) ->
    lists:any(fun(B) -> matches(Key, B) end, Bindings).

%% @doc The `{KeyLabel, Description}' help pair.
-spec help(binding()) -> {iodata(), iodata()}.
help(#{help := Help}) -> Help.

-spec keys(binding()) -> [beamtea_key:key()].
keys(#{keys := Keys}) -> Keys.

-spec enabled(binding()) -> boolean().
enabled(#{enabled := E}) -> E.

-spec set_enabled(boolean(), binding()) -> binding().
set_enabled(E, B) -> B#{enabled := E}.
