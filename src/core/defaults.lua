-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- The library's built-in defaults: the task states every space gets, and the
-- pre-filled text that `/kanban` and "Kanban: Customize task states" insert,
-- so people edit a full list (deleting a line removes that column or state)
-- instead of starting from nothing.

kanban = kanban or {}
kanban.defaults = kanban.defaults or {}
local defaults = kanban.defaults

---@class kanban.StateSpec
---@field name string
---@field order number|nil
---@field done boolean|nil a finished state (counts as done for blockers)
---@field todo boolean|nil kanban: this state's column also holds plain `[ ]` tasks
---@field column boolean|nil kanban: a done state that keeps its own column

---The task states every space gets with this library. Done (`[x]`) is built
---into SilverBullet and always comes last.
---@type kanban.StateSpec[]
defaults.taskStates = {
  { name = "Backlog", order = 0, todo = true },
  { name = "Ready for Development", order = 1 },
  { name = "In Progress", order = 2 },
  { name = "Blocked", order = 3 },
  { name = "Cancelled", order = 4, done = true, column = true },
}

---Validates a task-state list (as given to kanban.taskStates). Returns the
---valid entries and the problems found in the others.
---@param list any
---@return kanban.StateSpec[] valid
---@return string[] problems
function defaults.validateStates(list)
  local valid, problems, seen = {}, {}, {}
  if type(list) ~= "table" then
    return valid, { "kanban.taskStates needs a list of states" }
  end
  local todo = nil
  for i, s in ipairs(list) do
    local where = "task state " .. i
    if type(s) ~= "table" or type(s.name) ~= "string" or s.name == "" then
      problems[#problems + 1] = where .. " needs a `name`"
    elseif s.name == " " or s.name == "x" or s.name == "X" then
      problems[#problems + 1] = where .. ": `" .. s.name .. "` is built in"
    elseif string.find(s.name, ":", 1, true) or string.find(s.name, "]", 1, true) then
      problems[#problems + 1] = where .. ": names cannot contain `:` or `]`"
    elseif seen[s.name] then
      problems[#problems + 1] = where .. ": `" .. s.name .. "` is listed twice"
    elseif s.order ~= nil and type(s.order) ~= "number" then
      problems[#problems + 1] = where .. ": `order` must be a number"
    elseif s.todo and s.done then
      problems[#problems + 1] = where .. ": a done state cannot hold `[ ]` tasks"
    elseif s.todo and todo then
      problems[#problems + 1] = where
        .. ": only one state can hold `[ ]` tasks ("
        .. todo
        .. " already does)"
    else
      seen[s.name] = true
      if s.todo then
        todo = s.name
      end
      valid[#valid + 1] = {
        name = s.name,
        order = s.order,
        done = s.done == true or nil,
        todo = s.todo == true or nil,
        column = s.column == true or nil,
      }
    end
  end
  return valid, problems
end

---The `taskStates` config map for a list of states.
---@param list kanban.StateSpec[]
---@return table<string, kanban.StateSpec>
function defaults.stateMap(list)
  local map = {}
  for _, s in ipairs(list) do
    map[s.name] = kanban.util.shallowCopy(s)
  end
  return map
end

---The states of a `taskStates` config map as a list, ordered like their
---columns (to do, then by `order`, done states last).
---@param map table<string, table>|nil
---@return kanban.StateSpec[]
function defaults.stateList(map)
  local normalized = kanban.states.normalize(map)
  local out = {}
  for _, s in ipairs(normalized.list) do
    if not s.builtin then
      local spec = { name = s.name, order = s.order }
      if s.done then
        spec.done = true
      end
      if s.todo then
        spec.todo = true
      end
      if s.column then
        spec.column = true
      end
      out[#out + 1] = spec
    end
  end
  return out
end

-- A Markdown code fence. Spelled out with string.rep because three backticks
-- in a source file would end the library page's own space-lua fence.
local fence = string.rep("`", 3)

-- YAML for a plain string: bare when unambiguous, double-quoted otherwise.
local function yamlString(s)
  if string.match(s, "^[%w][%w _/%.%-]*$") and not string.match(s, "%s$") then
    return s
  end
  local escaped = string.gsub(s, '[\\"]', "\\%0")
  return '"' .. escaped .. '"'
end

---The text of a `kanban` block for a page, with its columns written out so
---they can be edited (deleting a line removes that column).
---@param pageName string
---@param columnTitles string[]
---@return string
function defaults.boardBlock(pageName, columnTitles)
  local lines = { fence .. "kanban", "page: " .. yamlString(pageName), "columns:" }
  for _, title in ipairs(columnTitles) do
    lines[#lines + 1] = "  - " .. yamlString(title)
  end
  lines[#lines + 1] = fence
  return table.concat(lines, "\n") .. "\n"
end

---The Space Lua for a CONFIG block that sets the complete list of task
---states, pre-filled with `list`.
---@param list kanban.StateSpec[]
---@return string
function defaults.configBlock(list)
  local lines = {
    "-- Kanban task states: the complete list. Delete a line to remove a state",
    "-- (its tasks go back to [ ] after System: Reload); add lines for your",
    "-- own. `todo = true` also puts plain [ ] tasks in that column, and",
    "-- `column = true` gives a done state its own column. Done ([x]) is built in.",
    "kanban.taskStates {",
  }
  for _, s in ipairs(list) do
    local parts = { "name = " .. string.format("%q", s.name) }
    if s.order ~= nil then
      parts[#parts + 1] = "order = " .. tostring(s.order)
    end
    if s.done then
      parts[#parts + 1] = "done = true"
    end
    if s.todo then
      parts[#parts + 1] = "todo = true"
    end
    if s.column then
      parts[#parts + 1] = "column = true"
    end
    lines[#lines + 1] = "  { " .. table.concat(parts, ", ") .. " },"
  end
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n") .. "\n"
end

---Inserts a Space Lua snippet into CONFIG text: at the end of the first
---space-lua block that the Configuration Manager doesn't manage, or in a new
---block at the end when there is none.
---@param configText string
---@param snippet string
---@return string
function defaults.insertIntoConfig(configText, snippet)
  local open = fence .. "space-lua"
  local pos = 1
  while true do
    local s, e = string.find(configText, open, pos, true)
    if s == nil then
      break
    end
    local close = string.find(configText, "\n" .. fence, e, true)
    if close == nil then
      break
    end
    local body = string.sub(configText, e + 1, close)
    if not string.find(body, "managed-by: configuration-manager", 1, true) then
      local before = string.sub(configText, 1, close)
      return before .. snippet .. string.sub(configText, close + 1)
    end
    pos = close + 1
  end
  local sep = string.sub(configText, -1) == "\n" and "\n" or "\n\n"
  return configText .. sep .. open .. "\n" .. snippet .. fence .. "\n"
end
