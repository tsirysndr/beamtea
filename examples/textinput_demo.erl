%%% Text input demo — a focused text field with a live greeting. Uses the
%%% beamtea_textinput bubble.
%%%
%%% Run:  ./bin/beamtea-run textinput_demo
-module(textinput_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

-record(st, {input, submitted = none}).

main() -> beamtea:start(?MODULE).

init(_Flags) ->
    Input = beamtea_textinput:focus(
              beamtea_textinput:new(#{prompt => <<"name › "/utf8>>,
                                      placeholder => <<"type your name">>})),
    {#st{input = Input}, beamtea:none()}.

update({key, {ctrl, $c}}, St) -> {St, beamtea:quit()};
update({key, esc}, St)        -> {St, beamtea:quit()};
update({key, enter}, #st{input = In} = St) ->
    {St#st{submitted = beamtea_textinput:value(In)}, beamtea:none()};
update(Msg, #st{input = In} = St) ->
    {In1, Cmd} = beamtea_textinput:update(Msg, In),
    {St#st{input = In1}, Cmd}.

view(#st{input = In, submitted = Sub}) ->
    Greeting =
        case Sub of
            none -> beamtea_term:faint(<<"(press enter to greet)">>);
            <<>> -> beamtea_term:faint(<<"(nothing to greet)">>);
            Name -> [beamtea_color:fg(green, <<"hello, ">>),
                     beamtea_color:fg(hotpink, beamtea_term:bold(Name)),
                     beamtea_color:fg(green, <<"!">>)]
        end,
    [
     "\n  ", beamtea_color:fg(charmple, beamtea_term:bold(<<"beamtea text input">>)), "\n\n",
     "  ", beamtea_textinput:view(In), "\n\n",
     "  ", Greeting, "\n\n",
     "  ", beamtea_term:faint(<<"enter greet · esc/ctrl-c quit"/utf8>>), "\n"
    ].
