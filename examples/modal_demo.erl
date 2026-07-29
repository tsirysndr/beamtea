%%% Modal demo — an advanced example: a floating yes/no confirmation modal
%%% composed entirely with beamtea_style (borders, padding, colours, buttons)
%%% and overlaid on a backdrop with beamtea_layout:overlay_center/3.
%%%
%%% ←/→ or Tab switch the focused button · Enter/Y/N confirm · Esc/q quit.
%%%
%%% Run:  ./bin/beamtea-run modal_demo
-module(modal_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

-record(st, {focus = no, choice = none}).

main() -> beamtea:start(?MODULE).

init(_Flags) -> {#st{}, beamtea:none()}.

%%% --- update ----------------------------------------------------------

update({key, Key}, #st{choice = none} = St) ->
    case Key of
        _ when Key =:= left; Key =:= right; Key =:= tab;
               Key =:= {char, $h}; Key =:= {char, $l} ->
            {St#st{focus = toggle(St#st.focus)}, beamtea:none()};
        {char, $y} -> {St#st{choice = yes}, beamtea:none()};
        {char, $n} -> {St#st{choice = no}, beamtea:none()};
        K when K =:= enter; K =:= {char, $\s} ->
            {St#st{choice = St#st.focus}, beamtea:none()};
        K when K =:= esc; K =:= {char, $q} -> {St, beamtea:quit()};
        _ -> {St, beamtea:none()}
    end;
update({key, K}, St) when K =:= {char, $q}; K =:= enter; K =:= esc ->
    {St, beamtea:quit()};
update(_Msg, St) ->
    {St, beamtea:none()}.

toggle(yes) -> no;
toggle(no) -> yes.

%%% --- view ------------------------------------------------------------

view(#st{choice = Choice, focus = Focus}) ->
    {W, H} = beamtea:window_size(),
    Modal = case Choice of
                none -> question_modal(Focus);
                _ -> result_modal(Choice)
            end,
    beamtea_layout:overlay_center(backdrop(W, H), Modal, {W, H}).

%% A plain-text "app" behind the modal (no ANSI — overlay slices it by column).
backdrop(W, H) ->
    Header = ["  beamtea mail  ", lists:duplicate(max(0, W - 16), $\s)],
    Rows = [io_lib:format("   ~2..0B   ~-20s   unread", [N, subject(N)])
            || N <- lists:seq(1, max(1, H - 3))],
    lists:join(<<"\n">>, [Header, <<>> | Rows]).

subject(N) ->
    S = ["Quarterly report", "Re: launch plan", "Lunch?", "Invoice #4021",
         "Design review", "Weekly digest", "Welcome to beamtea"],
    lists:nth((N rem length(S)) + 1, S).

question_modal(Focus) ->
    Title = beamtea_style:render(
              beamtea_style:bold(beamtea_style:foreground(beamtea_style:new(), pink)),
              <<"Confirm deletion">>),
    Msg = <<"Delete “Quarterly report”?"/utf8>>,
    Sub = beamtea_style:render(beamtea_style:faint(beamtea_style:new()),
                               <<"This cannot be undone.">>),
    Buttons = beamtea_style:join_horizontal(
                top, [button(<<" Yes ">>, Focus =:= yes),
                      <<"   ">>,
                      button(<<" No ">>, Focus =:= no)]),
    Help = beamtea_style:render(beamtea_style:faint(beamtea_style:new()),
                                <<"←/→ switch · enter confirm · esc quit"/utf8>>),
    Content = beamtea_style:join_vertical(
                center, [Title, <<>>, Msg, Sub, <<>>, Buttons, <<>>, Help]),
    beamtea_style:render(modal_box(pink), Content).

result_modal(Choice) ->
    {Text, Color} = case Choice of
                        yes -> {<<"🗑  Deleted."/utf8>>, red};
                        no  -> {<<"✓  Cancelled."/utf8>>, green}
                    end,
    Line = beamtea_style:render(
             beamtea_style:bold(beamtea_style:foreground(beamtea_style:new(), Color)), Text),
    Help = beamtea_style:render(beamtea_style:faint(beamtea_style:new()),
                                <<"press q to quit">>),
    Content = beamtea_style:join_vertical(center, [Line, <<>>, Help]),
    beamtea_style:render(modal_box(Color), Content).

%% The modal shell: rounded border in an accent colour, generous padding.
modal_box(Accent) ->
    S0 = beamtea_style:new(),
    S1 = beamtea_style:border(S0, rounded),
    S2 = beamtea_style:border_foreground(S1, Accent),
    beamtea_style:padding(S2, {1, 4}).

%% A pill button: focused = filled pink, unfocused = dim.
button(Label, Focused) ->
    Base = beamtea_style:padding(beamtea_style:new(), {0, 1}),
    S = case Focused of
            true ->
                beamtea_style:bold(
                  beamtea_style:background(
                    beamtea_style:foreground(Base, {16#1a, 16#1a, 16#1a}), pink));
            false ->
                beamtea_style:foreground(
                  beamtea_style:background(Base, 238), 250)
        end,
    beamtea_style:render(S, Label).
