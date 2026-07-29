%%% File picker demo — browse the filesystem and select a file. Uses the
%%% beamtea_filepicker bubble.
%%%
%%% Run:  rebar3 as examples shell
%%%       filepicker_demo:main().
-module(filepicker_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

-record(st, {fp, chosen = none}).

main() -> beamtea:start(?MODULE).

init(_Flags) ->
    FP = beamtea_filepicker:new(#{height => 12}),
    {#st{fp = FP}, beamtea:none()}.

update({key, {char, $q}}, St) -> {St, beamtea:quit()};
update(Msg, #st{fp = FP} = St) ->
    {FP1, Cmd} = beamtea_filepicker:update(Msg, FP),
    Chosen = case beamtea_filepicker:did_select_file(FP1) of
                 none -> St#st.chosen;
                 File -> File
             end,
    {St#st{fp = FP1, chosen = Chosen}, Cmd}.

view(#st{fp = FP, chosen = Chosen}) ->
    Footer =
        case Chosen of
            none -> beamtea_term:faint(<<"↑/↓ move · enter/→ open · ←/bksp up · q quit"/utf8>>);
            File -> [beamtea_color:fg(green, <<"selected: ">>),
                     beamtea_term:bold(list_to_binary(File))]
        end,
    [
     "  ", beamtea_color:fg(charmple, beamtea_term:bold(<<"beamtea file picker">>)), "\n\n",
     "  ", beamtea_filepicker:view(FP), "\n\n",
     "  ", Footer, "\n"
    ].
