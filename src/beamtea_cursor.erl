%%% @doc A bubble: a blinking cursor, mirroring the `cursor' package in
%%% charmbracelet/bubbles.
%%%
%%% Self-ticking like the spinner. Start it with {@link blink/1}, forward
%%% messages to {@link update/2}, and wrap the character under the cursor with
%%% {@link view/2} — it alternates between reverse-video (shown) and plain
%%% (hidden) on each blink.
-module(beamtea_cursor).

-export([new/0, new/1, blink/1, update/2, view/2,
         focus/1, blur/1, set_mode/2, visible/1]).

-export_type([model/0]).

-opaque model() :: #{type := cursor,
                     visible := boolean(),
                     mode := blink | static | hidden,
                     blink_ms := pos_integer(),
                     ref := reference()}.

%% @equiv new(#{})
-spec new() -> model().
new() -> new(#{}).

%% @doc Options: `mode' (`blink' | `static' | `hidden', default `blink'),
%% `blink_ms' (default 530, matching most terminals).
-spec new(map()) -> model().
new(Opts) ->
    #{type => cursor,
      visible => true,
      mode => maps:get(mode, Opts, blink),
      blink_ms => maps:get(blink_ms, Opts, 530),
      ref => make_ref()}.

%% @doc The command that starts blinking. Return it from `init/1'.
-spec blink(model()) -> beamtea:cmd().
blink(#{mode := blink, ref := Ref, blink_ms := Ms}) ->
    {tick, Ms, {beamtea_cursor, Ref}};
blink(_M) ->
    beamtea:none().

%% @doc Toggle visibility on the cursor's own tick; ignore other messages.
-spec update(term(), model()) -> {model(), beamtea:cmd()}.
update({beamtea_cursor, Ref}, #{ref := Ref, mode := blink, visible := V} = M) ->
    M1 = M#{visible := not V},
    {M1, blink(M1)};
update(_Msg, M) ->
    {M, beamtea:none()}.

%% @doc Render `Char' according to the cursor's current state.
-spec view(model(), iodata()) -> iodata().
view(#{mode := hidden}, Char) -> Char;
view(#{mode := static}, Char) -> beamtea_term:reverse(Char);
view(#{visible := true}, Char) -> beamtea_term:reverse(Char);
view(#{visible := false}, Char) -> Char.

-spec focus(model()) -> model().
focus(M) -> M#{mode := blink, visible := true}.

-spec blur(model()) -> model().
blur(M) -> M#{mode := static, visible := true}.

-spec set_mode(blink | static | hidden, model()) -> model().
set_mode(Mode, M) -> M#{mode := Mode}.

-spec visible(model()) -> boolean().
visible(#{mode := hidden}) -> false;
visible(#{visible := V}) -> V.
