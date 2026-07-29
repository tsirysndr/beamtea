%%% @doc A bubble: a help view that renders {@link beamtea_keybind} bindings,
%%% mirroring the `help' package in charmbracelet/bubbles.
%%%
%%% Two modes: a compact single line (short help) and an expanded multi-column
%%% listing (full help). Disabled bindings are omitted automatically.
%%%
%%% ```
%%%   H = beamtea_help:new(),
%%%   beamtea_help:short(H, [Up, Down, Quit]),        %% "↑/k up · ↓/j down · q quit"
%%%   beamtea_help:full(H, [[Up, Down], [Quit]]).     %% grouped columns
%%% '''
-module(beamtea_help).

-export([new/0, new/1, short/2, full/2, view/3]).

-export_type([model/0]).

-opaque model() :: #{type := help,
                     sep := iodata(),
                     key_color := 0..255,
                     desc_color := 0..255}.

%% @equiv new(#{})
-spec new() -> model().
new() -> new(#{}).

%% @doc Options: `sep' (separator, default " · "), `key_color', `desc_color'.
-spec new(map()) -> model().
new(Opts) ->
    #{type => help,
      sep => maps:get(sep, Opts, <<" · "/utf8>>),
      key_color => maps:get(key_color, Opts, beamtea_color:c(pink)),
      desc_color => maps:get(desc_color, Opts, beamtea_color:c(dim))}.

%% @doc Compact one-line help from a flat list of bindings.
-spec short(model(), [beamtea_keybind:binding()]) -> iodata().
short(#{sep := Sep} = M, Bindings) ->
    Enabled = [B || B <- Bindings, beamtea_keybind:enabled(B)],
    lists:join(Sep, [render_pair(M, beamtea_keybind:help(B)) || B <- Enabled]).

%% @doc Expanded help from groups (columns) of bindings, one line per binding.
-spec full(model(), [[beamtea_keybind:binding()]]) -> iodata().
full(M, Groups) ->
    Columns = [render_column(M, G) || G <- Groups],
    lists:join(<<"    ">>, Columns).

render_column(M, Group) ->
    Enabled = [B || B <- Group, beamtea_keybind:enabled(B)],
    Lines = [render_pair(M, beamtea_keybind:help(B)) || B <- Enabled],
    lists:join(<<"\n">>, Lines).

%% @doc Render short help when `ShowAll' is false, full help otherwise. When
%% `ShowAll', `Bindings' must be a list of groups.
-spec view(model(), boolean(), [term()]) -> iodata().
view(M, false, Bindings) -> short(M, Bindings);
view(M, true, Groups) -> full(M, Groups).

render_pair(#{key_color := KC, desc_color := DC}, {Key, Desc}) ->
    [beamtea_term:paint([38, 5, KC], Key), <<" ">>,
     beamtea_term:paint([38, 5, DC], Desc)].
