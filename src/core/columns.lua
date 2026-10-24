-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- A board's columns: given explicitly in the board options, or derived from
-- the task states (to do, each custom not-done state, then one Done column
-- that collects every done state and receives drops as "x").

kanban = kanban or {}
kanban.columns = kanban.columns or {}
local columns = kanban.columns

---@class kanban.Column
---@field id string
---@field title string
---@field states string[]
---@field dropState string
---@field done boolean every state in the column is a done state

local defaultTitles = { [" "] = "To do", x = "Done", X = "Done" }

local function titleFor(states)
  return defaultTitles[states[1]] or states[1]
end

---@param spec kanban.Spec
---@param normalized kanban.States
---@return kanban.Column[]
function columns.build(spec, normalized)
  local out = {}
  local function add(title, list, dropState)
    local done = true
    for _, s in ipairs(list) do
      if not kanban.states.isDone(s, normalized) then
        done = false
      end
    end
    if done and not spec.includeDone then
      return
    end
    out[#out + 1] = {
      id = tostring(#out + 1),
      title = title,
      states = list,
      dropState = dropState,
      done = done,
    }
  end

  if spec.columns then
    for _, c in ipairs(spec.columns) do
      add(c.title or titleFor(c.states), c.states, c.dropState)
    end
    return out
  end

  local doneStates = {}
  for _, s in ipairs(normalized.list) do
    if s.done then
      doneStates[#doneStates + 1] = s.name
    else
      add(titleFor { s.name }, { s.name }, s.name)
    end
  end
  -- "x" first so that drops into Done write "x". The comparator must be a
  -- strict ordering (cmp(a, a) == false): Space Lua's sort never returns
  -- otherwise.
  table.sort(doneStates, function(a, b)
    if a == b then
      return false
    elseif a == "x" or b == "x" then
      return a == "x"
    end
    return a < b
  end)
  add("Done", doneStates, "x")
  return out
end

---The column a state belongs to, or nil.
---@param list kanban.Column[]
---@param state string
---@return kanban.Column|nil
function columns.forState(list, state)
  for _, c in ipairs(list) do
    if kanban.util.contains(c.states, state) then
      return c
    end
  end
  return nil
end
