%%% @doc A bubble: a paginator (dots or "N/M"), mirroring the `paginator'
%%% package in charmbracelet/bubbles.
%%%
%%% Tracks the current page over a total item count and helps you slice the
%%% items for the visible page.
%%%
%%% ```
%%%   P0 = beamtea_paginator:new(#{total_items => 42, per_page => 10}),
%%%   {P1, _} = beamtea_paginator:update({key, right}, P0),
%%%   {Start, End} = beamtea_paginator:slice_bounds(P1, 42),
%%%   Page = lists:sublist(Items, Start + 1, End - Start).
%%% '''
-module(beamtea_paginator).

-export([new/0, new/1, update/2, view/1,
         page/1, total_pages/1, per_page/1,
         set_total_items/2, slice_bounds/2, on_last_page/1]).

-export_type([model/0]).

-opaque model() :: #{type := paginator,
                     page := non_neg_integer(),
                     per_page := pos_integer(),
                     total_pages := pos_integer(),
                     kind := dots | arabic,
                     active := binary(),
                     inactive := binary(),
                     active_color := 0..255,
                     inactive_color := 0..255}.

%% @equiv new(#{})
-spec new() -> model().
new() -> new(#{}).

%% @doc Options: `per_page' (default 10), `total_items' (default 0),
%% `kind' (`dots' | `arabic', default `dots'), glyphs and colours.
-spec new(map()) -> model().
new(Opts) ->
    PerPage = maps:get(per_page, Opts, 10),
    Total = maps:get(total_items, Opts, 0),
    #{type => paginator,
      page => 0,
      per_page => PerPage,
      total_pages => pages(Total, PerPage),
      kind => maps:get(kind, Opts, dots),
      active => maps:get(active, Opts, <<"●"/utf8>>),
      inactive => maps:get(inactive, Opts, <<"○"/utf8>>),
      active_color => maps:get(active_color, Opts, beamtea_color:c(hotpink)),
      inactive_color => maps:get(inactive_color, Opts, beamtea_color:c(dim))}.

%% @doc Move between pages with ←/→, h/l, or PageUp/PageDown.
-spec update(term(), model()) -> {model(), beamtea:cmd()}.
update({key, Key}, #{page := P, total_pages := TP} = M) ->
    P1 = case Key of
             K when K =:= left; K =:= {char, $h}; K =:= page_up ->
                 max(0, P - 1);
             K when K =:= right; K =:= {char, $l}; K =:= page_down ->
                 min(TP - 1, P + 1);
             home -> 0;
             'end' -> TP - 1;
             _ -> P
         end,
    {M#{page := P1}, beamtea:none()};
update(_Msg, M) ->
    {M, beamtea:none()}.

%% @doc Render the paginator.
-spec view(model()) -> iodata().
view(#{kind := arabic, page := P, total_pages := TP}) ->
    beamtea_term:faint([integer_to_binary(P + 1), <<"/">>,
                        integer_to_binary(TP)]);
view(#{kind := dots, page := P, total_pages := TP,
       active := A, inactive := I, active_color := AC, inactive_color := IC}) ->
    Dots = [dot(N =:= P, A, I, AC, IC) || N <- lists:seq(0, TP - 1)],
    lists:join(<<" ">>, Dots).

dot(true, A, _I, AC, _IC)  -> beamtea_term:paint([38, 5, AC], A);
dot(false, _A, I, _AC, IC) -> beamtea_term:paint([38, 5, IC], I).

%%% --- accessors --------------------------------------------------------

-spec page(model()) -> non_neg_integer().
page(#{page := P}) -> P.

-spec total_pages(model()) -> pos_integer().
total_pages(#{total_pages := TP}) -> TP.

-spec per_page(model()) -> pos_integer().
per_page(#{per_page := PP}) -> PP.

%% @doc Recompute the page count for a new item total, clamping the page.
-spec set_total_items(non_neg_integer(), model()) -> model().
set_total_items(Total, #{per_page := PP, page := P} = M) ->
    TP = pages(Total, PP),
    M#{total_pages := TP, page := min(P, TP - 1)}.

%% @doc `{StartIndex, EndIndex}' (0-based, half-open) for the current page over
%% `TotalItems' — feed straight into `lists:sublist/3'.
-spec slice_bounds(model(), non_neg_integer()) -> {non_neg_integer(), non_neg_integer()}.
slice_bounds(#{page := P, per_page := PP}, TotalItems) ->
    Start = P * PP,
    End = min(Start + PP, TotalItems),
    {Start, End}.

-spec on_last_page(model()) -> boolean().
on_last_page(#{page := P, total_pages := TP}) -> P =:= TP - 1.

%%% --- helpers ----------------------------------------------------------

pages(Total, PerPage) -> max(1, (Total + PerPage - 1) div PerPage).
