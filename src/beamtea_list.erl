%%% @doc A bubble: a scrollable, selectable list.
%%%
%%% Arrow keys (or j/k) move the selection; the visible window scrolls to keep
%%% the cursor in view. Forward key messages to {@link update/2} and read the
%%% choice back with {@link selected/1}.
%%%
%%% ```
%%%   L = beamtea_list:new([<<"Tea">>, <<"Coffee">>, <<"Water">>], #{title => <<"Pick one">>}),
%%%   {L1, _} = beamtea_list:update({key, down}, L),
%%%   {1, <<"Coffee">>} = beamtea_list:selected(L1).
%%% '''
-module(beamtea_list).

-export([new/1, new/2, update/2, view/1,
         selected/1, cursor/1, items/1, set_items/2]).

-export_type([model/0]).

-opaque model() :: #{type := list,
                     items := [iodata()],
                     cursor := non_neg_integer(),
                     offset := non_neg_integer(),
                     height := pos_integer(),
                     title := iodata() | none,
                     cursor_glyph := iodata(),
                     color := 0..255}.

%% @equiv new(Items, #{})
-spec new([iodata()]) -> model().
new(Items) -> new(Items, #{}).

%% @doc Options: `title', `height' (visible rows, default 10), `cursor_glyph'
%% (default "> "), `color' (selection accent).
-spec new([iodata()], map()) -> model().
new(Items, Opts) ->
    #{type => list,
      items => Items,
      cursor => 0,
      offset => 0,
      height => maps:get(height, Opts, 10),
      title => maps:get(title, Opts, none),
      cursor_glyph => maps:get(cursor_glyph, Opts, <<"> ">>),
      color => maps:get(color, Opts, beamtea_color:c(pink))}.

%% @doc Move the selection in response to a key; ignore everything else.
-spec update(term(), model()) -> {model(), beamtea:cmd()}.
update({key, Key}, M) ->
    {move(Key, M), beamtea:none()};
update(_Msg, M) ->
    {M, beamtea:none()}.

move(Key, #{cursor := Cur, items := Items} = M)
  when Key =:= up; Key =:= {char, $k} ->
    scroll(M#{cursor := max(0, Cur - 1)}, length(Items));
move(Key, #{cursor := Cur, items := Items} = M)
  when Key =:= down; Key =:= {char, $j} ->
    scroll(M#{cursor := min(length(Items) - 1, Cur + 1)}, length(Items));
move(home, M) ->
    scroll(M#{cursor := 0}, length(maps:get(items, M)));
move('end', #{items := Items} = M) ->
    scroll(M#{cursor := max(0, length(Items) - 1)}, length(Items));
move(_Other, M) ->
    M.

%% Keep the cursor inside the visible window [offset, offset+height).
scroll(#{cursor := Cur, offset := Off, height := H} = M, _N) ->
    Off1 = if
               Cur < Off       -> Cur;
               Cur >= Off + H  -> Cur - H + 1;
               true            -> Off
           end,
    M#{offset := Off1}.

%% @doc Render the (optional) title and the visible window of items.
-spec view(model()) -> iodata().
view(#{items := Items, cursor := Cur, offset := Off, height := H,
       title := Title, cursor_glyph := Glyph, color := Color}) ->
    Head = case Title of
               none -> [];
               _ -> [beamtea_term:bold(accent(Title, Color)), <<"\n\n">>]
           end,
    Window = sublist(Items, Off, H),
    Rows = [render_row(Item, Off + Idx - 1, Cur, Glyph, Color)
            || {Idx, Item} <- enumerate(Window)],
    [Head, lists:join(<<"\n">>, Rows)].

render_row(Item, Index, Cur, Glyph, Color) when Index =:= Cur ->
    accent([Glyph, Item], Color);
render_row(Item, _Index, _Cur, Glyph, _Color) ->
    Pad = binary:copy(<<" ">>, glyph_width(Glyph)),
    [Pad, Item].

%%% --- accessors --------------------------------------------------------

%% @doc `{Index, Item}' currently under the cursor (or `none' if empty).
-spec selected(model()) -> {non_neg_integer(), iodata()} | none.
selected(#{items := []}) -> none;
selected(#{items := Items, cursor := Cur}) ->
    {Cur, lists:nth(Cur + 1, Items)}.

-spec cursor(model()) -> non_neg_integer().
cursor(#{cursor := C}) -> C.

-spec items(model()) -> [iodata()].
items(#{items := Items}) -> Items.

%% @doc Replace the items; the cursor is clamped into range.
-spec set_items([iodata()], model()) -> model().
set_items(Items, #{cursor := Cur} = M) ->
    Max = max(0, length(Items) - 1),
    scroll(M#{items := Items, cursor := min(Cur, Max)}, length(Items)).

%%% --- helpers ----------------------------------------------------------

accent(Text, Color) -> beamtea_term:paint([38, 5, Color], Text).

glyph_width(Glyph) -> byte_size(iolist_to_binary(Glyph)).

enumerate(List) -> lists:zip(lists:seq(1, length(List)), List).

sublist(List, Offset, Len) ->
    lists:sublist(lists:nthtail(min(Offset, length(List)), List), Len).
