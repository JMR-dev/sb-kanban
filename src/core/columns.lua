-- SPDX-License-Identifier: Apache-2.0
-- priority: 50

-- A board's columns. By default they come from the task states: one column
-- per state in `order`, then one Done column that collects every done state
-- and receives drops as "x". Two state flags adjust that: `todo` makes a
-- state's column also hold plain `[ ]` tasks (instead of a separate To do
-- column), and `column` gives a done state its own column before Done.
--
-- A board's `columns` option lists the columns to show. A plain name refers
-- to a default column (by title, else by one of its states), so the
-- pre-filled list is just names and deleting one removes that column; a
-- table describes a column literally.

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

---The default columns for a set of task states (without ids).
---@param normalized kanban.States
---@return { title: string, states: string[], dropState: string }[]
function columns.defaults(normalized)
  local todoState = nil
  for _, s in ipairs(normalized.list) do
    if s.todo and not s.done and todoState == nil then
      todoState = s.name
    end
  end
  local out = {}
  if todoState == nil then
    out[#out + 1] = { title = "To do", states = { " " }, dropState = " " }
  end
  local doneStates = {}
  for _, s in ipairs(normalized.list) do
    if s.builtin then
      if s.done then
        doneStates[#doneStates + 1] = s.name
      end
    elseif s.done and not s.column then
      doneStates[#doneStates + 1] = s.name
    else
      local states = { s.name }
      if s.name == todoState then
        states[2] = " "
      end
      out[#out + 1] = { title = s.name, states = states, dropState = s.name }
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
  out[#out + 1] = { title = "Done", states = doneStates, dropState = "x" }
  return out
end

---The titles of the default columns, as `/kanban` pre-fills them.
---@param normalized kanban.States
---@return string[]
function columns.defaultTitles(normalized)
  return kanban.util.map(columns.defaults(normalized), function(c)
    return c.title
  end)
end

-- A default column by title, else the default column holding that state,
-- else a column for that single state.
local function resolve(ref, defaultsList)
  for _, c in ipairs(defaultsList) do
    if c.title == ref then
      return c
    end
  end
  for _, c in ipairs(defaultsList) do
    if kanban.util.contains(c.states, ref) then
      return c
    end
  end
  return { title = titleFor { ref }, states = { ref }, dropState = ref }
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

  local defaultsList = columns.defaults(normalized)
  if spec.columns == nil then
    for _, c in ipairs(defaultsList) do
      add(c.title, c.states, c.dropState)
    end
    return out
  end
  for _, c in ipairs(spec.columns) do
    if c.ref ~= nil then
      local d = resolve(c.ref, defaultsList)
      add(d.title, d.states, d.dropState)
    else
      add(c.title or titleFor(c.states), c.states, c.dropState)
    end
  end
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
