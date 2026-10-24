# ADR 0001: Spike results against real SilverBullet 2.12.0

- Status: accepted
- Date: 2026-10-24
- Context: plan step 2. The upstream docs read during planning came from the
  `main` branch (Edge). Everything below was checked against the pinned
  `silverbullet-server` 2.12.0 binary through the Runtime API
  (`/.runtime/lua_script`) and a Playwright-driven browser. The user's own
  SilverBullet Desktop (stable flatpak, built 2026-10-12) corresponds to
  2.12.1, which has the same APIs.

## Findings

### Works on 2.12.0 as planned
- **Native HTML5 drag-and-drop through Lua DOM handlers.** `dom.div {
  draggable = "true", ondragstart = ..., ondragover = ..., ondrop = ... }`:
  `e.dataTransfer.setData/getData` and `e.preventDefault()` (dot-call, per the
  JS bridge) work, and Playwright's `dragTo` drives it.
- **A list-valued `blockedBy`** (`[blockedBy: ["[[$a]]", "[[$b]]"]]`) gives one
  `blockedBy` relation per link. A relation's `from` is the task's `ref` (the
  anchor name when it has one, else `Page@pos`); `to` is the anchor name,
  `toTag = "anchor"`.
- **A task's `ref`** is its anchor name when anchored, else `Page@pos`; `range` is
  the byte range of the whole list line. An inline attribute shows up as a
  field (`t.blockedBy`), either a string or a list.
- **`editor.navigate("$anchor")`** opens the anchor's page with the cursor on
  the task.
- **`yaml.parse`** is available to Lua.
- **`index.updateTaskState(pageAtPos, oldState, newState)`** (via
  `system.invokeFunction`) rewrites the state. Given an anchor ref instead of
  `Page@pos` it silently does nothing; given a stale position it also silently
  does nothing (the file is left intact).
- **Text splices**: `space.writePage` (page not open) and
  `editor.replaceRange` (page open in the editor; saved after a short delay)
  both work, and new `$anchor`s get indexed.
- **`query [[...]]`** (with the space StyLua inserts) parses the same as
  `query[[...]]`.

### Not in 2.12.0 (Edge only, per CHANGELOG "Edge" section)
- **The `object` API** (`object.update/append/delete/createPage`) is nil.
- **Automatic live update of widgets** ("widgets now compose everywhere and
  live update"): a code widget that reads `index.tasks()` does **not**
  re-render when tasks change.
- **`string.escapeHtml`** is nil.

### Stdlib surface on 2.12.0 (introspected with `type(...)`)
- Present: `string.startsWith/endsWith/trim/trimStart/trimEnd/split/
  matchRegex/matchRegexAll`, `table.includes/keys/find/select`, `each`,
  `some`, plus the usual Lua 5.4 `string`/`table`/`math`/`os.time/date/clock`.
- Missing: `string.escapeHtml`, `table.create` (5.5), global `unpack`,
  `os.getenv`, `os.exit`.
- `.luacheckrc` and `types/silverbullet.lua` list exactly the verified surface.

### Task states
- `taskState.define { name, done, order }` lands in `config.get("taskStates")`
  as `{ [name] = { name, done, order } }`.
- `task.done` honours a custom `done = true` state, but only at index time:
  in a freshly booted space, a page indexed before CONFIG's definitions ran
  reported `done = false` until it was re-indexed. **The core therefore
  derives done-ness from `taskStates` (plus `x`/`X`) itself and does not
  trust `task.done`.**

### Space Lua parse quirk found
- `query[[...]][1]` is a parse error ("unexpected symbol near '['"); assign the
  result to a local first (or parenthesise it).

### Environment
- The index lags an external write (HTTP `PUT /.fs/...`) by a few seconds, so
  tests must poll for the expected state.
- The Runtime API client and a browser are separate clients: Lua globals are
  not shared between them.
- In `mcr.microsoft.com/playwright:v1.64.0-resolute`, running as root, the
  Runtime API works with Playwright's headless shell as `SB_CHROME_PATH` and
  no `--no-sandbox` wrapper. The image has no `make`, `unzip`, `gcc` or `jq`.

## Decisions
1. **All writes go through one seam, `src/sb/write.lua`, with only the 2.12.x
   backend in v1.** That means `index.updateTaskState` with a `Page@pos` ref
   for state changes, and a guarded splice for attributes and anchors. The
   splice computes the new line in the pure core, checks that the indexed
   range still holds the expected line, and writes with `editor.replaceRange`
   if the page is open, else `space.writePage`. Every write is verified by
   re-reading the page; when it didn't land, the user sees "this task changed
   since the board was drawn". An `object.update` backend is **not** built
   now: no pinned release has the API, so it could not get a real-SilverBullet
   run, which is the project's bar for passing. Adding it later touches only
   `write.lua`.
2. **Boards render as `widget.new { content = fn, refreshOn = { "index" } }`**,
   which re-renders on index changes on 2.12.0 and is still supported on Edge.
3. **HTML escaping is the core's own `escapeHtml`**, not `string.escapeHtml`.
4. **The dialect check also rejects `query[[...]]` followed by `[`, `.` or `:`.**
5. **Tooling** (step 1): selene was replaced by luacheck. selene's release
   binaries only include the Lua 5.1 std, and crates.io has no 0.32.0 to build
   with Lua 5.4 support. luacheck comes from a pinned master commit, because the
   1.2.0 release crashes on Lua 5.5.
