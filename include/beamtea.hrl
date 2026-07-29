%% beamtea — shared definitions.
-ifndef(BEAMTEA_HRL).
-define(BEAMTEA_HRL, true).

%% A normalized program: three funs implementing the Elm architecture.
-record(beamtea_prog, {
    init   :: fun((term()) -> {term(), term()}),
    update :: fun((term(), term()) -> {term(), term()}),
    view   :: fun((term()) -> iodata())
}).

-endif.
