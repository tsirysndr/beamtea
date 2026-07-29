%%% Spinner demo — cycle through every built-in spinner style. Uses the
%%% beamtea_spinner bubble.
%%%
%%% Run:  rebar3 as examples shell
%%%       spinner_demo:main().
-module(spinner_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

-record(st, {styles, idx = 1, spinner}).

main() -> beamtea:start(?MODULE).

init(_Flags) ->
    Styles = beamtea_spinner:styles(),
    S = beamtea_spinner:new(hd(Styles)),
    {#st{styles = Styles, spinner = S}, beamtea_spinner:tick(S)}.

update({key, {char, $q}}, St) ->
    {St, beamtea:quit()};
update({key, Key}, #st{styles = Styles, idx = I} = St)
  when Key =:= right; Key =:= left; Key =:= {char, $\s} ->
    I1 = case Key of
             left -> ((I - 2 + length(Styles)) rem length(Styles)) + 1;
             _    -> (I rem length(Styles)) + 1
         end,
    NewStyle = lists:nth(I1, Styles),
    S = beamtea_spinner:new(NewStyle),
    {St#st{idx = I1, spinner = S}, beamtea_spinner:tick(S)};
update(Msg, #st{spinner = S} = St) ->
    {S1, Cmd} = beamtea_spinner:update(Msg, S),
    {St#st{spinner = S1}, Cmd}.

view(#st{styles = Styles, idx = I, spinner = S}) ->
    Style = lists:nth(I, Styles),
    [
     "\n  ", beamtea_color:fg(charmple, beamtea_term:bold(<<"beamtea spinners">>)), "\n\n",
     "  ", beamtea_spinner:view(S), "  ",
     beamtea_color:fg(cyan, atom_to_binary(Style, utf8)),
     beamtea_term:faint(io_lib:format("  (~p/~p)", [I, length(Styles)])), "\n\n",
     "  ", beamtea_term:faint(<<"←/→ or space to change style · q quit"/utf8>>), "\n"
    ].
