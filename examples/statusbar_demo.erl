%%% Status bar demo — a beautiful full-width bottom status bar composed from
%%% coloured segments with beamtea_style, pinned to the last terminal row.
%%%
%%% A left mode badge + filename, an elastic filler, and right-aligned position,
%%% encoding and a beamtea badge. `i' enters INSERT, Esc returns to NORMAL,
%%% arrows move the cursor, `q' quits.
%%%
%%% Run:  ./bin/beamtea-run statusbar_demo
-module(statusbar_demo).
-behaviour(beamtea).

-export([main/0, init/1, update/2, view/1]).

-record(st, {mode = normal, line = 1, col = 1}).

main() -> beamtea:start(?MODULE).

init(_Flags) -> {#st{}, beamtea:none()}.

%%% --- update ----------------------------------------------------------

update({key, {char, $i}}, #st{mode = normal} = St) ->
    {St#st{mode = insert}, beamtea:none()};
update({key, esc}, St) ->
    {St#st{mode = normal}, beamtea:none()};
update({key, {char, $q}}, #st{mode = normal} = St) ->
    {St, beamtea:quit()};
update({key, Key}, St) ->
    {move(Key, St), beamtea:none()};
update(_Msg, St) ->
    {St, beamtea:none()}.

move(up, #st{line = L} = St)    -> St#st{line = max(1, L - 1)};
move(down, #st{line = L} = St)  -> St#st{line = L + 1};
move(left, #st{col = C} = St)   -> St#st{col = max(1, C - 1)};
move(right, #st{col = C} = St)  -> St#st{col = C + 1};
move(_Other, St)                -> St.

%%% --- view ------------------------------------------------------------

view(#st{mode = Mode} = St) ->
    {W, H} = beamtea:window_size(),
    Bar = status_bar(St, W),
    Body = content(Mode, H - 1),
    lists:join(<<"\n">>, Body ++ [Bar]).

%% Fill the area above the bar with a little placeholder document.
content(Mode, Rows) ->
    Title = ["  ", beamtea_color:fg(charmple, beamtea_term:bold(<<"beamtea editor">>))],
    Hint = ["  ", beamtea_term:faint(hint(Mode))],
    Lines = [Title, <<>>, Hint],
    Lines ++ lists:duplicate(max(0, Rows - length(Lines)), <<>>).

hint(insert) -> <<"-- INSERT --  ·  esc to return to NORMAL"/utf8>>;
hint(normal) -> <<"i insert · ↑↓←→ move · q quit"/utf8>>.

%%% --- the status bar --------------------------------------------------

status_bar(#st{mode = Mode, line = L, col = C}, W) ->
    ModeSeg = mode_badge(Mode),
    FileSeg = seg(<<" main.erl "/utf8>>, 238, 252),
    Pos = seg([<<" Ln ">>, integer_to_binary(L),
               <<", Col ">>, integer_to_binary(C), <<" ">>], 238, 252),
    Enc = seg(<<" UTF-8 ">>, 240, 252),
    Logo = seg(<<" beamtea ">>, beamtea_color:c(charmple), 231, true),
    Left = beamtea_style:join_horizontal(top, [ModeSeg, FileSeg]),
    Right = beamtea_style:join_horizontal(top, [Enc, Pos, Logo]),
    Fill = filler(max(0, W - beamtea_util:visible_width(Left)
                           - beamtea_util:visible_width(Right))),
    beamtea_style:join_horizontal(top, [Left, Fill, Right]).

mode_badge(insert) -> seg(<<" INSERT ">>, beamtea_color:c(green), 232, true);
mode_badge(normal) -> seg(<<" NORMAL ">>, beamtea_color:c(pink), 232, true).

%% A coloured segment; `Bold' optional.
seg(Text, Bg, Fg) -> seg(Text, Bg, Fg, false).
seg(Text, Bg, Fg, Bold) ->
    S0 = beamtea_style:background(beamtea_style:foreground(beamtea_style:new(), Fg), Bg),
    S1 = case Bold of true -> beamtea_style:bold(S0); false -> S0 end,
    beamtea_style:render(S1, Text).

%% Elastic middle: a background-filled span of the given width.
filler(Width) ->
    beamtea_style:render(
      beamtea_style:background(beamtea_style:width(beamtea_style:new(), Width), 236), <<>>).
