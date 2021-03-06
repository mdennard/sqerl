DEPS = $(CURDIR)/deps

DIALYZER_OPTS = -Wunderspecs

# List dependencies that should be included in a cached dialyzer PLT file.
# DIALYZER_DEPS = deps/app1/ebin \
#                 deps/app2/ebin
DIALYZER_DEPS = deps/epgsql/ebin deps/pooler/ebin deps/envy/ebin

DEPS_PLT = sqerl.plt

ERLANG_DIALYZER_APPS = asn1 \
                       compiler \
                       crypto \
                       edoc \
                       edoc \
                       erts \
                       eunit \
                       eunit \
                       gs \
                       hipe \
                       inets \
                       kernel \
                       mnesia \
                       mnesia \
                       observer \
                       public_key \
                       runtime_tools \
                       runtime_tools \
                       ssl \
                       stdlib \
                       syntax_tools \
                       syntax_tools \
                       tools \
                       webtool \
                       xmerl

all: compile eunit dialyzer

# Clean ebin and .eunit of this project
clean:
	@rebar clean skip_deps=true

# Clean this project and all deps
allclean:
	@rebar clean

compile: $(DEPS)
	@rebar compile

$(DEPS):
	@rebar get-deps

# Full clean and removal of all deps. Remove deps first to avoid
# wasted effort of cleaning deps before nuking them.
distclean:
	@rm -rf deps $(DEPS_PLT)
	@rebar clean

eunit:
	@rebar skip_deps=true eunit

test: eunit

# Only include local PLT if we have deps that we are going to analyze
ifeq ($(strip $(DIALYZER_DEPS)),)
dialyzer: ~/.dialyzer_plt
	@dialyzer $(DIALYZER_OPTS) -r ebin
else
dialyzer: ~/.dialyzer_plt $(DEPS_PLT)
	@dialyzer $(DIALYZER_OPTS) --plts ~/.dialyzer_plt $(DEPS_PLT) -r ebin

$(DEPS_PLT):
	@dialyzer --build_plt $(DIALYZER_DEPS) --output_plt $(DEPS_PLT)
endif

~/.dialyzer_plt:
	@echo "ERROR: Missing ~/.dialyzer_plt. Please wait while a new PLT is compiled."
	dialyzer --build_plt --apps $(ERLANG_DIALYZER_APPS)
	@echo "now try your build again"

doc:
	@rebar doc skip_deps=true

DB_TYPE ?= pgsql
-include itest/$(DB_TYPE)_conf.mk

itest_create:
	@echo Creating integration test database
	@${DB_CMD} < itest/itest_${DB_TYPE}_create.sql

itest_clean:
	@rm -f itest/*.beam
	@echo Dropping integration test database
	@${DB_CMD} < itest/itest_${DB_TYPE}_clean.sql

itest: compile itest_create itest_run itest_clean

itest_run:
	cd itest;erlc -I ../include *.erl
	@erl -pa deps/*/ebin -pa ebin -pa itest -noshell -eval "eunit:test(itest, [verbose])" \
	-s erlang halt -db_type $(DB_TYPE)

perftest: compile itest_create perftest_run itest_clean

perftest_run:
	cd itest;erlc -I ../include *.erl
	@erl -pa deps/*/ebin -pa ebin -pa itest -noshell \
	-eval "eunit:test(perftest, [verbose])" \
	-s erlang halt -db_type $(DB_TYPE)

.PHONY: all compile eunit test dialyzer clean allclean distclean doc itest itest_clean itest_create itest_run

