-- SPDX-License-Identifier: Apache-2.0
-- priority: 50

-- Task states: SilverBullet's built-in " " (to do) and "x"/"X" (done), plus
-- the custom states defined with `taskState.define { name, done, order }`
-- (config key `taskStates`). Done-ness is computed here rather than read from
-- `task.done`, which can be stale for pages indexed before CONFIG ran.

kanban = kanban or {}
kanban.states = kanban.states or {}
local states = kanban.states

---@class kanban.State
---@field name string
---@field done boolean
---@field order number
---@field builtin boolean
---@field todo boolean|nil this state's column also holds plain `[ ]` tasks
---@field column boolean|nil a done state with its own column

---@class kanban.States
---@field list kanban.State[] not-done states first (by order, then name), then done states
---@field byName table<string, kanban.State>

---Normalizes the `taskStates` config map into an ordered list.
---@param defs table<string, table>|nil
---@return kanban.States
function states.normalize(defs)
  local list = {}
  local byName = {}
  local function add(name, done, order, builtin, flags)
    if byName[name] == nil then
      local s = { name = name, done = done, order = order, builtin = builtin }
      if flags then
        s.todo = flags.todo == true and not done or nil
        s.column = flags.column == true and done or nil
      end
      byName[name] = s
      list[#list + 1] = s
    end
  end
  add(" ", false, -math.huge, true)
  defs = defs or {}
  for _, key in ipairs(kanban.util.sortedKeys(defs)) do
    local def = defs[key]
    if type(def) == "table" then
      local name = def.name or key
      add(name, def.done == true, tonumber(def.order) or 0, false, def)
    end
  end
  add("x", true, math.huge, true)
  add("X", true, math.huge, true)
  table.sort(list, function(a, b)
    if a.done ~= b.done then
      return not a.done
    elseif a.order ~= b.order then
      return a.order < b.order
    end
    return a.name < b.name
  end)
  return { list = list, byName = byName }
end

---@param state string
---@param normalized kanban.States
---@return boolean
function states.isDone(state, normalized)
  local s = normalized.byName[state]
  return s ~= nil and s.done
end
