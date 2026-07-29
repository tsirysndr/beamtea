%%% @doc The event loop that owns the terminal and drives an Elm program.
%%%
%%% This process is the one that initialises `prim_tty', so it must be
%%% registered (prim_tty derives its reader/writer process names from the
%%% owner's registered name). {@link beamtea:start/3} takes care of that.
%%%
%%% Lifecycle:
%%% <ol>
%%%   <li>put the tty in raw mode, enter the alternate screen, hide cursor</li>
%%%   <li>run `init/1', render the first frame, arm the reader</li>
%%%   <li>loop: decode input into keys, feed messages to `update/2', run the
%%%       returned commands, repaint</li>
%%%   <li>on quit/eof/crash: show cursor, leave the alternate screen and
%%%       restore cooked mode — always, via `after'</li>
%%% </ol>
-module(beamtea_runtime).

-include("beamtea.hrl").

-export([run/3]).

-record(st, {
    tty          :: term(),            %% opaque prim_tty state
    prog         :: #beamtea_prog{},
    model        :: term(),
    opts         :: map(),
    size         :: {pos_integer(), pos_integer()},  %% {Cols, Rows}
    alt          :: boolean(),
    catch_ctrl_c :: boolean(),
    layout       :: top_left | center | fill | {frame, map()} | {place, map()},
    buf = <<>>   :: binary()           %% leftover, un-parsed input bytes
}).

