%%% @doc A bubble: a filesystem picker, mirroring the `filepicker' package in
%%% charmbracelet/bubbles.
%%%
%%% Browse directories with the arrows, descend with Enter/→, ascend with
%%% ←/Backspace. Selecting a file records it; read it back with
%%% {@link did_select_file/1}.
-module(beamtea_filepicker).

-export([new/0, new/1, update/2, view/1,
         path/1, did_select_file/1, highlighted/1]).

-export_type([model/0]).

-opaque model() :: #{type := filepicker,
                     path := file:filename(),
                     entries := [{binary(), boolean()}],  %% {Name, IsDir}
                     cursor := non_neg_integer(),
                     offset := non_neg_integer(),
                     height := pos_integer(),
                     selected := none | file:filename(),
                     dir_color := 0..255,
                     select_color := 0..255}.

%% @equiv new(#{})
-spec new() -> model().
new() -> new(#{}).

%% @doc Options: `path' (starting directory, default cwd), `height'
%% (visible rows, default 12), colours.
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
             dir_color => maps:get(dir_color, Opts, beamtea_color:c(sky)),
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
    {Name, IsDir} = lists:nth(Cur + 1, Es),
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
                Tagged = [{list_to_binary(N),
                           filelib:is_dir(filename:join(Path, N))}
                          || N <- Names],
                lists:sort(fun sort_entries/2, Tagged);
            {error, _} ->
                []
        end,
    M#{entries := Entries}.

sort_entries({NA, true}, {NB, false}) when NA =/= NB -> true;
sort_entries({_NA, false}, {_NB, true}) -> false;
sort_entries({NA, _}, {NB, _}) -> NA =< NB.

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
       dir_color := DC, select_color := SC}) ->
    Header = beamtea_term:bold(beamtea_color:fg(cyan, list_to_binary(Path))),
    Body =
        case Es of
            [] -> [<<"\n">>, beamtea_term:faint(<<"  (empty)">>)];
            _ ->
                Window = lists:sublist(lists:nthtail(min(Off, length(Es)), Es), H),
                Rows = [render_entry(E, Off + Idx - 1 =:= Cur, DC, SC)
                        || {Idx, E} <- enumerate(Window)],
                [<<"\n">>, lists:join(<<"\n">>, Rows)]
        end,
    [Header, Body].

render_entry({Name, IsDir}, Selected, DC, SC) ->
    Glyph = case IsDir of true -> <<"📁 "/utf8>>; false -> <<"📄 "/utf8>> end,
    Label = case IsDir of
                true -> beamtea_term:paint([38, 5, DC], Name);
                false -> Name
            end,
    case Selected of
        true  -> beamtea_term:paint([38, 5, SC], [<<"> ">>, Glyph, Name]);
        false -> [<<"  ">>, Glyph, Label]
    end.

%%% --- accessors --------------------------------------------------------

-spec path(model()) -> file:filename().
path(#{path := Path}) -> Path.

%% @doc The path of a file the user selected, or `none'.
-spec did_select_file(model()) -> none | file:filename().
did_select_file(#{selected := Sel}) -> Sel.

%% @doc The `{Name, IsDir}' currently under the cursor, or `none'.
-spec highlighted(model()) -> {binary(), boolean()} | none.
highlighted(#{entries := []}) -> none;
highlighted(#{entries := Es, cursor := Cur}) -> lists:nth(Cur + 1, Es).

%%% --- helpers ----------------------------------------------------------

cwd() ->
    case file:get_cwd() of
        {ok, Dir} -> Dir;
        _ -> "/"
    end.

enumerate(List) -> lists:zip(lists:seq(1, length(List)), List).
