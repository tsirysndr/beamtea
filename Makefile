.PHONY: all compile test dialyzer xref clean run examples docs

REBAR := rebar3

all: compile

compile:
	$(REBAR) compile

test:
	$(REBAR) eunit

xref:
	$(REBAR) xref

dialyzer:
	$(REBAR) dialyzer

# Generate HTML API docs into ./doc from the @doc/@spec annotations.
docs:
	$(REBAR) edoc

clean:
	$(REBAR) clean
	rm -rf _build

# Build the examples so they are on the code path.
examples:
	$(REBAR) as examples compile

# Run an example in a properly configured terminal, e.g. `make run EXAMPLE=counter`.
EXAMPLE ?= counter
run:
	@./bin/beamtea-run $(EXAMPLE)
