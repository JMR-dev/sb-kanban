# sb-kanban

Kanban boards for [SilverBullet](https://silverbullet.md) v2, as a pure Space
Lua library: no plug, nothing to compile. Boards are views over your ordinary
markdown tasks. Drag a card to change its task state, and link tasks across
pages with `blockedBy` dependencies.

> Status: in development (0.1.0). Requires SilverBullet 2.12.x.

## Install

The library is one page, `dist/Library/JMR-dev/Kanban.md`; it belongs at
`Library/JMR-dev/Kanban.md` in your space.

- **Folder space** (SilverBullet Desktop, or a server pointed at a folder):
  copy the file in, and SilverBullet picks it up within seconds.

  ```sh
  mkdir -p "$SPACE/Library/JMR-dev"
  cp dist/Library/JMR-dev/Kanban.md "$SPACE/Library/JMR-dev/"
  ```

- **Any space, from the browser:** create the page `Library/JMR-dev/Kanban`
  and paste the file's contents into it.

To update, replace the page the same way. Usage is documented on the
installed page.

**Library: Install** (and **Library: Update**) need the page at a publicly
readable `https://` or `github:` URI: SilverBullet 2.12 reads no `http://`
URIs and cannot sign in. This repository's Gitea instance requires signing
in to read files, so that route needs a public mirror first.

## Development

Everything is pinned and checksum-verified in `tools/versions.env`.

```sh
make bootstrap   # Lua 5.5.1, LuaRocks, busted, luacheck, StyLua, LuaLS,
                 # SilverBullet 2.12.1, pnpm deps, Playwright Chromium
make check       # format, lint, types, page, unit tests, real-SilverBullet tests
make dev         # SilverBullet on a scratch copy of the test space
```

SilverBullet runs its own Lua dialect, so the code is written to the subset
that both Space Lua and Lua 5.5.1 share. See [docs/compat.md](docs/compat.md)
for the rules and the tools that enforce them, and
[CONTRIBUTING.md](CONTRIBUTING.md) for the workflow.

## Credits

The idea of a SilverBullet kanban comes from
[dandimrod/silverbullet-kanban](https://github.com/dandimrod/silverbullet-kanban),
a pre-v2 plug. This is an independent rewrite for SilverBullet v2; no code is
taken from it.

## License

[Apache-2.0](LICENSE).
