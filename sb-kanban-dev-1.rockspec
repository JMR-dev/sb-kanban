-- Development-only rockspec: never published. It exists to install and pin
-- the test toolchain (busted and its dependency tree, plus luacheck's
-- dependencies; luacheck itself comes from a pinned commit, see
-- scripts/bootstrap.sh) into the project-local lua_modules/ tree; exact
-- versions are locked in luarocks.lock.
rockspec_format = "3.0"
package = "sb-kanban"
version = "dev-1"
source = {
  url = "git+file:///dev/null",
}
description = {
  summary = "Kanban boards for SilverBullet v2, as a Space Lua library",
  license = "AGPL-3.0-or-later",
}
dependencies = {
  "lua >= 5.4",
  "busted == 2.3.0",
  "argparse == 0.7.2",
  "luafilesystem == 1.9.0",
}
build = {
  type = "none",
}
