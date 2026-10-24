-- The complete list of SilverBullet APIs the library is allowed to use: the
-- single source of truth for compatibility.
--
-- * .luacheckrc builds its `silverbullet` std from this file, so using any
--   SilverBullet name or field that is not listed here is a lint warning.
-- * sbtest/runtime/api_surface checks every entry against the pinned server
--   (SILVERBULLET_VERSION in tools/versions.env), so an entry only stays here
--   while that release really has it.
-- * tools/check_api.lua keeps types/silverbullet.lua in step with this list.
--
-- Add a name only when the library starts using it, and only after checking
-- it exists on the pinned release (2.12.1, the maintainer's Desktop).
-- Upstream `main` documents APIs that 2.12.x does not have, such as
-- `string.escapeHtml` and the `object` API (docs/adr/0001-spike.md).
--
-- This file is plain data in the Space Lua and Lua 5.5 subset: it is also
-- evaluated inside SilverBullet by the api_surface spec.
return {
  -- The Lua standard library as far as the library may use it: what Space
  -- Lua implements (Lua 5.4 level, minus coroutine/io/debug/utf8/require,
  -- global unpack, most of os) and Lua 5.5.1 also has. Plain names are global
  -- functions or values; tables list their allowed fields.
  stdlib = {
    globals = {
      "assert",
      "error",
      "getmetatable",
      "ipairs",
      "next",
      "pairs",
      "pcall",
      "print",
      "rawequal",
      "rawget",
      "select",
      "setmetatable",
      "tonumber",
      "tostring",
      "type",
    },
    tables = {
      string = {
        "byte",
        "char",
        "find",
        "format",
        "gmatch",
        "gsub",
        "len",
        "lower",
        "match",
        "rep",
        "reverse",
        "sub",
        "upper",
      },
      table = { "concat", "insert", "remove", "sort", "unpack", "pack" },
      math = {
        "abs",
        "ceil",
        "floor",
        "fmod",
        "huge",
        "max",
        "min",
        "random",
        "tointeger",
        "type",
      },
      -- Space Lua's os only has time functions.
      os = { "time", "date", "clock", "difftime" },
    },
  },

  -- Syscall and Std namespaces: namespace -> function fields. `true` means
  -- any field (dom.<tag> element builders).
  namespaces = {
    codeWidget = { "define" },
    command = { "define" },
    config = { "get", "set", "define" },
    dom = true,
    editor = {
      "flashNotification",
      "navigate",
      "getCurrentPage",
      "getText",
      "replaceRange",
      "filterBox",
      "insertAtCursor",
      "getCursor",
    },
    event = { "listen" },
    index = { "tasks", "relations", "objects", "ensureFullIndex" },
    service = { "define", "discover", "invoke" },
    slashCommand = { "define" },
    space = { "readPage", "writePage" },
    system = { "invokeFunction" },
    widget = { "new", "html" },
    yaml = { "parse" },
  },

  -- Space Lua additions to standard library tables.
  extensions = {
    string = { "startsWith", "endsWith", "trim", "split" },
  },

  -- Plug functions called through system.invokeFunction. These are checked
  -- by the runtime integration specs that exercise them.
  plugFunctions = { "index.updateTaskState" },

  -- Extra names only the in-SilverBullet specs (sbtest/runtime/) may use.
  -- Checked by api_surface like everything else; never used by src/.
  testOnly = {
    globals = { "load" },
    namespaces = {},
  },
}
