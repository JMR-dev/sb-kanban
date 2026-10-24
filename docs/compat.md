# Compatibility contract

The library runs inside SilverBullet's own Lua interpreter (Space Lua), while
its unit tests run on Lua 5.5.1. "Compatible" means: **works on the pinned
SilverBullet release (`SILVERBULLET_VERSION` in `tools/versions.env`:
2.12.1, the version the maintainer's Desktop runs) and behaves the same on Lua
5.5.1.** Upstream documentation on `main` describes Edge features that no
release has yet; it is not a source of truth here. The pinned server is.

| Rule | Why | Enforced by |
|---|---|---|
| Only APIs listed in `tools/sb_api.lua` | That list was checked against the pinned release; `main` documents more (`object.*`, `string.escapeHtml`, live-updating widgets) | luacheck `spacelua` std (built from the list); `sbtest/runtime/api_surface_spec.lua` re-checks every entry on the real server |
| Only the Lua standard library that Space Lua implements | No `coroutine`, `io`, `debug`, `utf8`, `require`/`package`, global `unpack`, `table.create` (5.5), `math.maxinteger`, `os` beyond time functions | luacheck `spacelua` std; LuaLS with `runtime.version = "Lua 5.4"` and those libraries disabled |
| Type stubs match the allowlist | A stub for a missing API would let typecheck pass | `tools/check_api.lua` |
| No `global` declarations (Lua 5.5) | Space Lua has none | `tools/check_dialect.lua` |
| `query` and `using` never used as names or fields | Hard keywords in Space Lua | `tools/check_dialect.lua` |
| No `query [[...]]` followed by `[`, `.` or `:` | Space Lua parse error | `tools/check_dialect.lua` |
| No `!=` | Space Lua only | `luac -p` (5.5.1) and `tools/check_dialect.lua` |
| No bitwise operators | 32-bit in Space Lua, 64-bit in Lua 5.5 | `tools/check_dialect.lua` |
| Long brackets at level 2 at most (`[==[`) | Space Lua's limit | `tools/check_dialect.lua` |
| No `__gc`, `__mode`, `__metatable` | Unsupported metamethods | `tools/check_dialect.lua` |
| No `repeat ... until` | Space Lua resolves a body `local` named in the `until` condition as a global (found by the in-SilverBullet run of `deps.lua`'s cycle detection) | `tools/check_dialect.lua` |
| No `_G` | A userdata proxy in Space Lua: `type(_G)` is `"userdata"` and `pairs(_G)` yields nothing | `tools/check_dialect.lua` |
| No assignment to `for` loop variables | Compile error in Lua 5.5 | `luac -p` (5.5.1) |
| `table.sort` comparators must be strict (`cmp(a, a)` is false, never both `cmp(a, b)` and `cmp(b, a)`) | Space Lua's sort never returns otherwise, which hangs the client; Lua 5.5.1 copes | `spec/helpers/strict_sort.lua` fails any such sort in the Lua 5.5.1 run |
| Don't depend on `pairs` order | Space Lua orders keys differently | Review; the in-SilverBullet spec run catches regressions |
| Don't compare error messages for equality | Space Lua's `error()` adds no position prefix | Specs use `assert.has_error(fn, substring)` |
| Don't rely on integer vs float formatting or 64-bit integers | Space Lua numbers are JS doubles | Review; the in-SilverBullet spec run |
| Don't trust `task.done` | Pages indexed before CONFIG ran keep a stale value | `kanban.states` computes done-ness from `taskStates` |
| No file calls into another file while loading; load-time actions live in `src/register.lua` (priority 10) | SilverBullet runs equal-priority blocks in no guaranteed order (by `Page@pos` ref, compared as strings) | `spec/tools/load_order_spec.lua` loads `src/` forwards and backwards |
| Task text goes into the DOM through `kanban.sb.render.textEl` | 2.12's `dom` builder renders plain-string children as Markdown, raw HTML included | `sbtest/runtime/render_spec.lua` and the e2e literal-text test |
| No widget relying on automatic re-render | Edge only; 2.12 needs `refreshOn` | Boards use `widget.new { content = ..., refreshOn = { "index" } }`; e2e checks a board updates after an edit elsewhere |

Code that must follow the rules: `src/`, `spec/core/`, `sbtest/shim.lua`,
`sbtest/runtime/`. Code under `tools/`, `spec/sb/`, `spec/helpers/` and
`spec/tools/` only ever runs on Lua 5.5.1.

The final word is the real-SilverBullet run (`make sb-test e2e`): nothing is
reported as passing without it.
