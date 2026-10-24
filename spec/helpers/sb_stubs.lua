-- In-memory stand-ins for the SilverBullet APIs in tools/sb_api.lua, for the
-- Lua 5.5.1 test run only. They never run inside SilverBullet, where the real
-- APIs exist; real-server coverage of the adapters comes from
-- sbtest/runtime/.
--
-- `sbfake` holds the fake world (pages, config, registered widgets) so specs
-- under spec/sb/ can set it up and inspect it; `sbfake.reset()` empties it.

sbfake = {}

function sbfake.reset()
  sbfake.config = {}
  sbfake.codeWidgets = {}
end
sbfake.reset()

local function path(key)
  if type(key) == "table" then
    return key
  end
  local parts = {}
  for part in string.gmatch(key, "[^.]+") do
    parts[#parts + 1] = part
  end
  return parts
end

config = {}

function config.get(key, default)
  local node = sbfake.config
  for _, k in ipairs(path(key)) do
    if type(node) ~= "table" then
      return default
    end
    node = node[k]
  end
  if node == nil then
    return default
  end
  return node
end

function config.set(key, value)
  local parts = path(key)
  local node = sbfake.config
  for i = 1, #parts - 1 do
    node[parts[i]] = node[parts[i]] or {}
    node = node[parts[i]]
  end
  node[parts[#parts]] = value
end

function config.define(key, schema)
  sbfake.config.__schemas = sbfake.config.__schemas or {}
  sbfake.config.__schemas[key] = schema
end

codeWidget = {}

function codeWidget.define(def)
  sbfake.codeWidgets[def.language] = def
end
