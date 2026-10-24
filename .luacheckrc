-- luacheck configuration (luacheck itself runs on the project's Lua 5.5.1).
--
-- Code that runs inside SilverBullet (src/, spec/core/, sbtest/runtime/,
-- sbtest/shim.lua) is checked against the `spacelua` std, which is built only
-- from tools/sb_api.lua: the standard-library functions Space Lua implements
-- plus the SilverBullet APIs verified on the pinned release. It deliberately
-- does not start from luacheck's lua54 std, so anything outside the allowlist
-- (io, coroutine, require, unpack, os.getenv, math.maxinteger,
-- string.escapeHtml, the object API, ...) is an undefined-variable or
-- undefined-field warning.

local api = dofile("tools/sb_api.lua")

-- A read-only global table with exactly these fields.
local function fieldTable(names)
  local fields = {}
  for _, name in ipairs(names) do
    fields[name] = {}
  end
  return { fields = fields }
end

local readGlobals = {}
for _, name in ipairs(api.stdlib.globals) do
  readGlobals[name] = {}
end
for name, fields in pairs(api.stdlib.tables) do
  readGlobals[name] = fieldTable(fields)
end
for name, fields in pairs(api.extensions) do
  for _, field in ipairs(fields) do
    readGlobals[name].fields[field] = {}
  end
end
for name, fields in pairs(api.namespaces) do
  if fields == true then
    readGlobals[name] = { other_fields = true }
  else
    readGlobals[name] = fieldTable(fields)
  end
end
-- The integrated-query keyword: plain Lua parses `query [[...]]` as a call.
readGlobals.query = {}

stds.spacelua = {
  read_globals = readGlobals,
  -- This library's namespace, created with `kanban = kanban or {}`.
  globals = { "kanban" },
}

-- src/core/ and its specs: the standard library only, with no SilverBullet
-- APIs and not even Space Lua's string extensions. The Lua 5.5.1 test run
-- then exercises exactly the code SilverBullet runs, with nothing stubbed.
local coreGlobals = {}
for _, name in ipairs(api.stdlib.globals) do
  coreGlobals[name] = {}
end
for name, fields in pairs(api.stdlib.tables) do
  coreGlobals[name] = fieldTable(fields)
end
stds.spacecore = { read_globals = coreGlobals, globals = { "kanban" } }

-- Exactly the busted subset that sbtest/shim.lua implements, so a spec that
-- uses anything else fails lint before it fails inside SilverBullet.
stds.bustedSubset = {
  read_globals = {
    "describe",
    "it",
    "before_each",
    assert = {
      fields = {
        are = { fields = { same = {}, equal = {} } },
        is_true = {},
        is_false = {},
        is_nil = {},
        has_error = {},
      },
    },
  },
}

-- In-SilverBullet specs may also use `api.testOnly` and the `sbApi` local
-- that sbtest/runtime.spec.ts prepends (the parsed tools/sb_api.lua).
local testGlobals = { sbApi = { other_fields = true } }
for _, name in ipairs(api.testOnly.globals) do
  testGlobals[name] = {}
end
for name, fields in pairs(api.testOnly.namespaces) do
  testGlobals[name] = fieldTable(fields)
end
stds.sbtest = { read_globals = testGlobals }

-- The stubs in spec/helpers/ define the SilverBullet globals for Lua 5.5.1.
local stubbed = { "sbfake" }
for name in pairs(api.namespaces) do
  stubbed[#stubbed + 1] = name
end

std = "spacelua"
max_line_length = 100

files["src/core"] = { std = "spacecore" }
files["spec/core"] = { std = "spacecore+bustedSubset" }
files["sbtest"] = { std = "spacelua+bustedSubset+sbtest" }

-- These only ever run on Lua 5.5.1, never inside SilverBullet, so the full
-- standard library is fine there.
files["spec/sb"] = { std = "lua55+spacelua+bustedSubset", globals = { "sbfake" } }
files["spec/helpers"] = { std = "lua55+bustedSubset", globals = stubbed }
files["spec/tools"] = { std = "lua55+bustedSubset", read_globals = { "sbfake" } }
files["tools"] = { std = "lua55" }
files["tools/fixtures"] = { std = "spacelua" }

-- types/ holds lua-language-server declarations, not code.
exclude_files = { ".tools", "lua_modules", "node_modules", "types" }
