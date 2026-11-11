SHELL := bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

LUA_COVERAGE_MIN ?= 80
BUSTED_FLAGS ?=
ADDON := MasterAngler

LR_PATH := $(shell luarocks --lua-version=5.1 --local path --lr-path 2>/dev/null)
LR_CPATH := $(shell luarocks --lua-version=5.1 --local path --lr-cpath 2>/dev/null)
export PATH := $(HOME)/.luarocks/bin:$(PATH)
export LUA_PATH := $(LR_PATH);$(LUA_PATH);;
export LUA_CPATH := $(LR_CPATH);$(LUA_CPATH);;

.PHONY: help deps test lint fmt fmt-check coverage install link

help: ## Show the targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{ printf "%-12s %s\n", $$1, $$2 }'

deps: ## Install busted, luacov and luacheck with luarocks (Lua 5.1)
	luarocks --lua-version=5.1 --local install busted 2.3.0-1
	luarocks --lua-version=5.1 --local install luacov 0.17.0-1
	luarocks --lua-version=5.1 --local install luacheck 1.2.0-1

test: ## Run the busted tests
	busted $(BUSTED_FLAGS)

lint: ## Run luacheck
	luacheck .

fmt: ## Format the Lua code
	stylua .

fmt-check: ## Check the Lua format
	stylua --check .

coverage: ## Run busted with luacov and check the threshold
	rm -f luacov.stats.out luacov.report.out
	busted --coverage $(BUSTED_FLAGS)
	luacov
	LUA_COVERAGE_MIN=$(LUA_COVERAGE_MIN) bash scripts/coverage.sh luacov.report.out

install: ## Copy the addon into WOW_DIR (a flavor folder such as _forever_)
	@if [ -z "$${WOW_DIR:-}" ]; then echo "WOW_DIR is required, for example .../World of Warcraft/_forever_" >&2; exit 2; fi
	@if [ ! -d "$(WOW_DIR)/Interface/AddOns" ]; then echo "install: $(WOW_DIR)/Interface/AddOns does not exist" >&2; exit 1; fi
	rm -rf "$(WOW_DIR)/Interface/AddOns/$(ADDON)"
	cp -R "$(ADDON)" "$(WOW_DIR)/Interface/AddOns/$(ADDON)"

link: ## Link the addon into WOW_DIR (a flavor folder such as _forever_)
	@if [ -z "$${WOW_DIR:-}" ]; then echo "WOW_DIR is required, for example .../World of Warcraft/_forever_" >&2; exit 2; fi
	@if [ ! -d "$(WOW_DIR)/Interface/AddOns" ]; then echo "link: $(WOW_DIR)/Interface/AddOns does not exist" >&2; exit 1; fi
	@if [ -e "$(WOW_DIR)/Interface/AddOns/$(ADDON)" ] && [ ! -L "$(WOW_DIR)/Interface/AddOns/$(ADDON)" ]; then echo "link: remove the copy first" >&2; exit 1; fi
	ln -sfn "$(CURDIR)/$(ADDON)" "$(WOW_DIR)/Interface/AddOns/$(ADDON)"
