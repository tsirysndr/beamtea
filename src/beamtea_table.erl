%%% @doc A bubble: a scrollable, row-selectable data table, mirroring the
%%% `table' package in charmbracelet/bubbles.
%%%
%%% ```
%%%   Cols = [{<<"Name">>, 12}, {<<"Lang">>, 8}, {<<"Stars">>, 6}],
%%%   Rows = [[<<"beamtea">>, <<"Erlang">>, <<"1.2k">>], ...],
%%%   T = beamtea_table:new(Cols, Rows, #{height => 6}),
%%%   {T1, _} = beamtea_table:update({key, down}, T),
%%%   beamtea_table:selected_row(T1).
%%% '''
-module(beamtea_table).

-export([new/2, new/3, update/2, view/1,
         selected_row/1, cursor/1, set_rows/2, rows/1]).

-export_type([model/0, column/0]).

-type column() :: {Title :: iodata(), Width :: pos_integer()}.

-opaque model() :: #{type := table,
                     columns := [column()],
                     rows := [[iodata()]],
                     cursor := non_neg_integer(),
                     offset := non_neg_integer(),
                     height := pos_integer(),
                     header_color := 0..255,
                     select_color := 0..255}.

%% @equiv new(Columns, Rows, #{})
-spec new([column()], [[iodata()]]) -> model().
new(Columns, Rows) -> new(Columns, Rows, #{}).

%% @doc Options: `height' (visible rows, default 10), `header_color',
%% `select_color'.
-spec new([column()], [[iodata()]], map()) -> model().
new(Columns, Rows, Opts) ->
    #{type => table,
      columns => Columns,
      rows => Rows,
      cursor => 0,
      offset => 0,
      height => maps:get(height, Opts, 10),
      header_color => maps:get(header_color, Opts, beamtea_color:c(purple)),
      select_color => maps:get(select_color, Opts, beamtea_color:c(pink))}.

%% @doc Move the selected row with the arrows (or j/k) and scroll to follow.
-spec update(term(), model()) -> {model(), beamtea:cmd()}.
update({key, Key}, #{cursor := Cur, rows := Rows} = M) ->
    N = length(Rows),
    Cur1 = case Key of
               K when K =:= up;   K =:= {char, $k} -> max(0, Cur - 1);
               K when K =:= down; K =:= {char, $j} -> min(N - 1, Cur + 1);
               home -> 0;
               'end' -> max(0, N - 1);
               _ -> Cur
           end,
    {scroll(M#{cursor := Cur1}), beamtea:none()};
update(_Msg, M) ->
    {M, beamtea:none()}.

scroll(#{cursor := Cur, offset := Off, height := H} = M) ->
    Off1 = if
               Cur < Off      -> Cur;
               Cur >= Off + H -> Cur - H + 1;
               true           -> Off
           end,
    M#{offset := Off1}.

%% @doc Render the header and the visible rows.
-spec view(model()) -> iodata().
view(#{columns := Cols, rows := Rows, cursor := Cur, offset := Off,
       height := H, header_color := HC, select_color := SC}) ->
    Header = beamtea_term:paint([1, 38, 5, HC], render_cells(Cols, Cols)),
    Rule = beamtea_term:faint(binary:copy(<<"─"/utf8>>, table_width(Cols))),
    Window = window(Rows, Off, H),
    Lines = [render_row(Cols, Row, Off + Idx - 1 =:= Cur, SC)
             || {Idx, Row} <- enumerate(Window)],
    lists:join(<<"\n">>, [Header, Rule | Lines]).

render_row(Cols, Row, true, SC) ->
    beamtea_term:paint([7, 38, 5, SC], render_cells(Cols, Row));
render_row(Cols, Row, false, _SC) ->
    render_cells(Cols, Row).

%% Lay each cell out to its column width; header uses titles, rows use cells.
render_cells(Cols, CellsOrCols) ->
    Pairs = zip_cells(Cols, CellsOrCols),
    Rendered = [beamtea_util:pad_right(beamtea_util:truncate(Cell, W), W)
                || {W, Cell} <- Pairs],
    lists:join(<<" ">>, Rendered).

%% When rendering the header, CellsOrCols is the columns list ({Title,W});
%% otherwise it is a plain row (list of cells).
zip_cells(Cols, Cols) ->
    [{W, Title} || {Title, W} <- Cols];
zip_cells(Cols, Row) ->
    Widths = [W || {_T, W} <- Cols],
    Padded = Row ++ lists:duplicate(max(0, length(Widths) - length(Row)), <<>>),
    lists:zip(Widths, lists:sublist(Padded, length(Widths))).

%%% --- accessors --------------------------------------------------------

%% @doc The currently selected row (or `none' if the table is empty).
-spec selected_row(model()) -> {non_neg_integer(), [iodata()]} | none.
selected_row(#{rows := []}) -> none;
selected_row(#{rows := Rows, cursor := Cur}) ->
    {Cur, lists:nth(Cur + 1, Rows)}.

-spec cursor(model()) -> non_neg_integer().
cursor(#{cursor := C}) -> C.

-spec rows(model()) -> [[iodata()]].
rows(#{rows := Rows}) -> Rows.

%% @doc Replace the rows; the cursor is clamped into range.
-spec set_rows([[iodata()]], model()) -> model().
set_rows(Rows, #{cursor := Cur} = M) ->
    Max = max(0, length(Rows) - 1),
    scroll(M#{rows := Rows, cursor := min(Cur, Max)}).

%%% --- helpers ----------------------------------------------------------

table_width(Cols) ->
    lists:sum([W || {_T, W} <- Cols]) + max(0, length(Cols) - 1).

enumerate(List) -> lists:zip(lists:seq(1, length(List)), List).

window(Rows, Off, H) ->
    lists:sublist(lists:nthtail(min(Off, length(Rows)), Rows), H).
