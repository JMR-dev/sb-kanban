# Contributing

## Layout

| Path | What | Runs on |
|---|---|---|
| `src/` | The library, one file per ```space-lua block of the installed page | SilverBullet |
| `src/core/` | Pure logic: plain tables in, plain tables out, no SilverBullet APIs | SilverBullet and Lua 5.5.1 |
| `src/sb/` | Adapters: the only code that calls SilverBullet APIs | SilverBullet |
| `page/Kanban.template.md` | The installed page's documentation | |
| `dist/Library/JMR-dev/Kanban.md` | The generated, committed install target (`make build`) | SilverBullet |
| `spec/core/` | Specs for `src/core/` | Lua 5.5.1 (busted) and SilverBullet (shim) |
| `spec/sb/` | Adapter specs against in-memory stubs | Lua 5.5.1 only |
| `sbtest/runtime/` | Integration specs inside a real SilverBullet | SilverBullet |
| `sbtest/ui/` | Playwright browser tests against a real SilverBullet | |
| `sbtest/space/` | The fixture space the server starts from | |
| `tools/` | Page generator, dialect check, API allowlist | Lua 5.5.1 |

## The gate

`make check` runs, in order:

1. `fmt-check`: StyLua.
2. `lint`: `luac -p` (Lua 5.5.1), luacheck against the allowlist std, the
   Space Lua dialect check, and the type-stub/allowlist sync.
3. `typecheck`: lua-language-server, against Space Lua's Lua 5.4-level stdlib.
4. `build-check`: the committed page matches the sources.
5. `test`: busted on Lua 5.5.1.
6. `sb-test`: the pinned SilverBullet server starts on a scratch copy of
   `sbtest/space/` with the committed page installed. `spec/core/` and
   `sbtest/runtime/` then run inside its headless client through the
   Runtime API.
7. `e2e`: Playwright drives boards in a browser against the same kind of
   server.

A change is passing only when all seven pass. Stages 6 and 7 are the only
ones that exercise SilverBullet's own Lua interpreter.

## Writing specs

Specs use the busted subset that `sbtest/shim.lua` implements:
- `describe`, `it`, `before_each` (before the `it`s it applies to);
- `assert.are.same`/`are.equal`, `assert.is_true`/`is_false`/`is_nil`;
- `assert.has_error(fn, exactMessage?)`.

luacheck rejects anything else. Don't depend on `pairs` order.

## Adding a SilverBullet API

1. Check that it exists on the pinned release, through the Runtime API
   (`make dev`, then `curl -d 'type(ns.fn)' http://127.0.0.1:3000/.runtime/lua`).
2. Add it to `tools/sb_api.lua` and add a stub to `types/silverbullet.lua`.
3. `sbtest/runtime/api_surface_spec.lua` re-checks it on every run.

## Pull requests

One feature per branch, as a PR to `main` on Gitea. CI runs the same stages:
`static` (1–4), `unit` (5) and `sb` (6–7). `main` requires all three.
