# sb-kanban. `make check` is the gate: nothing counts as passing unless every
# stage passes, including sb-test and e2e, which run against a real
# SilverBullet server (SilverBullet runs its own Lua interpreter, so Lua 5.5.1
# results alone prove nothing about it). See CONTRIBUTING.md.

SHELL := bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := check

BIN := .tools/bin
LUA := $(BIN)/lua
LUAC := $(BIN)/luac
STYLUA := $(BIN)/stylua
LUALS := $(BIN)/lua-language-server
BUSTED := lua_modules/bin/busted
LUACHECK := lua_modules/bin/luacheck

PAGE := dist/Library/JMR-dev/Kanban.md
FMT_DIRS := src spec sbtest tools types

# Lua that runs inside SilverBullet and must follow docs/compat.md.
SB_LUA = $(shell find src spec/core sbtest -name '*.lua' 2>/dev/null | sort)
ALL_LUA = $(shell find src spec sbtest tools types -name '*.lua' 2>/dev/null | sort)

.PHONY: bootstrap build fmt fmt-check lint typecheck build-check test sb-test e2e check dev

## Install the pinned toolchain (.tools/, lua_modules/) and the test harness.
bootstrap:
	scripts/bootstrap.sh
	pnpm install --frozen-lockfile
	pnpm exec playwright install chromium

## Regenerate the installable library page from page/ and src/.
build:
	$(LUA) tools/build_page.lua $(PAGE)

fmt:
	$(STYLUA) $(FMT_DIRS)

fmt-check:
	$(STYLUA) --check $(FMT_DIRS)

## Syntax (luac 5.5.1), luacheck's allowlist std, the Space Lua dialect rules,
## and the type stubs matching the allowlist.
lint:
	$(LUAC) -p $(ALL_LUA)
	$(LUACHECK) -q .
	$(LUA) tools/check_dialect.lua $(SB_LUA)
	$(LUA) tools/check_api.lua

typecheck:
	$(LUALS) --check=. --checklevel=Warning --configpath=.luarc.json \
	  --logpath=.tools/luals-log --check_format=pretty

## The committed page must match what the sources generate.
build-check:
	$(LUA) tools/build_page.lua .tools/page-check.md
	@cmp -s .tools/page-check.md $(PAGE) || { \
	  echo "$(PAGE) is out of date: run 'make build' and commit it" >&2; \
	  diff -u $(PAGE) .tools/page-check.md | head -40 >&2; exit 1; }

## Unit specs on Lua 5.5.1.
test:
	$(BUSTED)

## Specs inside a real SilverBullet (Runtime API): spec/core/ plus
## sbtest/runtime/, against the committed page.
sb-test:
	pnpm run sb-test

## Browser tests against a real SilverBullet.
e2e:
	pnpm run e2e

check: fmt-check lint typecheck build-check test sb-test e2e

## Run the pinned SilverBullet on a scratch copy of the fixture space, with
## the freshly built page installed, for trying things by hand.
dev: build
	scripts/dev.sh
