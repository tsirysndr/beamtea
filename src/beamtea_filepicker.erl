%%% @doc A bubble: a filesystem picker, mirroring the `filepicker' package in
%%% charmbracelet/bubbles.
%%%
%%% Browse directories with the arrows, descend with Enter/→, ascend with
%%% ←/Backspace. Each row shows a Unix-style permissions column, a size column
%%% and the name — directories in purple, files in gray. Selecting a file
%%% records it; read it back with {@link did_select_file/1}.
-module(beamtea_filepicker).

-include_lib("kernel/include/file.hrl").

-export([new/0, new/1, update/2, view/1,
         path/1, did_select_file/1, highlighted/1]).

-export_type([model/0]).

%% Each entry: {Name, IsDir, SizeBytes, PermsString}.
-type entry() :: {binary(), boolean(), non_neg_integer(), binary()}.

-opaque model() :: #{type := filepicker,
                     path := file:filename(),
                     entries := [entry()],
                     cursor := non_neg_integer(),
                     offset := non_neg_integer(),
                     height := pos_integer(),
                     selected := none | file:filename(),
                     dir_color := 0..255,
                     file_color := 0..255,
                     select_color := 0..255}.

%% @equiv new(#{})
-spec new() -> model().
new() -> new(#{}).

%% @doc Options: `path' (starting directory, default cwd), `height'
%% (visible rows, default 12), `dir_color' (default purple), `file_color'
%% (default gray), `select_color'.
-spec new(map()) -> model().
new(Opts) ->
    Path = maps:get(path, Opts, cwd()),
    Base = #{type => filepicker,
             path => Path,
             entries => [],
             cursor => 0,
             offset => 0,
             height => maps:get(height, Opts, 12),
             selected => none,
             dir_color => maps:get(dir_color, Opts, beamtea_color:c(purple)),
             file_color => maps:get(file_color, Opts, beamtea_color:c(gray)),
             select_color => maps:get(select_color, Opts, beamtea_color:c(pink))},
    load(Base).

%% @doc Navigate in response to a key.
-spec update(term(), model()) -> {model(), beamtea:cmd()}.
update({key, Key}, #{cursor := Cur, entries := Es} = M) ->
    N = length(Es),
    M1 =
        case Key of
            K when K =:= up;   K =:= {char, $k} ->
                scroll(M#{cursor := max(0, Cur - 1)});
            K when K =:= down; K =:= {char, $j} ->
                scroll(M#{cursor := min(max(0, N - 1), Cur + 1)});
            home -> scroll(M#{cursor := 0});
            'end' -> scroll(M#{cursor := max(0, N - 1)});
            K when K =:= enter; K =:= right; K =:= {char, $l} ->
                open(M);
            K when K =:= left; K =:= backspace; K =:= {char, $h} ->
                ascend(M);
            _ -> M
        end,
    {M1, beamtea:none()};
update(_Msg, M) ->
    {M, beamtea:none()}.

%% Descend into a directory or select a file.
open(#{entries := []} = M) -> M;
open(#{entries := Es, cursor := Cur, path := Path} = M) ->
    {Name, IsDir, _Size, _Perms} = lists:nth(Cur + 1, Es),
    Full = filename:join(Path, unicode:characters_to_list(Name)),
    case IsDir of
        true  -> load(M#{path := Full, cursor := 0, offset := 0});
        false -> M#{selected := Full}
    end.

ascend(#{path := Path} = M) ->
    Parent = filename:dirname(Path),
    case Parent =:= Path of
        true -> M;  %% already at root
        false -> load(M#{path := Parent, cursor := 0, offset := 0})
    end.

%% (Re)read the current directory: directories first, then files, alpha-sorted.
load(#{path := Path} = M) ->
    Entries =
        case file:list_dir(Path) of
            {ok, Names} ->
                Tagged = [entry_info(Path, N) || N <- Names],
                lists:sort(fun sort_entries/2, Tagged);
            {error, _} ->
                []
        end,
    M#{entries := Entries}.

%% Read type, size and permissions for one directory entry.
entry_info(Path, Name) ->
    Full = filename:join(Path, Name),
    case file:read_file_info(Full, [{time, posix}]) of
        {ok, #file_info{type = Type, size = Size, mode = Mode}} ->
            {list_to_binary(Name), Type =:= directory, Size, perms(Type, Mode)};
        {error, _} ->
            {list_to_binary(Name), filelib:is_dir(Full), 0, <<"??????????">>}
    end.

sort_entries({_, true, _, _}, {_, false, _, _}) -> true;
sort_entries({_, false, _, _}, {_, true, _, _}) -> false;
sort_entries({NA, _, _, _}, {NB, _, _, _}) -> NA =< NB.

scroll(#{cursor := Cur, offset := Off, height := H} = M) ->
    Off1 = if
               Cur < Off      -> Cur;
               Cur >= Off + H -> Cur - H + 1;
               true           -> Off
           end,
    M#{offset := Off1}.

%% @doc Render the current path and the visible window of entries.
-spec view(model()) -> iodata().
view(#{path := Path, entries := Es, cursor := Cur, offset := Off, height := H,
       dir_color := DC, file_color := FC, select_color := SC}) ->
    Header = beamtea_term:bold(beamtea_color:fg(cyan, list_to_binary(Path))),
    Body =
        case Es of
            [] -> [<<"\n">>, beamtea_term:faint(<<"  (empty)">>)];
            _ ->
                Window = lists:sublist(lists:nthtail(min(Off, length(Es)), Es), H),
                Rows = [render_entry(E, Off + Idx - 1 =:= Cur, DC, FC, SC)
                        || {Idx, E} <- enumerate(Window)],
                [<<"\n">>, lists:join(<<"\n">>, Rows)]
        end,
    [Header, Body].

%% A row: cursor marker, permissions, right-aligned size, then the coloured
%% name (purple for dirs, gray for files; bold + pink marker when selected).
render_entry({Name, IsDir, Size, Perms}, Selected, DC, FC, SC) ->
    NameColor = case IsDir of true -> DC; false -> FC end,
    PermsCol = beamtea_term:faint(Perms),
    SizeCol = beamtea_term:faint(pad_left(human_size(IsDir, Size), 7)),
    {Marker, NameCol} =
        case Selected of
            true ->
                {beamtea_term:paint([38, 5, SC], <<"> ">>),
                 beamtea_term:bold(beamtea_term:paint([38, 5, NameColor], Name))};
            false ->
                {<<"  ">>, beamtea_term:paint([38, 5, NameColor], Name)}
        end,
    [Marker, PermsCol, <<"  ">>, SizeCol, <<"  ">>, NameCol].

%%% --- accessors --------------------------------------------------------

-spec path(model()) -> file:filename().
path(#{path := Path}) -> Path.

%% @doc The path of a file the user selected, or `none'.
-spec did_select_file(model()) -> none | file:filename().
did_select_file(#{selected := Sel}) -> Sel.

%% @doc The `{Name, IsDir}' currently under the cursor, or `none'.
-spec highlighted(model()) -> {binary(), boolean()} | none.
highlighted(#{entries := []}) -> none;
highlighted(#{entries := Es, cursor := Cur}) ->
    {Name, IsDir, _Size, _Perms} = lists:nth(Cur + 1, Es),
    {Name, IsDir}.

%%% --- helpers ----------------------------------------------------------

cwd() ->
    case file:get_cwd() of
        {ok, Dir} -> Dir;
        _ -> "/"
    end.

enumerate(List) -> lists:zip(lists:seq(1, length(List)), List).

%% A Unix-style permission string, e.g. "drwxr-xr-x".
perms(Type, Mode) ->
    Bits = [{8#400, $r}, {8#200, $w}, {8#100, $x},
            {8#040, $r}, {8#020, $w}, {8#010, $x},
            {8#004, $r}, {8#002, $w}, {8#001, $x}],
    Chars = [case Mode band B of 0 -> $-; _ -> C end || {B, C} <- Bits],
    list_to_binary([type_char(Type) | Chars]).

type_char(directory) -> $d;
type_char(symlink)   -> $l;
type_char(device)    -> $c;
type_char(_)         -> $-.

%% Human-readable size; directories show "-".
human_size(true, _Size) -> <<"-">>;
human_size(false, Size) ->
    if
        Size < 1024        -> <<(integer_to_binary(Size))/binary, "B">>;
        Size < 1024 * 1024 -> unit(Size / 1024, "K");
        Size < 1024 * 1024 * 1024 -> unit(Size / (1024 * 1024), "M");
        true -> unit(Size / (1024 * 1024 * 1024), "G")
    end.

unit(V, Suffix) ->
    %% one decimal place, e.g. "1.2K"
    Whole = trunc(V),
    Tenth = trunc((V - Whole) * 10),
    iolist_to_binary([integer_to_binary(Whole), $., integer_to_binary(Tenth), Suffix]).

pad_left(Bin0, Width) ->
    Bin = iolist_to_binary(Bin0),
    Len = byte_size(Bin),
    case Width > Len of
        true -> <<(binary:copy(<<" ">>, Width - Len))/binary, Bin/binary>>;
        false -> Bin
    end.
