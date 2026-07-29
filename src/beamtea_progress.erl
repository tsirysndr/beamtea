%%% @doc A bubble: a horizontal progress bar with an electric gradient.
%%%
%%% Stateless with respect to time — set the percentage (0.0–1.0) from your own
%%% model and render. Pair it with a {@link beamtea:every/2} timer to animate.
%%%
%%% ```
%%%   P0 = beamtea_progress:new(#{width => 40}),
%%%   P1 = beamtea_progress:set(0.42, P0),
%%%   beamtea_progress:view(P1)   %% => "██████░░░░░  42%"
%%% '''
-module(beamtea_progress).

-export([new/0, new/1, set/2, incr/2, percent/1, view/1]).

-export_type([model/0, rgb/0]).

-type rgb() :: {0..255, 0..255, 0..255}.

-opaque model() :: #{type := progress,
                     percent := float(),
                     width := pos_integer(),
                     full := binary(),
                     empty := binary(),
                     gradient := {rgb(), rgb()},
                     empty_color := 0..255,
                     show_percent := boolean()}.

%% Charm-style default gradient: purple (#7D56F4) -> pink (#EE6FF8).
-define(GRAD_FROM, {16#7D, 16#56, 16#F4}).
-define(GRAD_TO,   {16#EE, 16#6F, 16#F8}).

%% @equiv new(#{})
-spec new() -> model().
new() -> new(#{}).

%% @doc Options: `width' (default 40), `full'/`empty' glyphs, `gradient'
%% (`{FromRGB, ToRGB}', each an `{R,G,B}' triple — interpolated in 24-bit
%% truecolor), `empty_color' (xterm-256 index), `show_percent'.
-spec new(map()) -> model().
new(Opts) ->
    #{type => progress,
      percent => clamp(maps:get(percent, Opts, 0.0)),
      width => maps:get(width, Opts, 40),
      full => maps:get(full, Opts, <<"█"/utf8>>),
      empty => maps:get(empty, Opts, <<"░"/utf8>>),
      gradient => maps:get(gradient, Opts, {?GRAD_FROM, ?GRAD_TO}),
      empty_color => maps:get(empty_color, Opts, beamtea_color:c(dim)),
      show_percent => maps:get(show_percent, Opts, true)}.

%% @doc Set the fill fraction, clamped to [0.0, 1.0].
-spec set(number(), model()) -> model().
set(P, M) -> M#{percent := clamp(P)}.

%% @doc Add `Delta' to the current fraction (clamped).
-spec incr(number(), model()) -> model().
incr(Delta, #{percent := P} = M) -> M#{percent := clamp(P + Delta)}.

%% @doc The current fraction.
-spec percent(model()) -> float().
percent(#{percent := P}) -> P.

%% @doc Render the bar (with a trailing percentage unless disabled).
-spec view(model()) -> iodata().
view(#{percent := P, width := W, full := Full, empty := Empty,
       gradient := {From, To}, empty_color := EmptyColor,
       show_percent := ShowPct}) ->
    Filled = round(P * W),
    Bar = [gradient_cell(Full, I, W, From, To) || I <- lists:seq(1, Filled)]
        ++ [beamtea_term:paint([38, 5, EmptyColor], Empty)
            || _ <- lists:seq(Filled + 1, W)],
    Pct = case ShowPct of
              true -> [<<" ">>, pct_label(P)];
              false -> <<>>
          end,
    [Bar, Pct].

%%% --- helpers ----------------------------------------------------------

%% Interpolate a truecolor across the bar so the fill fades from `From' to `To'.
%% Interpolation is linear in RGB space between the two endpoints — this is what
%% gives a smooth purple->pink ramp (unlike walking xterm-256 index numbers,
%% which passes through unrelated hues).
gradient_cell(Glyph, I, W, From, To) when W > 1 ->
    T = (I - 1) / (W - 1),
    beamtea_term:paint_rgb(lerp_rgb(From, To, T), Glyph);
gradient_cell(Glyph, _I, _W, From, _To) ->
    beamtea_term:paint_rgb(From, Glyph).

lerp_rgb({R1, G1, B1}, {R2, G2, B2}, T) ->
    {lerp(R1, R2, T), lerp(G1, G2, T), lerp(B1, B2, T)}.

lerp(A, B, T) -> round(A + (B - A) * T).

pct_label(P) ->
    Whole = round(P * 100),
    beamtea_term:faint([integer_to_binary(Whole), <<"%">>]).

clamp(P) when P < 0.0 -> 0.0;
clamp(P) when P > 1.0 -> 1.0;
clamp(P) -> P * 1.0.
