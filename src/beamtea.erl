%%% @doc beamtea — a delightful terminal UI framework for the BEAM, built on
%%% `prim_tty' and inspired by Bubble Tea and The Elm Architecture.
%%%
%%% A program is three pure functions:
%%% <ul>
%%%   <li>`init(Flags) -> {Model, Cmd}' — the starting model and an initial
%%%       command</li>
%%%   <li>`update(Msg, Model) -> {Model, Cmd}' — fold a message into the
%%%       model</li>
%%%   <li>`view(Model) -> iodata()' — render the model to the full screen</li>
%%% </ul>
%%%
%%% Supply them either as a module implementing the {@link beamtea} behaviour
%%% or as a map `#{init => F, update => F, view => F}', then call
%%% {@link start/1}.
%%%
%%% Messages your `update/2' will receive from the runtime:
%%% <ul>
%%%   <li>`{key, Key}' — a keypress (see {@link beamtea_key})</li>
%%%   <li>`{resize, {Cols, Rows}}' — the terminal was resized</li>
%%% </ul>
%%% plus any message produced by the commands you return.
-module(beamtea).

-include("beamtea.hrl").

%% Program entry points
-export([start/1, start/2, start/3]).

%% Command constructors
-export([none/0, quit/0, batch/1, sequence/1, msg/1,
         tick/2, every/2, task/1]).

%% Terminal info
-export([window_size/0]).

%% Internal (used by the runtime)
-export([normalize/1]).

-export_type([program/0, model/0, msg/0, cmd/0]).

%%% ===================================================================
%%% Behaviour
%%% ===================================================================

-callback init(Flags :: term()) -> {model(), cmd()}.
-callback update(msg(), model()) -> {model(), cmd()}.
-callback view(model()) -> iodata().

%%% ===================================================================
%%% Types
%%% ===================================================================

-type model() :: term().
-type msg()   :: {key, beamtea_key:key()}
               | {resize, {pos_integer(), pos_integer()}}
               | term().

%% A command describes a side-effect for the runtime to run after an update.
-type cmd() ::
        none | ok
      | quit
      | {msg, msg()}
      | {tick, non_neg_integer(), msg()}
      | {every, pos_integer(), msg()}
      | {task, fun(() -> msg())}
      | fun(() -> msg())
      | {batch, [cmd()]}
      | {seq, [cmd()]}
      | [cmd()].

-type program() :: module()
                 | #{init := fun((term()) -> {model(), cmd()}),
                     update := fun((msg(), model()) -> {model(), cmd()}),
                     view := fun((model()) -> iodata())}.

%%% ===================================================================
%%% Entry points
%%% ===================================================================

%% @equiv start(Program, undefined, #{})
-spec start(program()) -> {ok, model()} | {error, term()}.
start(Program) -> start(Program, undefined, #{}).

%% @equiv start(Program, Flags, #{})
-spec start(program(), term()) -> {ok, model()} | {error, term()}.
start(Program, Flags) -> start(Program, Flags, #{}).

%% @doc Start a program and block until it quits.
%%
%% Returns `{ok, FinalModel}' on a clean exit, or `{error, Reason}' if the
%% program could not start (e.g. `not_a_terminal' when stdout is not a tty) or
%% crashed.
%%
%% Run beamtea programs so they own the terminal — use `bin/beamtea-run' or
%% start the VM with `stty -isig' and `erl +Bi -noshell -noinput'. Launching
%% from an interactive `rebar3 shell' will conflict with the shell's own tty
%% handling and route Ctrl-C to the BEAM break handler. See the README.
%%
%% `Opts' understands:
%% <ul>
%%   <li>`alt_screen => boolean()' (default `true') — use the alternate
%%       screen buffer</li>
%%   <li>`catch_ctrl_c => boolean()' (default `true') — quit on Ctrl-C
%%       instead of passing it to `update/2'</li>
%%   <li>`layout => top_left | center | {place, Opts}' (default `top_left')
%%       — position the whole view within the terminal, so a small view can
%%       fill/centre the screen. See {@link beamtea_layout}. `center' and
%%       `{place, ...}' re-flow automatically on resize.</li>
%% </ul>
-spec start(program(), term(), map()) -> {ok, model()} | {error, term()}.
start(Program, Flags, Opts) ->
    case whereis(beamtea_runtime) of
        Pid when is_pid(Pid) ->
            {error, already_running};
        undefined ->
            Prog = normalize(Program),
            {Child, Mon} =
                spawn_monitor(
                  fun() ->
                          true = register(beamtea_runtime, self()),
                          Result = beamtea_runtime:run(Prog, Flags, Opts),
                          exit({beamtea_result, Result})
                  end),
            receive
                {'DOWN', Mon, process, Child, Reason} ->
                    interpret_exit(Reason)
            end
    end.

interpret_exit({beamtea_result, Model}) -> {ok, Model};
interpret_exit(normal)                  -> {ok, undefined};
interpret_exit(enotsup)                 -> {error, not_a_terminal};
interpret_exit({enotsup, _})            -> {error, not_a_terminal};
interpret_exit(Reason)                  -> {error, Reason}.

%%% ===================================================================
%%% Command constructors
%%% ===================================================================

%% @doc A command that does nothing.
-spec none() -> cmd().
none() -> none.

%% @doc Ask the runtime to quit after this update.
-spec quit() -> cmd().
quit() -> quit.

%% @doc Run several commands.
-spec batch([cmd()]) -> cmd().
batch(Cmds) -> {batch, Cmds}.

%% @doc Run several commands (ordering is not otherwise significant in 0.1.0).
-spec sequence([cmd()]) -> cmd().
sequence(Cmds) -> {seq, Cmds}.

%% @doc Deliver `Msg' back to `update/2' as soon as possible.
-spec msg(msg()) -> cmd().
msg(Msg) -> {msg, Msg}.

%% @doc Deliver `Msg' once, after `Ms' milliseconds.
-spec tick(non_neg_integer(), msg()) -> cmd().
tick(Ms, Msg) -> {tick, Ms, Msg}.

%% @doc Deliver `Msg' repeatedly, every `Ms' milliseconds, until the program
%% quits. (0.1.0 timers cannot be individually cancelled.)
-spec every(pos_integer(), msg()) -> cmd().
every(Ms, Msg) -> {every, Ms, Msg}.

%% @doc Run `Fun' asynchronously; its return value is delivered to `update/2'.
-spec task(fun(() -> msg())) -> cmd().
task(Fun) -> {task, Fun}.

%% @doc The current terminal size `{Cols, Rows}'. Callable from `init/1' and
%% `view/1' (they run in the runtime process), so a view can size its content
%% to the terminal without threading the size through the model. The size also
%% arrives in `update/2' as `{resize, {Cols, Rows}}' if you prefer to store it.
%% Returns `{80, 24}' if called outside a running program.
-spec window_size() -> {pos_integer(), pos_integer()}.
window_size() ->
    case get(beamtea_size) of
        {Cols, Rows} when is_integer(Cols), is_integer(Rows) -> {Cols, Rows};
        _ -> {80, 24}
    end.

%%% ===================================================================
%%% Internal
%%% ===================================================================

%% @doc Normalize a program (module or map) into the internal record form.
-spec normalize(program()) -> #beamtea_prog{}.
normalize(#{init := I, update := U, view := V})
  when is_function(I, 1), is_function(U, 2), is_function(V, 1) ->
    #beamtea_prog{init = I, update = U, view = V};
normalize(Mod) when is_atom(Mod) ->
    #beamtea_prog{init = fun Mod:init/1,
                  update = fun Mod:update/2,
                  view = fun Mod:view/1}.
