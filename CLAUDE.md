# sb-kanban

Kanban boards for SilverBullet v2, as a pure Space Lua library. Read
`docs/compat.md` before writing any Lua that runs inside SilverBullet.

## Rules

- **Nothing is "passing" until it passed against a real SilverBullet.**
  SilverBullet runs its own Lua interpreter, so Lua 5.5.1 results prove
  nothing about it. The gate is `make check`, which includes `sb-test` and
  `e2e` (real server, pinned in `tools/versions.env`). If only part of it ran,
  say exactly which stages ran.
- **Only compatible features.** `src/`, `spec/core/`, `sbtest/shim.lua` and
  `sbtest/runtime/` run inside SilverBullet and follow `docs/compat.md`. Use
  only APIs in `tools/sb_api.lua`. Add one there (and a stub in
  `types/silverbullet.lua`) only after checking it exists on the pinned
  release; never because upstream `main` documents it.
- **The library page is generated.** Edit `src/` and `page/`, then
  `make build`; commit `dist/` with the change (CI checks it is current).
- **The `kanban` namespace is never reassigned** (`kanban = kanban or {}`), so
  a future TypeScript plug can add `kanban.*` syscalls.
- **Git:** one feature per branch and PR on Gitea
  (`ssh://git@gitea.jasonmross.dev:2222/JMR-dev/sb-kanban.git`, `tea` CLI).
  Never push to `main` or force-push. A PR may be merged once every CI check
  is green.
- Tool versions and hashes live only in `tools/versions.env`; bump both
  together.

## Commands

- `make bootstrap`: pinned toolchain into `.tools/` and `lua_modules/`, plus
  pnpm deps and Playwright's Chromium.
- `make fmt`: format. `make check`: the full gate.
- Single stages: `fmt-check lint typecheck build-check test sb-test e2e`.
- `make dev`: pinned SilverBullet on a scratch copy of `sbtest/space`.
