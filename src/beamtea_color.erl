%%% @doc A small, electric colour palette inspired by Charmbracelet's Charm
%%% brand (lipgloss/bubbletea). Names map to xterm-256 colour indices so they
%%% render on any modern terminal.
%%%
%%% ```
%%%   beamtea_term:paint([38, 5, beamtea_color:c(hotpink)], "hi")
%%%   beamtea_color:fg(purple, "hi")     %% shorthand for the above
%%% '''
-module(beamtea_color).

-export([c/1, fg/2, bg/2, names/0]).

-export_type([name/0]).

-type name() ::
        charmple | purple | indigo | violet | lavender
      | hotpink | pink | magenta | fuchsia
      | cyan | aqua | teal | blue | sky
      | green | lime | mint
      | yellow | gold | orange | coral | red
      | white | cloud | gray | dim | charcoal.

%% @doc The xterm-256 index for a named colour.
-spec c(name()) -> 0..255.
%% --- purples (Charm signature #7D56F4-ish) ---
c(charmple)  -> 99;    %% #875fff — the Charm purple
c(purple)    -> 141;   %% #af87ff
c(indigo)    -> 63;    %% #5f5fff
c(violet)    -> 135;   %% #af5fff
c(lavender)  -> 183;   %% #d7afff
%% --- pinks / magentas ---
c(hotpink)   -> 205;   %% #ff5fd7
c(pink)      -> 212;   %% #ff87d7
c(magenta)   -> 200;   %% #ff00d7
c(fuchsia)   -> 198;   %% #ff0087
%% --- blues / cyans ---
c(cyan)      -> 51;    %% #00ffff
c(aqua)      -> 86;    %% #5fffd7
c(teal)      -> 44;    %% #00d7d7
c(blue)      -> 39;    %% #00afff
c(sky)       -> 117;   %% #87d7ff
%% --- greens ---
c(green)     -> 42;    %% #00d787
c(lime)      -> 154;   %% #afff00
c(mint)      -> 121;   %% #87ffaf
%% --- warm ---
c(yellow)    -> 227;   %% #ffff5f
c(gold)      -> 220;   %% #ffd700
c(orange)    -> 214;   %% #ffaf00
c(coral)     -> 209;   %% #ff875f
c(red)       -> 203;   %% #ff5f5f
%% --- neutrals ---
c(white)     -> 231;   %% #ffffff
c(cloud)     -> 253;   %% #dadada
c(gray)      -> 245;   %% #8a8a8a
c(dim)       -> 240;   %% #585858
c(charcoal)  -> 236.   %% #303030

%% @doc Paint `Text' with a named foreground colour.
-spec fg(name(), iodata()) -> iodata().
fg(Name, Text) -> beamtea_term:paint([38, 5, c(Name)], Text).

%% @doc Paint `Text' with a named background colour.
-spec bg(name(), iodata()) -> iodata().
bg(Name, Text) -> beamtea_term:paint([48, 5, c(Name)], Text).

%% @doc All known colour names.
-spec names() -> [name()].
names() ->
    [charmple, purple, indigo, violet, lavender,
     hotpink, pink, magenta, fuchsia,
     cyan, aqua, teal, blue, sky,
     green, lime, mint,
     yellow, gold, orange, coral, red,
     white, cloud, gray, dim, charcoal].
