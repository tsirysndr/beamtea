%%% @doc A bubble: a scrollable viewport over a block of text, mirroring the
%%% `viewport' package in charmbracelet/bubbles.
%%%
%%% Give it content and a height; it shows a window into that content that the
%%% user can scroll with the arrows, PageUp/PageDown, Home/End (and j/k).
%%%
%%% ```
%%%   V0 = beamtea_viewport:new(#{height => 10}),
%%%   V1 = beamtea_viewport:set_content(BigText, V0),
%%%   {V2, _} = beamtea_viewport:update({key, down}, V1),
%%%   beamtea_viewport:view(V2).
%%% '''
-module(beamtea_viewport).

-export([new/0, new/1, set_content/2, update/2, view/1,
         scroll_percent/1, at_top/1, at_bottom/1,
         line_down/2, line_up/2, offset/1, total_lines/1]).

-export_type([model/0]).

-opaque model() :: #{type := viewport,
                     lines := [iodata()],
                     offset := non_neg_integer(),
                     height := pos_integer(),
                     width := pos_integer() | infinity}.

%% @equiv new(#{})
-spec new() -> model().
new() -> new(#{}).

%% @doc Options: `height' (visible rows, default 20), `width' (optional).
-spec new(map()) -> model().
new(Opts) ->
    #{type => viewport,
      lines => [],
      offset => 0,
      height => maps:get(height, Opts, 20),
      width => maps:get(width, Opts, infinity)}.

%% @doc Replace the content (split into lines on `\n').
-spec set_content(iodata(), model()) -> model().
set_content(Content, M) ->
    M#{lines := beamtea_render:lines(Content), offset := 0}.

%% @doc Scroll in response to a key.
-spec update(term(), model()) -> {model(), beamtea:cmd()}.
update({key, Key}, #{height := H} = M) ->
    M1 = case Key of
             K when K =:= down; K =:= {char, $j} -> line_down(1, M);
             K when K =:= up;   K =:= {char, $k} -> line_up(1, M);
             page_down -> line_down(H, M);
             page_up   -> line_up(H, M);
             {char, $\s} -> line_down(H, M);
             home -> M#{offset := 0};
             'end' -> M#{offset := max_offset(M)};
             _ -> M
         end,
    {M1, beamtea:none()};
update(_Msg, M) ->
    {M, beamtea:none()}.

%% @doc The visible window of lines.
-spec view(model()) -> iodata().
view(#{lines := Lines, offset := Off, height := H}) ->
    Window = lists:sublist(lists:nthtail(min(Off, length(Lines)), Lines), H),
    %% Pad to full height so the frame does not jump as content scrolls.
    Padding = lists:duplicate(max(0, H - length(Window)), <<>>),
    lists:join(<<"\n">>, Window ++ Padding).

%%% --- scrolling --------------------------------------------------------

%% @doc Scroll down by `N' lines (clamped).
-spec line_down(non_neg_integer(), model()) -> model().
line_down(N, #{offset := Off} = M) ->
    M#{offset := min(max_offset(M), Off + N)}.

%% @doc Scroll up by `N' lines (clamped).
-spec line_up(non_neg_integer(), model()) -> model().
line_up(N, #{offset := Off} = M) ->
    M#{offset := max(0, Off - N)}.

max_offset(#{lines := Lines, height := H}) ->
    max(0, length(Lines) - H).

%%% --- accessors --------------------------------------------------------

-spec offset(model()) -> non_neg_integer().
offset(#{offset := Off}) -> Off.

-spec total_lines(model()) -> non_neg_integer().
total_lines(#{lines := Lines}) -> length(Lines).

-spec at_top(model()) -> boolean().
at_top(#{offset := Off}) -> Off =:= 0.

-spec at_bottom(model()) -> boolean().
at_bottom(#{offset := Off} = M) -> Off >= max_offset(M).

%% @doc How far through the content we are scrolled, as 0.0–1.0.
-spec scroll_percent(model()) -> float().
scroll_percent(#{offset := Off} = M) ->
    case max_offset(M) of
        0 -> 1.0;
        Max -> Off / Max
    end.