%% @doc Run `Prog' to completion in the current (registered) process and return
%% the final model. Called by {@link beamtea:start/3}.
-spec run(#beamtea_prog{}, term(), map()) -> term().
run(#beamtea_prog{} = Prog, Flags, Opts) ->
    %% Trap exits so a dying reader/writer surfaces as a message we can react
    %% to rather than taking us down before the terminal is restored.
    process_flag(trap_exit, true),
    TTY0 = prim_tty:init(#{input => raw, output => raw}),
    Alt = maps:get(alt_screen, Opts, true),
    CatchC = maps:get(catch_ctrl_c, Opts, true),
    enter_screen(TTY0, Alt),
    try
        Size = window_size(TTY0),
        put(beamtea_size, Size),   %% make it readable from init/view via beamtea:window_size/0
        {InitModel, Cmd} = (Prog#beamtea_prog.init)(Flags),
        St0 = #st{tty = TTY0, prog = Prog, model = InitModel, opts = Opts,
                  size = Size, alt = Alt, catch_ctrl_c = CatchC,
                  layout = maps:get(layout, Opts, top_left)},
        St1 = perform(beamtea_cmd:to_effects(Cmd), St0),
        %% Hand the program its initial size up-front (as a resize) so it can
        %% lay out to the full terminal on the very first frame.
        St2 = deliver({resize, Size}, St1),
        render(St2),
        ok = prim_tty:read(TTY0),
        loop(St2)
    after
        leave_screen(TTY0, Alt)
    end.

%%% ===================================================================
%%% Main loop
%%% ===================================================================

loop(#st{tty = TTY} = St) ->
    receive
        %% --- Keyboard input --------------------------------------------
        {_Ref, {data, Bytes}} ->
            {Keys, Rest} = beamtea_key:parse(<<(St#st.buf)/binary, Bytes/binary>>),
            St1 = lists:foldl(fun handle_key/2, St#st{buf = Rest}, Keys),
            render(St1),
            ok = prim_tty:read(TTY),      %% re-arm (idempotent)
            loop(St1);

        %% --- Terminal resized ------------------------------------------
        {_Ref, {signal, sigwinch}} ->
            TTY1 = prim_tty:handle_signal(TTY, sigwinch),
            Size = window_size(TTY1),
            St1 = deliver({resize, Size}, St#st{tty = TTY1, size = Size}),
            render(St1),
            loop(St1);

        %% --- Resumed from Ctrl-Z (SIGCONT): re-establish the screen ----
        {_Ref, {signal, sigcont}} ->
            TTY1 = prim_tty:handle_signal(TTY, sigcont),
            enter_screen(TTY1, St#st.alt),
            St1 = St#st{tty = TTY1},
            render(St1),
            loop(St1);

        {_Ref, eof} ->
            St#st.model;

        %% --- Messages from commands (timers, tasks, self-sends) --------
        {beamtea_msg, Msg} ->
            St1 = deliver(Msg, St),
            render(St1),
            loop(St1);

        {beamtea_every, Ms, Msg} ->
            erlang:send_after(Ms, self(), {beamtea_every, Ms, Msg}),
            St1 = deliver(Msg, St),
            render(St1),
            loop(St1);

        beamtea_quit ->
            St#st.model;

        %% A linked reader/writer died — nothing sensible left to do.
        {'EXIT', _Pid, _Reason} ->
            St#st.model;

        _Other ->
            loop(St)
    end.

%%% ===================================================================
%%% Message / command plumbing
%%% ===================================================================

%% Ctrl-C is intercepted by the runtime (unless disabled) so users always have
%% a guaranteed way out, even from a buggy program.
handle_key({ctrl, $c}, #st{catch_ctrl_c = true} = St) ->
    self() ! beamtea_quit,
    St;
handle_key(Key, St) ->
    deliver({key, Key}, St).

deliver(Msg, #st{prog = Prog, model = Model} = St) ->
    {Model1, Cmd} = (Prog#beamtea_prog.update)(Msg, Model),
    perform(beamtea_cmd:to_effects(Cmd), St#st{model = Model1}).

%% Execute side-effects. Effects that produce new messages defer them via the
%% mailbox so control returns to the loop between updates.
perform([], St) ->
    St;
perform([Effect | Rest], St) ->
    perform(Rest, run_effect(Effect, St)).

run_effect(quit, St) ->
    self() ! beamtea_quit,
    St;
run_effect({msg, Msg}, St) ->
    self() ! {beamtea_msg, Msg},
    St;
run_effect({after_ms, Ms, Msg}, St) ->
    erlang:send_after(Ms, self(), {beamtea_msg, Msg}),
    St;
run_effect({every, Ms, Msg}, St) ->
    erlang:send_after(Ms, self(), {beamtea_every, Ms, Msg}),
    St;
run_effect({task, Fun}, St) ->
    Self = self(),
    spawn(fun() -> Self ! {beamtea_msg, Fun()} end),
    St.

%%% ===================================================================
%%% Terminal I/O
%%% ===================================================================

render(#st{tty = TTY, prog = Prog, model = Model, size = Size, layout = Layout}) ->
    put(beamtea_size, Size),   %% current size, readable from view via beamtea:window_size/0
    Frame0 = (Prog#beamtea_prog.view)(Model),
    Frame = apply_layout(Layout, Frame0, Size),
    ok = prim_tty:write(TTY, beamtea_render:to_frame(Frame)).

%% Position the view within the terminal. `top_left' (the default) renders as
%% written; `center' and `{place, Opts}' use the current size, so they track
%% terminal resizes automatically.
apply_layout(top_left, Frame, _Size) -> Frame;
apply_layout(center, Frame, Size) -> beamtea_layout:center(Frame, Size);
apply_layout(fill, Frame, Size) -> beamtea_layout:frame(Frame, Size, #{});
apply_layout({frame, Opts}, Frame, Size) -> beamtea_layout:frame(Frame, Size, Opts);
apply_layout({place, Opts}, Frame, Size) -> beamtea_layout:place(Frame, Size, Opts).

window_size(TTY) ->
    case prim_tty:window_size(TTY) of
        {ok, {Cols, Rows}} -> {Cols, Rows};
        _ -> {80, 24}
    end.

enter_screen(TTY, Alt) ->
    Enter = case Alt of
                true  -> [beamtea_term:alt_enter()];
                false -> []
            end,
    ok = prim_tty:write(TTY, [Enter,
                              beamtea_term:hide_cursor(),
                              beamtea_term:clear(),
                              beamtea_term:home()]).

%% Always leave the terminal usable: show the cursor, drop the alternate
%% screen, reset styling, and (critically) return the tty to cooked mode so the
%% user's shell keeps working. Uses a synchronous write to flush before reinit.
leave_screen(TTY, Alt) ->
    Leave = case Alt of
                true  -> [beamtea_term:alt_leave()];
                false -> [<<"\r\n">>]
            end,
    _ = sync_write(TTY, [beamtea_term:reset(),
                         beamtea_term:show_cursor(),
                         Leave]),
    try prim_tty:reinit(TTY, #{input => cooked, output => cooked})
    catch _:_ -> ok
    end,
    ok.

%% prim_tty's writer acks with `{WriterRef, ok}' (not the returned monitor
%% ref), so we match a generic `{_, ok}'. Only used at teardown when the main
%% loop is no longer competing for those messages.
sync_write(TTY, Chars) ->
    {ok, Mon} = prim_tty:write(TTY, Chars, self()),
    receive
        {_Ref, ok} ->
            erlang:demonitor(Mon, [flush]),
            ok;
        {'DOWN', Mon, _, _, _} ->
            ok
    after 2000 ->
        erlang:demonitor(Mon, [flush]),
        ok
    end.
