-- SPDX-License-Identifier: Apache-2.0
-- priority: 50

-- The extension points: card decorators (badges) and move guards. Any Space
-- Lua block in the space can register one, as long as it runs after this
-- library (the default priority, 0, does). Re-registering a name replaces it.
-- The built-ins go through the same path (src/register.lua).

kanban = kanban or {}
kanban.registry = kanban.registry or { decorators = {}, guards = {} }
local registry = kanban.registry

local function check(def, fnField, apiName)
  if type(def) ~= "table" or type(def.name) ~= "string" or type(def[fnField]) ~= "function" then
    error(apiName .. " needs a table with `name` (string) and `" .. fnField .. "` (function)")
  end
  if def.priority ~= nil and type(def.priority) ~= "number" then
    error(apiName .. ": `priority` must be a number")
  end
end

---Registers a card decorator: `decorate(card, ctx)` returns a list of badges
---`{ kind, text, title?, tone?, refs? }` for the card (or nil). Decorators run
---by `priority`, highest first; a failing one is reported on the board.
---@param def kanban.Decorator
function kanban.defineDecorator(def)
  check(def, "decorate", "kanban.defineDecorator")
  registry.decorators[def.name] = def
end

---Registers a move guard: `check(move, ctx)` returns true to allow a card
---move, or false plus a reason shown to the user.
---@param def kanban.MoveGuard
function kanban.defineMoveGuard(def)
  check(def, "check", "kanban.defineMoveGuard")
  registry.guards[def.name] = def
end

---The registered definitions of one kind, sorted by name.
---@param kind "decorators"|"guards"
---@return table[]
function registry.list(kind)
  local out = {}
  for _, name in ipairs(kanban.util.sortedKeys(registry[kind])) do
    out[#out + 1] = registry[kind][name]
  end
  return out
end
